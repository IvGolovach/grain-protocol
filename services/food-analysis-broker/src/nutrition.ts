import type { MealMacronutrients, NutritionRange, PortionBasis, PortionEstimate } from "./types.js";

export type Per100gNutrients = {
  kcal: number;
  proteinGrams: number;
  carbohydrateGrams: number;
  fatGrams: number;
  fiberGrams?: number;
};

export type NutritionEstimate = {
  portion: PortionEstimate;
  nutrition: NutritionRange;
  macronutrients: MealMacronutrients;
};

export type PortionResolution = {
  portion: PortionEstimate;
  basis: PortionBasis;
  confidence: number;
  usedDefault: boolean;
  derivedAmountGrams: number | null;
};

export function resolvePortionFromObservation(input: {
  amountGrams: number | null;
  servingGrams: number | null;
  servings: number | null;
  basis: PortionBasis;
  confidence: number;
}): PortionResolution {
  const amount = positiveIntegerOrNull(input.amountGrams);
  const serving = positiveIntegerOrNull(input.servingGrams);
  const servingCount = positiveIntegerOrNull(input.servings);
  const derivedAmount = amount ?? (serving === null ? null : serving * (servingCount ?? 1));
  const usedDefault = derivedAmount === null;
  const mode = positiveInteger(derivedAmount ?? 300);
  const spread = portionSpread(input.basis, input.confidence, usedDefault);
  return {
    portion: {
      gramsMin: Math.max(1, Math.round(mode * spread.minFactor)),
      gramsMode: mode,
      gramsMax: Math.max(mode, Math.round(mode * spread.maxFactor))
    },
    basis: input.basis,
    confidence: input.confidence,
    usedDefault,
    derivedAmountGrams: derivedAmount
  };
}

export function portionFromObservation(
  amountGrams: number | null,
  servingGrams: number | null,
  servings: number | null,
  basis: PortionBasis,
  confidence: number
): PortionEstimate {
  return resolvePortionFromObservation({
    amountGrams,
    servingGrams,
    servings,
    basis,
    confidence
  }).portion;
}

export function estimateFromPer100g(per100g: Per100gNutrients, portion: PortionEstimate): NutritionEstimate {
  validatePer100g(per100g);
  validatePortion(portion);
  const min = scale(per100g, portion.gramsMin);
  const mode = scale(per100g, portion.gramsMode);
  const max = scale(per100g, portion.gramsMax);
  return {
    portion,
    nutrition: {
      minKcal: min.kcal,
      modeKcal: mode.kcal,
      maxKcal: max.kcal
    },
    macronutrients: {
      proteinGrams: mode.proteinGrams,
      carbohydrateGrams: mode.carbohydrateGrams,
      fatGrams: mode.fatGrams,
      ...(mode.fiberGrams === undefined ? {} : { fiberGrams: mode.fiberGrams })
    }
  };
}

export function estimateFromExplicitCalories(kcal: number, portion: PortionEstimate): NutritionEstimate {
  validatePortion(portion);
  const modeKcal = positiveInteger(kcal);
  return {
    portion,
    nutrition: {
      minKcal: modeKcal,
      modeKcal,
      maxKcal: modeKcal
    },
    macronutrients: {
      proteinGrams: 0,
      carbohydrateGrams: 0,
      fatGrams: 0
    }
  };
}

export function fallbackEstimate(observation: {
  total_kcal: number;
  kcal_variance: number;
  amount_g: number | null;
  serving_g: number | null;
  servings: number | null;
  portion_basis: PortionBasis;
  portion_confidence: number;
}): NutritionEstimate {
  const modeKcal = positiveInteger(observation.total_kcal);
  const variance = Math.max(0, positiveInteger(observation.kcal_variance));
  const portion = portionFromObservation(
    observation.amount_g,
    observation.serving_g,
    observation.servings,
    observation.portion_basis,
    observation.portion_confidence
  );
  return {
    portion,
    nutrition: {
      minKcal: Math.max(0, modeKcal - variance),
      modeKcal,
      maxKcal: modeKcal + variance
    },
    macronutrients: {
      proteinGrams: 0,
      carbohydrateGrams: 0,
      fatGrams: 0
    }
  };
}

function scale(per100g: Per100gNutrients, grams: number): Required<MealMacronutrients> & { kcal: number } {
  const factor = grams / 100;
  return {
    kcal: Math.round(per100g.kcal * factor),
    proteinGrams: round1(per100g.proteinGrams * factor),
    carbohydrateGrams: round1(per100g.carbohydrateGrams * factor),
    fatGrams: round1(per100g.fatGrams * factor),
    fiberGrams: round1((per100g.fiberGrams ?? 0) * factor)
  };
}

function validatePer100g(per100g: Per100gNutrients): void {
  for (const [key, value] of Object.entries(per100g)) {
    if (typeof value !== "number" || !Number.isFinite(value) || value < 0) {
      throw new TypeError(`invalid per_100g nutrient ${key}`);
    }
  }
}

function validatePortion(portion: PortionEstimate): void {
  if (
    !Number.isSafeInteger(portion.gramsMin) ||
    !Number.isSafeInteger(portion.gramsMode) ||
    !Number.isSafeInteger(portion.gramsMax) ||
    portion.gramsMin < 0 ||
    portion.gramsMode < portion.gramsMin ||
    portion.gramsMax < portion.gramsMode
  ) {
    throw new TypeError("invalid portion range");
  }
}

function positiveInteger(value: number): number {
  if (!Number.isSafeInteger(value) || value < 0) {
    return 0;
  }
  return value;
}

function positiveIntegerOrNull(value: number | null): number | null {
  if (value === null || !Number.isSafeInteger(value) || value <= 0) {
    return null;
  }
  return value;
}

function portionSpread(
  basis: PortionBasis,
  confidence: number,
  usedDefault: boolean
): { minFactor: number; maxFactor: number } {
  if (usedDefault || basis === "unknown") {
    return { minFactor: 0.5, maxFactor: 1.5 };
  }
  if (basis === "visible_label" || basis === "package_serving") {
    return confidence >= 0.75
      ? { minFactor: 0.9, maxFactor: 1.1 }
      : { minFactor: 0.75, maxFactor: 1.25 };
  }
  if (confidence <= 0.45) {
    return { minFactor: 0.5, maxFactor: 1.75 };
  }
  return { minFactor: 0.65, maxFactor: 1.4 };
}

function round1(value: number): number {
  return Math.round((value + Number.EPSILON) * 10) / 10;
}
