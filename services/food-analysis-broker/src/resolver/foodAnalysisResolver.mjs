import { estimateComponentRanges, estimateNutrientRanges } from "../nutrition/normalize.mjs";
import { LookupIntent, USDA_FDC_PROVIDER } from "./usdaFoodDataCentral.mjs";

export function orderedLookupIntents(input) {
  const intents = [];

  if (input.barcode) {
    intents.push(LookupIntent.BARCODE_BRANDED);
  }

  if (input.dishType === "single" || input.dishType === "packaged" || input.genericLabel) {
    intents.push(LookupIntent.SIMPLE_GENERIC);
  }

  intents.push(LookupIntent.PREPARED_FNDDS);

  if (input.dishType === "mixed" || input.allowComponentFallback !== false) {
    intents.push(LookupIntent.MIXED_COMPONENT_RECONSTRUCTION);
  }

  return [...new Set(intents)];
}

export async function resolveFoodAnalysisCandidate(input, { providers }) {
  if (!providers?.usdaFoodDataCentral) {
    throw new Error("resolveFoodAnalysisCandidate requires providers.usdaFoodDataCentral");
  }

  const attempts = [];

  for (const intent of orderedLookupIntents(input)) {
    const match = await providers.usdaFoodDataCentral.lookup({
      intent,
      barcode: input.barcode,
      name: input.primaryLabel,
      genericLabel: input.genericLabel,
      preparedLabel: input.preparedLabel,
    });

    attempts.push({ provider: USDA_FDC_PROVIDER, intent, matched: Boolean(match) });

    if (!match) {
      continue;
    }

    const normalized = match.components
      ? estimateComponentRanges(match.components)
      : estimateNutrientRanges(match.per100g, input.portion);

    return toFoodAnalysisCandidate({
      input,
      match,
      normalized,
      intent,
      attempts,
    });
  }

  throw new Error(`No nutrition match for '${input.primaryLabel ?? input.genericLabel ?? "unknown food"}'`);
}

function toFoodAnalysisCandidate({ input, match, normalized, intent, attempts }) {
  const evidence = [
    {
      provider: match.provider,
      providerID: match.fdcId,
      matchedName: match.description,
      servingBasis: match.servingBasis,
    },
  ];

  if (match.components) {
    evidence.push(
      ...match.components.map((component) => ({
        provider: match.provider,
        providerID: component.fdcId,
        matchedName: component.description,
        servingBasis: "recipe_component",
      })),
    );
  }

  return {
    id: input.id ?? makeCandidateId(input.primaryLabel, match.fdcId),
    primaryLabel: input.primaryLabel,
    genericLabel: input.genericLabel,
    dishType: input.dishType ?? inferDishType(intent),
    portion: normalized.portion,
    nutrition: normalized.nutrition,
    macronutrients: normalized.macronutrients,
    macronutrientRanges: normalized.macronutrientRanges,
    confidence: confidenceForIntent(intent),
    assumptions: input.assumptions ?? [],
    evidence,
    resolver: {
      selectedIntent: intent,
      attempts,
    },
    userConfirmationRequired: true,
  };
}

function makeCandidateId(label, providerId) {
  const slug = String(label ?? "food")
    .toLowerCase()
    .replace(/[^a-z0-9]+/gu, "-")
    .replace(/^-|-$/gu, "");
  return `resolver-${slug}-${providerId}`;
}

function inferDishType(intent) {
  if (intent === LookupIntent.BARCODE_BRANDED) {
    return "packaged";
  }
  if (intent === LookupIntent.MIXED_COMPONENT_RECONSTRUCTION) {
    return "mixed";
  }
  return "single";
}

function confidenceForIntent(intent) {
  switch (intent) {
    case LookupIntent.BARCODE_BRANDED:
      return "high";
    case LookupIntent.SIMPLE_GENERIC:
      return "medium";
    case LookupIntent.PREPARED_FNDDS:
      return "medium";
    case LookupIntent.MIXED_COMPONENT_RECONSTRUCTION:
      return "low";
    default:
      return "low";
  }
}
