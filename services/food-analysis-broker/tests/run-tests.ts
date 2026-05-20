#!/usr/bin/env node

import { once } from "node:events";
import assert from "node:assert/strict";
import { createServer } from "node:http";

import { OpenAiFoodAnalyzer } from "../src/analyzers.js";
import { FoodAnalysisCandidateResolver } from "../src/resolver.js";
import { createBrokerServer } from "../src/server.js";
import {
  CompositeFoodSearchProvider,
  FixtureFoodSearchProvider,
  OpenFoodFactsSearchProvider,
  UsdaBrandedFoodSearchProvider,
  foodSearchProviderFromEnv
} from "../src/search.js";
import { FixtureNutritionProvider, type NutritionProvider } from "../src/usda.js";
import type { FoodAnalyzer, FoodAnalyzePhotoRequest, FoodObservation, FoodSearchProvider } from "../src/types.js";

const sampleRequest: FoodAnalyzePhotoRequest = {
  request_id: "test-request-001",
  capture_id: "capture-breakfast-001",
  client: {
    platform: "ios",
    app_version: "0.1.0",
    device_id_hash: "device-hash-fixture"
  },
  hints: {
    meal_context: "breakfast",
    locale: "en-US",
    timezone: "America/Los_Angeles"
  },
  photo: {
    media_type: "image/jpeg",
    bytes_b64: Buffer.from("not-a-real-image-fixture").toString("base64")
  },
  draft: {
    draft_id: "draft-breakfast-001",
    payload_cid: "food-photo:capture-breakfast-001",
    ts_ms: 1717200000000
  }
};

const checks: Array<{ name: string; pass: boolean; detail?: string }> = [];

async function main(): Promise<number> {
  await testMockEndpoint();
  await testFoodSearchCommonFoodFixture();
  await testFoodSearchFixtureEndpoint();
  await testFoodSearchBarcodeFixture();
  await testOpenFoodFactsBarcodeProvider();
  await testOpenFoodFactsBarcodeProviderExpandsUpcE();
  await testOpenFoodFactsBarcodeProviderDerivesEnergyFromKilojoules();
  await testOpenFoodFactsBarcodeProviderDerivesEnergyFromServing();
  await testUsdaBrandedBarcodeProvider();
  await testUsdaBrandedBarcodeProviderMatchesCanonicalCandidates();
  await testFoodSearchProviderFromEnvUsesOpenFoodFactsByDefault();
  await testFoodSearchProviderFromEnvCanDisableExternalProviders();
  await testCompositeFoodSearchProviderFallsBackAfterProviderFailure();
  await testPayloadCap();
  await testOpenAiRequestShapeAndResolverBoundary();
  await testVisibleNutritionLabelOverridesDatabasePortionScaling();
  await testUpstreamSchemaValidation();

  const failed = checks.filter((entry) => !entry.pass);
  process.stdout.write(`${JSON.stringify({ total: checks.length, failed: failed.length, checks }, null, 2)}\n`);
  return failed.length === 0 ? 0 : 1;
}

async function testMockEndpoint(): Promise<void> {
  await withServer(undefined, async (baseUrl) => {
    const response = await postJson(`${baseUrl}/v1/food/analyze-photo`, sampleRequest);
    assert.equal(response.status, 200);
    const body = await response.json() as Record<string, unknown>;
    assert.equal(body.ok, true);
    assert.equal(body.mode, "mock");
    assert.equal((body.privacy as Record<string, unknown>).store, false);

    const serialized = JSON.stringify(body);
    assert.equal(serialized.includes(sampleRequest.photo.bytes_b64), false);
    assert.equal(serialized.includes("not-a-real-image-fixture"), false);

    const draft = body.draft as Record<string, unknown>;
    assert.equal(draft.source, "photo_estimate");
    assert.equal(draft.source_class, "estimated");
    assert.equal((draft.privacy as Record<string, unknown>).raw_photo_persistence, "forbidden");
    const candidate = body.candidate as Record<string, unknown>;
    assert.equal(candidate.userConfirmationRequired, true);
    assert.equal(candidate.confidence, "low");
    pass("mock endpoint returns draft without raw image material");
  });
}

async function testFoodSearchCommonFoodFixture(): Promise<void> {
  await withServer(undefined, async (baseUrl) => {
    const response = await postJson(`${baseUrl}/v1/food/search`, {
      request_id: "common-food-fixture-001",
      query: "white rice",
      limit: 3
    });
    assert.equal(response.status, 200);
    const body = await response.json() as Record<string, unknown>;
    assert.equal(body.ok, true);

    const results = body.results as Array<Record<string, unknown>>;
    const rice = results.find((result) => result.result_id === "food-search:fixture-white-rice");
    assertRecord(rice);
    assert.equal(rice.primary_label, "Cooked white rice");
    assert.equal(rice.category, "common_food");
    assert.equal(rice.source_label, "deterministic_fixture");
    assert.equal(rice.trust_label, "fixture_verified");
    const evidence = rice.provider_evidence as Array<Record<string, unknown>>;
    assert.equal(evidence[0].provider_id, "fixture-white-rice");
    assert.equal(evidence[0].match_type, "name");
  });
  pass("food search returns normalized common-food fixture results");
}

async function testFoodSearchFixtureEndpoint(): Promise<void> {
  await withServer(undefined, async (baseUrl) => {
    const response = await postJson(`${baseUrl}/v1/food/search`, {
      request_id: "search-fixture-001",
      query: "casein protein",
      limit: 5
    });
    assert.equal(response.status, 200);
    const body = await response.json() as Record<string, unknown>;
    assert.equal(body.ok, true);
    assert.equal(body.request_id, "search-fixture-001");

    const results = body.results as Array<Record<string, unknown>>;
    assert.equal(Array.isArray(results), true);
    const casein = results.find((result) => result.result_id === "food-search:fixture-casein-protein");
    assertRecord(casein);
    assert.equal(casein.primary_label, "Casein protein powder");
    assert.equal(casein.generic_label, "casein protein powder");
    assert.equal(casein.category, "supplement");
    assert.equal(casein.source_label, "deterministic_fixture");
    assert.equal(casein.trust_label, "fixture_verified");

    const match = casein.match as Record<string, unknown>;
    assert.equal(match.type, "name");
    assert.equal(match.score, 0.98);
    const serving = casein.serving as Record<string, unknown>;
    assert.equal(serving.basis, "per_100g");
    assert.equal(serving.serving_size_g, 30);
    const nutrition = casein.nutrition as Record<string, unknown>;
    const per100g = nutrition.per_100g as Record<string, unknown>;
    assert.equal(per100g.protein_g, 80);

    const evidence = casein.provider_evidence as Array<Record<string, unknown>>;
    assert.equal(Array.isArray(evidence), true);
    assert.equal(evidence.length, 1);
    assert.equal(evidence[0].provider, "deterministic_fixture");
    assert.equal(evidence[0].provider_id, "fixture-casein-protein");
    assert.equal(evidence[0].matched_name, "Casein protein powder");
    assert.equal(evidence[0].source_label, "curated_fixture");
    assert.equal(evidence[0].trust_label, "fixture_verified");
  });
  pass("food search returns normalized casein fixture results with provider evidence");
}

async function testFoodSearchBarcodeFixture(): Promise<void> {
  await withServer(undefined, async (baseUrl) => {
    const response = await postJson(`${baseUrl}/v1/food/search`, {
      request_id: "barcode-fixture-001",
      barcode: "012345678905"
    });
    assert.equal(response.status, 200);
    const body = await response.json() as Record<string, unknown>;
    assert.equal(body.ok, true);
    assert.equal(body.barcode, "012345678905");

    const results = body.results as Array<Record<string, unknown>>;
    assert.equal(results.length, 1);
    const result = results[0];
    assert.equal(result.result_id, "food-search:fixture-kombucha-bottle");
    assert.equal(result.primary_label, "Ginger lemon kombucha");
    assert.equal(result.brand_label, "Grain Fixture Kitchen");
    assert.equal(result.category, "packaged_beverage");
    assert.equal(result.source_label, "deterministic_fixture");
    assert.equal(result.trust_label, "barcode_fixture");

    const match = result.match as Record<string, unknown>;
    assert.equal(match.type, "barcode");
    assert.equal(match.score, 1);
    const evidence = result.provider_evidence as Array<Record<string, unknown>>;
    assert.equal(evidence[0].provider_id, "012345678905");
    assert.equal(evidence[0].match_type, "barcode");
    assert.equal(evidence[0].source_label, "curated_fixture");
    assert.equal(evidence[0].trust_label, "barcode_fixture");
  });
  pass("food search resolves barcode-like packaged kombucha fixture");
}

async function testOpenFoodFactsBarcodeProvider(): Promise<void> {
  const provider = new OpenFoodFactsSearchProvider({
    baseUrl: "https://off.example.test",
    userAgent: "MealMarkTests/1.0 (test@example.com)",
    fetchFn: async (url: string | URL, init?: RequestInit) => {
      assert.equal(String(url), "https://off.example.test/api/v2/product/012345678905.json?fields=code%2Cproduct_name%2Cgeneric_name%2Cbrands%2Ccategories_tags%2Cserving_quantity%2Cserving_size%2Cnutriments");
      assert.equal((init?.headers as Record<string, string>)["User-Agent"], "MealMarkTests/1.0 (test@example.com)");
      return new Response(JSON.stringify({
        status: 1,
        product: {
          code: "012345678905",
          product_name: "Ginger Lemon Kombucha",
          generic_name: "kombucha",
          brands: "Example Ferments",
          categories_tags: ["en:beverages", "en:kombuchas"],
          serving_quantity: "473",
          serving_size: "1 bottle (473 ml)",
          nutriments: {
            "energy-kcal_100g": 17,
            proteins_100g: 0,
            carbohydrates_100g: 4.2,
            fat_100g: 0,
            fiber_100g: 0
          }
        }
      }), { status: 200, headers: { "content-type": "application/json" } });
    }
  });

  const results = await provider.search({ barcode: "012345678905" });

  assert.equal(results.length, 1);
  assert.equal(results[0].primary_label, "Ginger Lemon Kombucha");
  assert.equal(results[0].brand_label, "Example Ferments");
  assert.equal(results[0].source_label, "open_food_facts");
  assert.equal(results[0].trust_label, "barcode_provider");
  assert.equal(results[0].serving.serving_size_g, 473);
  assert.equal(results[0].nutrition.per_100g.kcal, 17);
  assert.equal(results[0].provider_evidence[0].provider, "open_food_facts");
  assert.equal(results[0].provider_evidence[0].provider_id, "012345678905");
  pass("Open Food Facts barcode provider maps product data to search result");
}

async function testOpenFoodFactsBarcodeProviderExpandsUpcE(): Promise<void> {
  const requestedUrls: string[] = [];
  const provider = new OpenFoodFactsSearchProvider({
    baseUrl: "https://off.example.test",
    userAgent: "MealMarkTests/1.0 (test@example.com)",
    fetchFn: async (url: string | URL) => {
      requestedUrls.push(String(url));
      if (String(url).includes("/api/v2/product/042100005264.json")) {
        return new Response(JSON.stringify({
          status: 1,
          product: {
            code: "042100005264",
            product_name: "Small Pack Gum",
            generic_name: "gum",
            brands: "Tiny Pack",
            nutriments: {
              "energy-kcal_100g": 250,
              proteins_100g: 0,
              carbohydrates_100g: 95,
              fat_100g: 0
            }
          }
        }), { status: 200, headers: { "content-type": "application/json" } });
      }
      return new Response(JSON.stringify({ status: 0 }), { status: 200, headers: { "content-type": "application/json" } });
    }
  });

  const results = await provider.search({ barcode: "04252614" });

  assert.equal(requestedUrls.some((url) => url.includes("/api/v2/product/04252614.json")), true);
  assert.equal(requestedUrls.some((url) => url.includes("/api/v2/product/042100005264.json")), true);
  assert.equal(results.length, 1);
  assert.equal(results[0].primary_label, "Small Pack Gum");
  assert.equal(results[0].provider_evidence[0].provider_id, "042100005264");
  pass("Open Food Facts barcode provider expands UPC-E candidates before giving up");
}

async function testOpenFoodFactsBarcodeProviderDerivesEnergyFromKilojoules(): Promise<void> {
  const provider = new OpenFoodFactsSearchProvider({
    baseUrl: "https://off.example.test",
    userAgent: "MealMarkTests/1.0 (test@example.com)",
    fetchFn: async () => new Response(JSON.stringify({
      status: 1,
      product: {
        code: "1234567890123",
        product_name: "Sparkling Tea",
        generic_name: "tea",
        nutriments: {
          "energy-kj_100g": 418.4,
          proteins_100g: 0,
          carbohydrates_100g: 24,
          fat_100g: 0
        }
      }
    }), { status: 200, headers: { "content-type": "application/json" } })
  });

  const results = await provider.search({ barcode: "1234567890123" });

  assert.equal(results.length, 1);
  assert.equal(results[0].nutrition.per_100g.kcal, 100);
  pass("Open Food Facts barcode provider derives kcal from kJ per 100g");
}

async function testOpenFoodFactsBarcodeProviderDerivesEnergyFromServing(): Promise<void> {
  const provider = new OpenFoodFactsSearchProvider({
    baseUrl: "https://off.example.test",
    userAgent: "MealMarkTests/1.0 (test@example.com)",
    fetchFn: async () => new Response(JSON.stringify({
      status: 1,
      product: {
        code: "1234567890124",
        product_name: "Canned Soda",
        generic_name: "soda",
        serving_quantity: "355",
        serving_size: "1 can (355 ml)",
        nutriments: {
          "energy-kcal_serving": 20,
          carbohydrates_serving: 5.5,
          fat_serving: 0,
          proteins_serving: 0
        }
      }
    }), { status: 200, headers: { "content-type": "application/json" } })
  });

  const results = await provider.search({ barcode: "1234567890124" });

  assert.equal(results.length, 1);
  assert.equal(results[0].serving.serving_size_g, 355);
  assert.equal(results[0].nutrition.per_100g.kcal, 5.6);
  assert.equal(results[0].nutrition.per_100g.carbohydrate_g, 1.5);
  pass("Open Food Facts barcode provider derives per-100g nutrition from serving values");
}

async function testUsdaBrandedBarcodeProvider(): Promise<void> {
  const provider = new UsdaBrandedFoodSearchProvider({
    apiKey: "test-fdc-key",
    baseUrl: "https://fdc.example.test/fdc/v1",
    fetchFn: async (url: string | URL, init?: RequestInit) => {
      assert.equal(String(url), "https://fdc.example.test/fdc/v1/foods/search?api_key=test-fdc-key");
      assert.equal((init?.headers as Record<string, string>)["content-type"], "application/json");
      const body = JSON.parse(String(init?.body)) as Record<string, unknown>;
      assert.equal(body.query, "012345678905");
      assert.deepEqual(body.dataType, ["Branded"]);
      return new Response(JSON.stringify({
        foods: [
          {
            fdcId: 2105222,
            description: "GINGER LEMON KOMBUCHA",
            brandName: "Example Ferments",
            brandOwner: "Example Ferments LLC",
            gtinUpc: "012345678905",
            foodCategory: "Beverages",
            servingSize: 473,
            servingSizeUnit: "ml",
            foodNutrients: [
              { nutrientName: "Energy", unitName: "KCAL", value: 17 },
              { nutrientName: "Protein", unitName: "G", value: 0 },
              { nutrientName: "Carbohydrate, by difference", unitName: "G", value: 4.2 },
              { nutrientName: "Total lipid (fat)", unitName: "G", value: 0 },
              { nutrientName: "Fiber, total dietary", unitName: "G", value: 0 }
            ]
          }
        ]
      }), { status: 200, headers: { "content-type": "application/json" } });
    }
  });

  const results = await provider.search({ barcode: "012345678905" });

  assert.equal(results.length, 1);
  assert.equal(results[0].primary_label, "GINGER LEMON KOMBUCHA");
  assert.equal(results[0].brand_label, "Example Ferments");
  assert.equal(results[0].source_label, "usda_fdc");
  assert.equal(results[0].trust_label, "barcode_provider");
  assert.equal(results[0].provider_evidence[0].provider, "usda_fdc");
  assert.equal(results[0].provider_evidence[0].provider_id, "2105222");
  assert.equal(results[0].provider_evidence[0].match_type, "barcode");
  pass("USDA branded barcode provider maps GTIN result to search result");
}

async function testUsdaBrandedBarcodeProviderMatchesCanonicalCandidates(): Promise<void> {
  const provider = new UsdaBrandedFoodSearchProvider({
    apiKey: "test-fdc-key",
    baseUrl: "https://fdc.example.test/fdc/v1",
    fetchFn: async (_url: string | URL, init?: RequestInit) => {
      const body = JSON.parse(String(init?.body)) as Record<string, unknown>;
      if (body.query !== "042100005264") {
        return new Response(JSON.stringify({ foods: [] }), { status: 200, headers: { "content-type": "application/json" } });
      }
      return new Response(JSON.stringify({
        foods: [
          {
            fdcId: 3105222,
            description: "SMALL PACK GUM",
            brandName: "Tiny Pack",
            gtinUpc: "042100005264",
            foodCategory: "Candy",
            servingSize: 2,
            servingSizeUnit: "g",
            foodNutrients: [
              { nutrientNumber: "208", nutrientName: "Energy", unitName: "KCAL", value: 250 },
              { nutrientNumber: "203", nutrientName: "Protein", unitName: "G", value: 0 },
              { nutrientNumber: "205", nutrientName: "Carbohydrate, by difference", unitName: "G", value: 95 },
              { nutrientNumber: "204", nutrientName: "Total lipid (fat)", unitName: "G", value: 0 }
            ]
          }
        ]
      }), { status: 200, headers: { "content-type": "application/json" } });
    }
  });

  const results = await provider.search({ barcode: "04252614" });

  assert.equal(results.length, 1);
  assert.equal(results[0].primary_label, "SMALL PACK GUM");
  assert.equal(results[0].source_label, "usda_fdc");
  pass("USDA branded barcode provider matches expanded UPC-E canonical candidates");
}

async function testFoodSearchProviderFromEnvUsesOpenFoodFactsByDefault(): Promise<void> {
  const server = createServer((req, res) => {
    assert.equal(req.url, "/api/v2/product/4860019001346.json?fields=code%2Cproduct_name%2Cgeneric_name%2Cbrands%2Ccategories_tags%2Cserving_quantity%2Cserving_size%2Cnutriments");
    assert.equal(req.headers["user-agent"], "MealMark/0.1 (https://github.com/IvGolovach/grain-protocol)");
    res.setHeader("content-type", "application/json");
    res.end(JSON.stringify({
      status: 1,
      product: {
        code: "4860019001346",
        product_name: "BORJOMI",
        generic_name: "mineral water",
        brands: "Borjomi",
        categories_tags: ["en:beverages", "en:waters", "en:mineral-waters"],
        serving_quantity: "500",
        serving_size: "500 ml",
        nutriments: {
          "energy-kcal_100g": 0,
          proteins_100g: 0,
          carbohydrates_100g: 0,
          fat_100g: 0,
          fiber_100g: 0
        }
      }
    }));
  });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  const address = server.address();
  assert(address && typeof address === "object");
  try {
    const provider = foodSearchProviderFromEnv({
      OPEN_FOOD_FACTS_BASE_URL: `http://127.0.0.1:${address.port}`
    });
    const results = await provider.search({ barcode: "4860019001346" });
    assert.equal(results.length, 1);
    assert.equal(results[0].primary_label, "BORJOMI");
    assert.equal(results[0].source_label, "open_food_facts");
    assert.equal(results[0].nutrition.per_100g.kcal, 0);
  } finally {
    server.close();
    await once(server, "close");
  }
  pass("food search env provider uses Open Food Facts by default");
}

async function testFoodSearchProviderFromEnvCanDisableExternalProviders(): Promise<void> {
  const provider = foodSearchProviderFromEnv({ FOOD_SEARCH_LIVE: "0" });
  const results = await provider.search({ barcode: "012345678905" });
  assert.equal(results.length, 1);
  assert.equal(results[0].source_label, "deterministic_fixture");
  assert.equal(results[0].trust_label, "barcode_fixture");
  pass("food search env provider can disable external providers for deterministic tests");
}

async function testCompositeFoodSearchProviderFallsBackAfterProviderFailure(): Promise<void> {
  const provider = new CompositeFoodSearchProvider([
    {
      async search() {
        throw new Error("upstream unavailable");
      }
    },
    new FixtureFoodSearchProvider()
  ]);

  const results = await provider.search({ barcode: "012345678905" });

  assert.equal(results.length, 1);
  assert.equal(results[0].result_id, "food-search:fixture-kombucha-bottle");
  assert.equal(results[0].trust_label, "barcode_fixture");
  pass("composite food search falls back after provider failure");
}

async function testPayloadCap(): Promise<void> {
  await withServer(undefined, async (baseUrl) => {
    const response = await postJson(`${baseUrl}/v1/food/analyze-photo`, {
      ...sampleRequest,
      photo: {
        media_type: "image/jpeg",
        bytes_b64: Buffer.alloc(3 * 1024 * 1024 + 1).toString("base64")
      }
    });
    assert.equal(response.status, 413);
    const body = await response.json() as Record<string, unknown>;
    assert.equal(body.ok, false);
    assert.equal((body.error as Record<string, unknown>).code, "PAYLOAD_TOO_LARGE");
    pass("oversized image is rejected with explicit error shape");
  });
}

async function testOpenAiRequestShapeAndResolverBoundary(): Promise<void> {
  let captured: unknown;
  const analyzer = new OpenAiFoodAnalyzer({
    apiKey: "test-key",
    model: "gpt-test-vision",
    fetchFn: async (_url, init) => {
      captured = JSON.parse(String(init?.body));
      return new Response(JSON.stringify({
        output_text: JSON.stringify(fakeObservation())
      }), { status: 200, headers: { "content-type": "application/json" } });
    }
  });

  await withServer(analyzer, async (baseUrl) => {
    const response = await postJson(`${baseUrl}/v1/food/analyze-photo`, sampleRequest);
    assert.equal(response.status, 200);
    const body = await response.json() as Record<string, unknown>;
    assert.equal(body.mode, "openai");
    const draft = body.draft as Record<string, unknown>;
    assert.equal(draft.source, "photo_estimate");
    assert.equal((draft.mean as Record<string, unknown>).kcal, 512);
    const candidate = body.candidate as Record<string, unknown>;
    assert.equal(candidate.primaryLabel, "Oatmeal");
    assert.equal(candidate.userConfirmationRequired, true);
  });

  assertRecord(captured);
  assert.equal(captured.store, false);
  assertRecord(captured.text);
  assertRecord(captured.text.format);
  assert.equal(captured.text.format.type, "json_schema");
  assert.equal(captured.text.format.name, "grain_food_photo_observation_v1");
  assert.equal(captured.text.format.strict, true);
  const capturedJson = JSON.stringify(captured);
  assert.equal(capturedJson.includes("nutrition_label"), true);
  assert.equal(capturedJson.includes("whole bottle"), true);
  assert.equal(capturedJson.includes("\"draft_v\""), false);
  pass("OpenAI call uses store=false structured observation, resolver produces draft");
}

async function testVisibleNutritionLabelOverridesDatabasePortionScaling(): Promise<void> {
  const analyzer: FoodAnalyzer = {
    async analyze() {
      return {
        mode: "openai",
        modelId: "gpt-test-vision",
        observation: {
          items: [{ label: "kombucha bottle nutrition label", confidence: 0.93 }],
          total_kcal: 80,
          kcal_variance: 0,
          nutrition_label: {
            is_visible: true,
            calories_per_container: 80,
            calories_per_serving: null,
            servings_per_container: null,
            serving_size_text: null,
            container_size_text: "one bottle",
            source_text: "80 calories per bottle"
          },
          serving_g: null,
          amount_g: 473,
          servings: 1,
          confidence: 0.93,
          rationale: "visible bottle label states 80 calories for the whole bottle"
        }
      };
    }
  };
  const nutritionProvider: NutritionProvider = {
    async lookup(query) {
      if (!query.toLowerCase().includes("kombucha")) return null;
      return {
        provider: "usda_fdc",
        providerID: "fixture-kombucha-generic",
        matchedName: "Kombucha, generic",
        servingBasis: "per_100g",
        per100g: {
          kcal: 63,
          proteinGrams: 0,
          carbohydrateGrams: 15,
          fatGrams: 0,
          fiberGrams: 0
        }
      };
    }
  };

  await withServer(analyzer, async (baseUrl) => {
    const response = await postJson(`${baseUrl}/v1/food/analyze-photo`, sampleRequest);
    assert.equal(response.status, 200);
    const body = await response.json() as Record<string, unknown>;
    const draft = body.draft as Record<string, unknown>;
    assert.equal((draft.mean as Record<string, unknown>).kcal, 80);
    assert.equal((draft.var as Record<string, unknown>).kcal, 0);

    const candidate = body.candidate as Record<string, unknown>;
    assert.equal(candidate.dishType, "packaged");
    assert.equal(candidate.confidence, "high");
    const nutrition = candidate.nutrition as Record<string, unknown>;
    assert.equal(nutrition.minKcal, 80);
    assert.equal(nutrition.modeKcal, 80);
    assert.equal(nutrition.maxKcal, 80);
    const evidence = candidate.evidence as Array<Record<string, unknown>>;
    assert.equal(evidence.some((entry) => entry.provider === "visible_nutrition_label"), true);
    assert.equal(evidence.some((entry) => entry.provider === "usda_fdc"), false);
  }, nutritionProvider);
  pass("visible nutrition label calories override generic database portion scaling");
}

async function testUpstreamSchemaValidation(): Promise<void> {
  const analyzer: FoodAnalyzer = {
    async analyze() {
      return {
        mode: "openai",
        modelId: "bad-fixture",
        observation: {
          ...fakeObservation(),
          total_kcal: -1
        } as FoodObservation
      };
    }
  };
  await withServer(analyzer, async (baseUrl) => {
    const response = await postJson(`${baseUrl}/v1/food/analyze-photo`, sampleRequest);
    assert.equal(response.status, 502);
    const body = await response.json() as Record<string, unknown>;
    assert.equal(body.ok, false);
    assert.equal((body.error as Record<string, unknown>).code, "UPSTREAM_ERROR");
  });
  pass("server rejects invalid analyzer observations before resolving drafts");
}

async function withServer(
  analyzer: FoodAnalyzer | undefined,
  run: (baseUrl: string) => Promise<void>,
  nutritionProvider: NutritionProvider = new FixtureNutritionProvider(),
  searchProvider: FoodSearchProvider = new FixtureFoodSearchProvider()
): Promise<void> {
  const server = createBrokerServer({
    analyzer,
    candidateResolver: new FoodAnalysisCandidateResolver({ nutritionProvider }),
    searchProvider
  });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  const address = server.address();
  assert(address && typeof address === "object");
  try {
    await run(`http://127.0.0.1:${address.port}`);
  } finally {
    server.close();
    await once(server, "close");
  }
}

async function postJson(url: string, body: unknown): Promise<Response> {
  return fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body)
  });
}

function fakeObservation(): FoodObservation {
  return {
    items: [{ label: "oatmeal", confidence: 0.8 }],
    total_kcal: 512,
    kcal_variance: 49,
    nutrition_label: null,
    serving_g: 250,
    amount_g: 250,
    servings: 1,
    confidence: 0.8,
    rationale: "fixture observation"
  };
}

function assertRecord(value: unknown): asserts value is Record<string, unknown> {
  assert.equal(typeof value, "object");
  assert.notEqual(value, null);
  assert.equal(Array.isArray(value), false);
}

function pass(name: string): void {
  checks.push({ name, pass: true });
}

main().then((code) => process.exit(code)).catch((err: unknown) => {
  checks.push({ name: "unexpected exception", pass: false, detail: err instanceof Error ? err.message : String(err) });
  process.stdout.write(`${JSON.stringify({ total: checks.length, failed: 1, checks }, null, 2)}\n`);
  process.exit(1);
});
