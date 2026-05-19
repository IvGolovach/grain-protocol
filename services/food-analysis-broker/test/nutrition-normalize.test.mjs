import assert from "node:assert/strict";
import test from "node:test";

import {
  estimateComponentRanges,
  estimateNutrientRanges,
  scaleNutrients,
} from "../src/nutrition/normalize.mjs";

test("scales per_100g nutrients to deterministic portion grams", () => {
  const result = scaleNutrients(
    {
      kcal: 63,
      proteinGrams: 0.2,
      carbohydrateGrams: 15.2,
      fatGrams: 0.2,
      fiberGrams: 2.1,
    },
    170,
  );

  assert.deepEqual(result, {
    kcal: 107,
    proteinGrams: 0.3,
    carbohydrateGrams: 25.8,
    fatGrams: 0.3,
    fiberGrams: 3.6,
  });
});

test("produces kcal and macronutrient ranges from portion min/mode/max", () => {
  const result = estimateNutrientRanges(
    {
      kcal: 63,
      proteinGrams: 0.2,
      carbohydrateGrams: 15.2,
      fatGrams: 0.2,
      fiberGrams: 2.1,
    },
    { gramsMin: 140, gramsMode: 170, gramsMax: 210 },
  );

  assert.deepEqual(result.nutrition, {
    minKcal: 88,
    modeKcal: 107,
    maxKcal: 132,
  });
  assert.deepEqual(result.macronutrients, {
    proteinGrams: 0.3,
    carbohydrateGrams: 25.8,
    fatGrams: 0.3,
    fiberGrams: 3.6,
  });
  assert.deepEqual(result.macronutrientRanges.carbohydrateGrams, {
    min: 21.3,
    mode: 25.8,
    max: 31.9,
  });
});

test("reconstructs mixed dish nutrition by summing component portions", () => {
  const result = estimateComponentRanges([
    {
      portion: { gramsMin: 100, gramsMode: 150, gramsMax: 200 },
      per100g: { kcal: 130, proteinGrams: 2.7, carbohydrateGrams: 28.2, fatGrams: 0.3, fiberGrams: 0.4 },
    },
    {
      portion: { gramsMin: 10, gramsMode: 20, gramsMax: 30 },
      per100g: { kcal: 717, proteinGrams: 0.9, carbohydrateGrams: 0.1, fatGrams: 81.1, fiberGrams: 0 },
    },
  ]);

  assert.deepEqual(result.portion, {
    gramsMin: 110,
    gramsMode: 170,
    gramsMax: 230,
  });
  assert.deepEqual(result.nutrition, {
    minKcal: 202,
    modeKcal: 338,
    maxKcal: 475,
  });
  assert.equal(result.macronutrients.fatGrams, 16.7);
});
