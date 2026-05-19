#!/usr/bin/env node

import { once } from "node:events";
import assert from "node:assert/strict";

import { OpenAiFoodAnalyzer } from "../src/analyzers.js";
import { FoodAnalysisCandidateResolver } from "../src/resolver.js";
import { createBrokerServer } from "../src/server.js";
import { FixtureNutritionProvider, type NutritionProvider } from "../src/usda.js";
import type { FoodAnalyzer, FoodAnalyzePhotoRequest, FoodObservation } from "../src/types.js";

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
  nutritionProvider: NutritionProvider = new FixtureNutritionProvider()
): Promise<void> {
  const server = createBrokerServer({
    analyzer,
    candidateResolver: new FoodAnalysisCandidateResolver({ nutritionProvider })
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
