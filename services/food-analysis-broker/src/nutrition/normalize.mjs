const NUTRIENT_KEYS = ["kcal", "proteinGrams", "carbohydrateGrams", "fatGrams", "fiberGrams"];

export function roundTo(value, digits = 1) {
  const scale = 10 ** digits;
  return Math.round((value + Number.EPSILON) * scale) / scale;
}

export function roundKcal(value) {
  return Math.round(value);
}

export function normalizePer100g(input) {
  const nutrients = {};

  for (const key of NUTRIENT_KEYS) {
    const raw = input?.[key] ?? 0;
    if (typeof raw !== "number" || !Number.isFinite(raw) || raw < 0) {
      throw new TypeError(`Invalid per_100g nutrient '${key}'`);
    }
    nutrients[key] = raw;
  }

  return nutrients;
}

export function scaleNutrients(per100g, grams, { kcalDigits = 0, macroDigits = 1 } = {}) {
  if (typeof grams !== "number" || !Number.isFinite(grams) || grams < 0) {
    throw new TypeError("Portion grams must be a non-negative finite number");
  }

  const normalized = normalizePer100g(per100g);
  const factor = grams / 100;

  return {
    kcal: kcalDigits === 0 ? roundKcal(normalized.kcal * factor) : roundTo(normalized.kcal * factor, kcalDigits),
    proteinGrams: roundTo(normalized.proteinGrams * factor, macroDigits),
    carbohydrateGrams: roundTo(normalized.carbohydrateGrams * factor, macroDigits),
    fatGrams: roundTo(normalized.fatGrams * factor, macroDigits),
    fiberGrams: roundTo(normalized.fiberGrams * factor, macroDigits),
  };
}
export function makePortionRange({ gramsMin, gramsMode, gramsMax }) {
  const values = [gramsMin, gramsMode, gramsMax];
  if (values.some((value) => typeof value !== "number" || !Number.isFinite(value) || value < 0)) {
    throw new TypeError("Portion range must contain finite non-negative grams");
  }
  if (!(gramsMin <= gramsMode && gramsMode <= gramsMax)) {
    throw new RangeError("Portion range must satisfy gramsMin <= gramsMode <= gramsMax");
  }
  return {
    gramsMin: Math.round(gramsMin),
    gramsMode: Math.round(gramsMode),
    gramsMax: Math.round(gramsMax),
  };
}

export function estimateNutrientRanges(per100g, portion) {
  const normalizedPortion = makePortionRange(portion);
  const min = scaleNutrients(per100g, normalizedPortion.gramsMin);
  const mode = scaleNutrients(per100g, normalizedPortion.gramsMode);
  const max = scaleNutrients(per100g, normalizedPortion.gramsMax);

  return {
    portion: normalizedPortion,
    nutrition: {
      minKcal: min.kcal,
      modeKcal: mode.kcal,
      maxKcal: max.kcal,
    },
    macronutrients: {
      proteinGrams: mode.proteinGrams,
      carbohydrateGrams: mode.carbohydrateGrams,
      fatGrams: mode.fatGrams,
      fiberGrams: mode.fiberGrams,
    },
    macronutrientRanges: {
      proteinGrams: { min: min.proteinGrams, mode: mode.proteinGrams, max: max.proteinGrams },
      carbohydrateGrams: {
        min: min.carbohydrateGrams,
        mode: mode.carbohydrateGrams,
        max: max.carbohydrateGrams,
      },
      fatGrams: { min: min.fatGrams, mode: mode.fatGrams, max: max.fatGrams },
      fiberGrams: { min: min.fiberGrams, mode: mode.fiberGrams, max: max.fiberGrams },
    },
  };
}

export function sumNutrients(items) {
  const totals = Object.fromEntries(NUTRIENT_KEYS.map((key) => [key, 0]));

  for (const item of items) {
    const nutrients = normalizePer100g(item.per100g);
    const grams = item.grams ?? item.gramsMode;
    if (typeof grams !== "number" || !Number.isFinite(grams) || grams < 0) {
      throw new TypeError("Component grams must be a non-negative finite number");
    }
    const factor = grams / 100;
    for (const key of NUTRIENT_KEYS) {
      totals[key] += nutrients[key] * factor;
    }
  }

  return {
    kcal: roundKcal(totals.kcal),
    proteinGrams: roundTo(totals.proteinGrams, 1),
    carbohydrateGrams: roundTo(totals.carbohydrateGrams, 1),
    fatGrams: roundTo(totals.fatGrams, 1),
    fiberGrams: roundTo(totals.fiberGrams, 1),
  };
}

export function estimateComponentRanges(components) {
  const byPoint = (point) =>
    sumNutrients(
      components.map((component) => ({
        per100g: component.per100g,
        grams: component.portion[`grams${point}`],
      })),
    );

  const min = byPoint("Min");
  const mode = byPoint("Mode");
  const max = byPoint("Max");
  const portion = makePortionRange({
    gramsMin: components.reduce((sum, component) => sum + component.portion.gramsMin, 0),
    gramsMode: components.reduce((sum, component) => sum + component.portion.gramsMode, 0),
    gramsMax: components.reduce((sum, component) => sum + component.portion.gramsMax, 0),
  });

  return {
    portion,
    nutrition: {
      minKcal: min.kcal,
      modeKcal: mode.kcal,
      maxKcal: max.kcal,
    },
    macronutrients: {
      proteinGrams: mode.proteinGrams,
      carbohydrateGrams: mode.carbohydrateGrams,
      fatGrams: mode.fatGrams,
      fiberGrams: mode.fiberGrams,
    },
    macronutrientRanges: {
      proteinGrams: { min: min.proteinGrams, mode: mode.proteinGrams, max: max.proteinGrams },
      carbohydrateGrams: {
        min: min.carbohydrateGrams,
        mode: mode.carbohydrateGrams,
        max: max.carbohydrateGrams,
      },
      fatGrams: { min: min.fatGrams, mode: mode.fatGrams, max: max.fatGrams },
      fiberGrams: { min: min.fiberGrams, mode: mode.fiberGrams, max: max.fiberGrams },
    },
  };
}
