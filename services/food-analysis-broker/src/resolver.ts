import { createHash } from "node:crypto";

import { estimateFromPer100g, fallbackEstimate, portionFromObservation } from "./nutrition.js";
import { nutritionProviderFromEnv, type NutritionProvider } from "./usda.js";
import type { CandidateResolver, DishType, EstimateConfidence, FoodAnalysisCandidate, FoodIntakeDraft, ObservationResolver } from "./types.js";

export class GrainDraftResolver implements ObservationResolver {
  resolve(input: Parameters<ObservationResolver["resolve"]>[0]): FoodIntakeDraft {
    const draftId = input.request.draft?.draft_id ?? `draft-photo:${input.photoSha25616}`;
    const captureId = input.request.capture_id;
    const payloadCid = input.request.draft?.payload_cid ?? `food-photo:${captureId ?? input.photoSha25616}`;
    const estimateId = `photo-estimate:${stableDigest([
      input.photoSha25616,
      input.modelId,
      String(input.observation.total_kcal),
      String(input.observation.kcal_variance)
    ])}`;

    return {
      draft_v: 1,
      draft_id: draftId,
      payload_cid: payloadCid,
      source: "photo_estimate",
      source_class: "estimated",
      mean: { kcal: input.observation.total_kcal },
      var: { kcal: input.observation.kcal_variance },
      ...(input.observation.amount_g === null ? {} : { amount_g: input.observation.amount_g }),
      ...(input.observation.serving_g === null ? {} : { serving_g: input.observation.serving_g }),
      ...(input.observation.servings === null ? {} : { servings: input.observation.servings }),
      ...(input.request.draft?.ts_ms === undefined ? {} : { ts_ms: input.request.draft.ts_ms }),
      source_ref: {
        estimate_id: estimateId,
        ...(captureId ? { capture_id: captureId } : {}),
        confidence: input.observation.confidence,
        evidence: {
          photo_sha256_16: input.photoSha25616,
          model_id: input.modelId,
          observation_schema: "grain_food_photo_observation_v1"
        },
        food_items: input.observation.items.map((item) => ({ ...item }))
      },
      privacy: {
        raw_photo_persistence: "forbidden",
        allowed_persistent_photo_fields: ["photo_sha256_16"]
      }
    };
  }
}

export class FoodAnalysisCandidateResolver implements CandidateResolver {
  private readonly nutritionProvider: NutritionProvider;

  constructor(options: { nutritionProvider?: NutritionProvider } = {}) {
    this.nutritionProvider = options.nutritionProvider ?? nutritionProviderFromEnv();
  }

  async resolveCandidate(input: Parameters<CandidateResolver["resolveCandidate"]>[0]): Promise<FoodAnalysisCandidate> {
    const item = input.observation.items[0];
    const label = item?.label?.trim() || input.request.hints?.meal_context || "Captured meal";
    const genericLabel = genericFoodLabel(label);
    const dishType = inferDishType(label);
    const match = await this.safeNutritionLookup(label, genericLabel);
    const estimate = match
      ? estimateFromPer100g(match.per100g, portionFromObservation(input.observation.amount_g, input.observation.serving_g))
      : fallbackEstimate(input.observation);
    const confidence = confidenceFrom(input.observation.confidence, Boolean(match), dishType);

    return {
      id: `broker-${stableDigest([input.photoSha25616, input.modelId, label])}`,
      primaryLabel: titleCase(label),
      genericLabel,
      dishType,
      portion: estimate.portion,
      nutrition: estimate.nutrition,
      macronutrients: estimate.macronutrients,
      confidence,
      assumptions: assumptionsFor({ label, dishType, matched: Boolean(match), observationConfidence: input.observation.confidence }),
      evidence: [
        {
          provider: input.modelId.startsWith("gpt-") ? "openai_responses" : "deterministic_fixture",
          providerID: input.modelId,
          matchedName: "food photo observation",
          servingBasis: "image_observation"
        },
        ...(match ? [{
          provider: match.provider,
          providerID: match.providerID,
          matchedName: match.matchedName,
          servingBasis: match.servingBasis
        }] : [])
      ],
      userConfirmationRequired: true
    };
  }

  private async safeNutritionLookup(label: string, genericLabel: string) {
    try {
      return await this.nutritionProvider.lookup(label) ?? await this.nutritionProvider.lookup(genericLabel);
    } catch {
      return null;
    }
  }
}

function stableDigest(parts: string[]): string {
  return createHash("sha256").update(parts.join("\n")).digest("hex").slice(0, 16);
}

function genericFoodLabel(label: string): string {
  const normalized = label.trim().toLowerCase();
  if (normalized.includes("apple")) return "apple";
  if (normalized.includes("risotto")) return "risotto";
  if (normalized.includes("salad")) return "salad";
  return normalized || "meal";
}

function inferDishType(label: string): DishType {
  const normalized = label.toLowerCase();
  if (normalized.includes("package") || normalized.includes("bar") || normalized.includes("label")) return "packaged";
  if (normalized.includes("risotto") || normalized.includes("bowl") || normalized.includes("plate") || normalized.includes("salad")) return "mixed";
  if (normalized.includes("meal") || normalized.includes("unknown")) return "unknown";
  return "single";
}

function confidenceFrom(value: number, hasNutritionMatch: boolean, dishType: DishType): EstimateConfidence {
  if (hasNutritionMatch && value >= 0.8 && dishType !== "mixed") return "high";
  if (hasNutritionMatch && value >= 0.55) return "medium";
  return "low";
}

function assumptionsFor(input: { label: string; dishType: DishType; matched: boolean; observationConfidence: number }) {
  const assumptions = [
    { id: "photo-estimate", label: "estimate from selected meal photo", isEnabled: true },
    { id: "user-confirmation", label: "review before saving", isEnabled: true }
  ];

  if (input.dishType === "mixed") {
    assumptions.push({ id: "mixed-dish-components", label: "mixed dish ingredients may vary", isEnabled: true });
  }
  if (!input.matched) {
    assumptions.push({ id: "model-only-nutrition", label: "nutrition database match unavailable; range is wider", isEnabled: true });
  }
  if (input.observationConfidence < 0.7) {
    assumptions.push({ id: "portion-uncertain", label: "portion size needs review", isEnabled: true });
  }
  return assumptions;
}

function titleCase(value: string): string {
  return value
    .split(/\s+/u)
    .filter(Boolean)
    .map((part) => part[0]?.toUpperCase() + part.slice(1))
    .join(" ");
}
