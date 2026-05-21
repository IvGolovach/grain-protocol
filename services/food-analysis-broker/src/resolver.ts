import { estimateFromExplicitCalories, estimateFromPer100g, fallbackEstimate, portionFromObservation } from "./nutrition.js";
import { stableDigest } from "./runtime.js";
import { nutritionProviderFromEnv, type NutritionProvider } from "./usda.js";
import type { CandidateResolver, DishType, EstimateConfidence, FoodAnalysisCandidate, FoodIntakeDraft, FoodObservation, ObservationResolver } from "./types.js";

export class GrainDraftResolver implements ObservationResolver {
  async resolve(input: Parameters<ObservationResolver["resolve"]>[0]): Promise<FoodIntakeDraft> {
    const draftId = input.request.draft?.draft_id ?? `draft-photo:${input.photoSha25616}`;
    const captureId = input.request.capture_id;
    const payloadCid = input.request.draft?.payload_cid ?? `food-photo:${captureId ?? input.photoSha25616}`;
    const explicitLabelCalories = caloriesFromNutritionLabel(input.observation);
    const meanKcal = explicitLabelCalories?.kcal ?? input.observation.total_kcal;
    const varianceKcal = explicitLabelCalories ? 0 : input.observation.kcal_variance;
    const estimateId = `photo-estimate:${await stableDigest([
      input.photoSha25616,
      input.modelId,
      String(meanKcal),
      String(varianceKcal)
    ])}`;

    return {
      draft_v: 1,
      draft_id: draftId,
      payload_cid: payloadCid,
      source: "photo_estimate",
      source_class: "estimated",
      mean: { kcal: meanKcal },
      var: { kcal: varianceKcal },
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
    const label = item?.label?.trim() || input.observation.nutrition_label?.source_text?.trim() || "Visible nutrition label";
    const genericLabel = genericFoodLabel(label);
    const explicitLabelCalories = caloriesFromNutritionLabel(input.observation);
    const dishType = explicitLabelCalories ? "packaged" : inferDishType(label);
    const portion = portionFromObservation(input.observation.amount_g, input.observation.serving_g);
    const match = explicitLabelCalories ? null : await this.safeNutritionLookup(label, genericLabel);
    const estimate = explicitLabelCalories
      ? estimateFromExplicitCalories(explicitLabelCalories.kcal, portion)
      : match
      ? estimateFromPer100g(match.per100g, portion)
      : fallbackEstimate(input.observation);
    const confidence = explicitLabelCalories ? "high" : confidenceFrom(input.observation.confidence, Boolean(match), dishType);

    return {
      id: `broker-${await stableDigest([input.photoSha25616, input.modelId, label])}`,
      primaryLabel: titleCase(label),
      genericLabel,
      dishType,
      portion: estimate.portion,
      nutrition: estimate.nutrition,
      macronutrients: estimate.macronutrients,
      confidence,
      assumptions: assumptionsFor({
        dishType,
        matched: Boolean(match),
        explicitNutritionLabel: Boolean(explicitLabelCalories),
        observationConfidence: input.observation.confidence
      }),
      evidence: [
        {
          provider: input.modelId.startsWith("gpt-") ? "openai_responses" : "deterministic_fixture",
          providerID: input.modelId,
          matchedName: "food photo observation",
          servingBasis: "image_observation"
        },
        ...(explicitLabelCalories ? [{
          provider: "visible_nutrition_label",
          providerID: `label:${input.photoSha25616}`,
          matchedName: explicitLabelCalories.matchedName,
          servingBasis: explicitLabelCalories.servingBasis
        }] : []),
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

function genericFoodLabel(label: string): string {
  const normalized = label.trim().toLowerCase();
  if (normalized.includes("apple")) return "apple";
  if (normalized.includes("kombucha")) return "kombucha";
  if (normalized.includes("risotto")) return "risotto";
  if (normalized.includes("salad")) return "salad";
  return normalized || "meal";
}

function inferDishType(label: string): DishType {
  const normalized = label.toLowerCase();
  if (
    normalized.includes("package") ||
    normalized.includes("bottle") ||
    normalized.includes("can") ||
    normalized.includes("bar") ||
    normalized.includes("label") ||
    normalized.includes("kombucha") ||
    normalized.includes("beverage") ||
    normalized.includes("drink")
  ) return "packaged";
  if (normalized.includes("risotto") || normalized.includes("bowl") || normalized.includes("plate") || normalized.includes("salad")) return "mixed";
  if (normalized.includes("meal") || normalized.includes("unknown")) return "unknown";
  return "single";
}

function confidenceFrom(value: number, hasNutritionMatch: boolean, dishType: DishType): EstimateConfidence {
  if (hasNutritionMatch && value >= 0.8 && dishType !== "mixed") return "high";
  if (hasNutritionMatch && value >= 0.55) return "medium";
  return "low";
}

function assumptionsFor(input: {
  dishType: DishType;
  matched: boolean;
  explicitNutritionLabel: boolean;
  observationConfidence: number;
}) {
  const assumptions = [
    { id: "photo-estimate", label: "estimate from selected meal photo", isEnabled: true },
    { id: "user-confirmation", label: "review before saving", isEnabled: true }
  ];

  if (input.explicitNutritionLabel) {
    assumptions.push({ id: "visible-nutrition-label", label: "visible label calories used without generic rescaling", isEnabled: true });
  }
  if (input.dishType === "mixed") {
    assumptions.push({ id: "mixed-dish-components", label: "mixed dish ingredients may vary", isEnabled: true });
  }
  if (!input.matched && !input.explicitNutritionLabel) {
    assumptions.push({ id: "model-only-nutrition", label: "nutrition database match unavailable; range is wider", isEnabled: true });
  }
  if (input.observationConfidence < 0.7 && !input.explicitNutritionLabel) {
    assumptions.push({ id: "portion-uncertain", label: "portion size needs review", isEnabled: true });
  }
  return assumptions;
}

function caloriesFromNutritionLabel(observation: FoodObservation): {
  kcal: number;
  matchedName: string;
  servingBasis: string;
} | null {
  const label = observation.nutrition_label;
  if (!label?.is_visible) {
    return null;
  }

  const matchedName = label.source_text?.trim() || "visible nutrition label";
  if (isSafePositiveKcal(label.calories_per_container)) {
    return {
      kcal: label.calories_per_container,
      matchedName,
      servingBasis: "per_container_label"
    };
  }

  if (
    isSafePositiveKcal(label.calories_per_serving) &&
    typeof label.servings_per_container === "number" &&
    label.servings_per_container > 0
  ) {
    return {
      kcal: Math.round(label.calories_per_serving * label.servings_per_container),
      matchedName,
      servingBasis: "per_serving_label"
    };
  }

  if (
    isSafePositiveKcal(label.calories_per_serving) &&
    (observation.servings === 1 || label.source_text?.match(/\b(bottle|container|package|whole)\b/iu))
  ) {
    return {
      kcal: label.calories_per_serving,
      matchedName,
      servingBasis: "single_serving_label"
    };
  }

  return null;
}

function isSafePositiveKcal(value: number | null): value is number {
  return typeof value === "number" && Number.isSafeInteger(value) && value > 0 && value <= 10000;
}

function titleCase(value: string): string {
  return value
    .split(/\s+/u)
    .filter(Boolean)
    .map((part) => part[0]?.toUpperCase() + part.slice(1))
    .join(" ");
}
