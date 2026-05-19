import type { MealMacronutrients, NutritionRange, PortionEstimate } from "./types.js";

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

export function portionFromObservation(amountGrams: number | null, servingGrams: number | null): PortionEstimate {
  const mode = positiveInteger(amountGrams ?? servingGrams ?? 300);
  return {
    gramsMin: Math.max(1, Math.round(mode * 0.75)),
    gramsMode: mode,
    gramsMax: Math.max(mode, Math.round(mode * 1.25))
  };
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

export function fallbackEstimate(observation: {
  total_kcal: number;
  kcal_variance: number;
  amount_g: number | null;
  serving_g: number | null;
}): NutritionEstimate {
  const modeKcal = positiveInteger(observation.total_kcal);
  const variance = Math.max(0, positiveInteger(observation.kcal_variance));
  const portion = portionFromObservation(observation.amount_g, observation.serving_g);
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

function round1(value: number): number {
  return Math.round((value + Number.EPSILON) * 10) / 10;
}
