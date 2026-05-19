import assert from "node:assert/strict";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

import { resolveFoodAnalysisCandidate } from "../src/resolver/foodAnalysisResolver.mjs";
import {
  FixtureBackedUsdaFoodDataCentralProvider,
  LookupIntent,
} from "../src/resolver/usdaFoodDataCentral.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const fixturePath = join(here, "fixtures", "usda-fdc-foods.json");

async function fixtureProvider() {
  return FixtureBackedUsdaFoodDataCentralProvider.fromFixture(fixturePath);
}

test("resolves an apple through simple generic USDA fixture evidence", async () => {
  const candidate = await resolveFoodAnalysisCandidate(
    {
      id: "test-fuji-apple",
      primaryLabel: "Fuji apple",
      genericLabel: "apple",
      dishType: "single",
      portion: { gramsMin: 140, gramsMode: 170, gramsMax: 210 },
      assumptions: [{ id: "single-item", label: "single medium apple", isEnabled: true }],
    },
    { providers: { usdaFoodDataCentral: await fixtureProvider() } },
  );

  assert.equal(candidate.primaryLabel, "Fuji apple");
  assert.equal(candidate.dishType, "single");
  assert.deepEqual(candidate.nutrition, {
    minKcal: 88,
    modeKcal: 107,
    maxKcal: 132,
  });
  assert.deepEqual(candidate.macronutrients, {
    proteinGrams: 0.3,
    carbohydrateGrams: 25.8,
    fatGrams: 0.3,
    fiberGrams: 3.6,
  });
  assert.deepEqual(candidate.evidence, [
    {
      provider: "usda_fdc",
      providerID: "1750340",
      matchedName: "Apples, raw, fuji, with skin",
      servingBasis: "per_100g",
    },
  ]);
  assert.equal(candidate.resolver.selectedIntent, LookupIntent.SIMPLE_GENERIC);
  assert.deepEqual(
    candidate.resolver.attempts.map((attempt) => [attempt.intent, attempt.matched]),
    [[LookupIntent.SIMPLE_GENERIC, true]],
  );
  assert.equal(candidate.userConfirmationRequired, true);
});

test("resolves risotto by falling back to mixed dish component reconstruction", async () => {
  const candidate = await resolveFoodAnalysisCandidate(
    {
      id: "test-mushroom-risotto",
      primaryLabel: "Mushroom risotto",
      genericLabel: "risotto",
      dishType: "mixed",
      portion: { gramsMin: 260, gramsMode: 320, gramsMax: 390 },
      assumptions: [
        { id: "rice-base", label: "rice base", isEnabled: true },
        { id: "butter-oil", label: "butter or oil likely", isEnabled: true },
      ],
    },
    { providers: { usdaFoodDataCentral: await fixtureProvider() } },
  );

  assert.equal(candidate.primaryLabel, "Mushroom risotto");
  assert.equal(candidate.dishType, "mixed");
  assert.deepEqual(candidate.portion, {
    gramsMin: 250,
    gramsMode: 320,
    gramsMax: 400,
  });
  assert.deepEqual(candidate.nutrition, {
    minKcal: 434,
    modeKcal: 606,
    maxKcal: 815,
  });
  assert.deepEqual(candidate.macronutrients, {
    proteinGrams: 17.2,
    carbohydrateGrams: 66,
    fatGrams: 30.1,
    fiberGrams: 1.4,
  });
  assert.equal(candidate.resolver.selectedIntent, LookupIntent.MIXED_COMPONENT_RECONSTRUCTION);
  assert.deepEqual(
    candidate.resolver.attempts.map((attempt) => [attempt.intent, attempt.matched]),
    [
      [LookupIntent.SIMPLE_GENERIC, false],
      [LookupIntent.PREPARED_FNDDS, false],
      [LookupIntent.MIXED_COMPONENT_RECONSTRUCTION, true],
    ],
  );
  assert.equal(candidate.evidence[0].provider, "usda_fdc");
  assert.equal(candidate.evidence[0].providerID, "fixture-risotto-mushroom-components");
  assert.equal(candidate.evidence[0].servingBasis, "recipe_component");
  assert.ok(candidate.evidence.some((evidence) => evidence.providerID === "1102653"));
  assert.ok(candidate.evidence.some((evidence) => evidence.providerID === "173410"));
});
