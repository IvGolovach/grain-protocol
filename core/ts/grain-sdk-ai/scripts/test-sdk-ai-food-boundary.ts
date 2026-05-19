#!/usr/bin/env node

import { GrainSdk } from "grain-sdk-ts";
import { confirmFoodIntakeDraft } from "grain-sdk-ts";
import { SdkError } from "grain-sdk-ts/errors";
import {
  DeterministicFakeFoodProvider,
  estimateFoodPhotoDraft,
  type FoodPhotoEstimatorProvider
} from "../src/index.js";

const checks: Array<{ name: string; pass: boolean; detail?: string }> = [];

function ok(name: string): void {
  checks.push({ name, pass: true });
}

function fail(name: string, detail: string): void {
  checks.push({ name, pass: false, detail });
}

function summarize(): number {
  const out = {
    total: checks.length,
    failed: checks.filter((x) => !x.pass).length,
    checks
  };
  process.stdout.write(`${JSON.stringify(out, null, 2)}\n`);
  return out.failed === 0 ? 0 : 1;
}

function kcalFromReducerField(value: unknown): unknown {
  if (typeof value !== "object" || value === null || !("kcal" in value)) {
    return undefined;
  }
  return (value as { kcal?: unknown }).kcal;
}

function hasForbiddenRawPhotoField(value: unknown): boolean {
  const forbidden = new Set(["image_bytes", "photo_bytes", "raw_photo", "raw_photo_b64", "raw_photo_bytes", "photo_b64", "image_b64"]);
  if (typeof value !== "object" || value === null) return false;
  if (Array.isArray(value)) return value.some(hasForbiddenRawPhotoField);
  return Object.entries(value as Record<string, unknown>).some(([key, entry]) => forbidden.has(key) || hasForbiddenRawPhotoField(entry));
}

async function run(): Promise<number> {
  const provider = new DeterministicFakeFoodProvider({
    mean: { kcal: 515 },
    var: { kcal: 16 },
    serving_g: 240,
    confidence: 0.75
  });

  const draft = await estimateFoodPhotoDraft(provider, {
    image_bytes: new Uint8Array([1, 2, 3, 4, 5]),
    media_type: "image/jpeg",
    capture_id: "camera-breakfast-001"
  }, {
    draft_id: "draft-ai-photo-001",
    payload_cid: "ai-photo:camera-breakfast-001",
    ts_ms: 1717200000000
  });

  if (
    draft.source !== "photo_estimate"
    || draft.source_class !== "estimated"
    || draft.mean.kcal !== 515
    || draft.var.kcal !== 16
    || draft.serving_g !== 240
  ) {
    fail("SDK-AI-FOOD-001 deterministic fake photo estimate drafts intake", "fake provider did not produce expected draft");
  } else if (hasForbiddenRawPhotoField(draft)) {
    fail("SDK-AI-FOOD-001 deterministic fake photo estimate drafts intake", "draft persisted raw image material");
  } else {
    ok("SDK-AI-FOOD-001 deterministic fake photo estimate drafts intake");
  }

  const confirmed = confirmFoodIntakeDraft(draft, { confirmed_at_ms: 1717200005000 });
  const sdk = new GrainSdk();
  await sdk.identity.createRoot();
  await sdk.events.append(confirmed);
  const reduced = await sdk.events.reduce();
  if (!reduced.pass || String(kcalFromReducerField(reduced.out.sum_mean)) !== "515" || String(kcalFromReducerField(reduced.out.sum_var)) !== "16") {
    fail("SDK-AI-FOOD-002 confirmed AI draft is appendable only by SDK workflow", `unexpected reducer output: ${JSON.stringify(reduced)}`);
  } else {
    ok("SDK-AI-FOOD-002 confirmed AI draft is appendable only by SDK workflow");
  }

  const insight = await provider.foodInsight({
    drafts: [draft],
    confirmed_intakes: [confirmed],
    policy: {
      ledger_writes_allowed: false,
      raw_photo_persistence_allowed: false
    }
  });
  if (
    insight.ledger_write_intent !== "never"
    || insight.raw_photo_persistence !== "forbidden"
    || JSON.stringify(insight).includes("append")
  ) {
    fail("SDK-AI-FOOD-003 advice is ledger-read-only", "food insight advertised ledger writes or append semantics");
  } else {
    ok("SDK-AI-FOOD-003 advice is ledger-read-only");
  }

  if (provider.observed_photo_sha256_16.length !== 1 || "observed_photo_bytes" in (provider as unknown as Record<string, unknown>)) {
    fail("SDK-AI-FOOD-004 image bytes are transient", "fake provider exposed raw photo bytes");
  } else {
    ok("SDK-AI-FOOD-004 image bytes are transient");
  }

  const leakingProvider: FoodPhotoEstimatorProvider = {
    async estimateFoodPhoto() {
      return {
        estimate_id: "leaky-estimate",
        mean: { kcal: 1 },
        var: { kcal: 0 },
        raw_photo_b64: "do-not-persist"
      } as never;
    }
  };

  try {
    await estimateFoodPhotoDraft(leakingProvider, {
      image_bytes: new Uint8Array([9]),
      media_type: "image/png"
    }, {
      draft_id: "draft-leaky",
      payload_cid: "leaky"
    });
    fail("SDK-AI-FOOD-005 rejects raw photo persistence fields", "leaking provider output was accepted");
  } catch (err) {
    const code = err instanceof SdkError ? err.code : "SDK_ERR_INTERNAL";
    if (code === "SDK_ERR_FOOD_RAW_PHOTO_PERSISTENCE") {
      ok("SDK-AI-FOOD-005 rejects raw photo persistence fields");
    } else {
      fail("SDK-AI-FOOD-005 rejects raw photo persistence fields", `unexpected code: ${code}`);
    }
  }

  return summarize();
}

run().then((code) => process.exit(code));
