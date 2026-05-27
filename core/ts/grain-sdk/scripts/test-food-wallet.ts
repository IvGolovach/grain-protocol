#!/usr/bin/env node

import { GrainSdk } from "../src/index.js";
import { SdkError } from "../src/errors.js";
import {
  confirmFoodIntakeDraft,
  draftFoodIntakeFromPhotoEstimate,
  draftFoodIntakeFromServingOffer,
  draftSelfIssuedFoodIntake
} from "../src/food-wallet.js";

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
  const photoDraft = draftFoodIntakeFromPhotoEstimate({
    estimate_id: "photo-estimate-001",
    capture_id: "breakfast-photo-001",
    mean: { kcal: 430 },
    var: { kcal: 36 },
    serving_g: 210,
    nutrition_confidence: "estimated",
    evidence: {
      photo_sha256_16: "0011223344556677"
    }
  }, {
    draft_id: "draft-photo-001",
    payload_cid: "meal-photo:breakfast-photo-001",
    ts_ms: 1717200000000
  });

  if (
    photoDraft.source !== "photo_estimate"
    || photoDraft.source_class !== "estimated"
    || photoDraft.record_trust !== "untrusted"
    || photoDraft.nutrition_confidence !== "estimated"
    || photoDraft.mean.kcal !== 430
    || photoDraft.var.kcal !== 36
    || photoDraft.serving_g !== 210
  ) {
    fail("SDK-FOOD-001 photo estimate drafts intake", "photo estimate did not map into expected draft fields");
  } else if (hasForbiddenRawPhotoField(photoDraft)) {
    fail("SDK-FOOD-001 photo estimate drafts intake", "draft persisted raw photo material");
  } else {
    ok("SDK-FOOD-001 photo estimate drafts intake");
  }

  const offerDraft = draftFoodIntakeFromServingOffer({
    offer_id: "verified-offer-001",
    issuer_kid: "issuer-kid-001",
    serving_g: 250,
    mean: { kcal: 620 },
    var: { kcal: 9 }
  }, {
    draft_id: "draft-offer-001",
    payload_cid: "serving-offer:verified-offer-001"
  });

  if (
    offerDraft.source !== "serving_offer"
    || offerDraft.source_class !== "attested"
    || offerDraft.record_trust !== "verified_source"
    || offerDraft.nutrition_confidence !== "confirmed"
    || offerDraft.serving_g !== 250
  ) {
    fail("SDK-FOOD-002 verified ServingOffer drafts intake", "verified serving offer did not map into an attested draft");
  } else {
    ok("SDK-FOOD-002 verified ServingOffer drafts intake");
  }

  const selfDraft = draftSelfIssuedFoodIntake({
    draft_id: "draft-self-001",
    payload_cid: "self-issued:meal-001",
    source_class: "measured",
    mean: { kcal: 700 },
    var: { kcal: 0 },
    amount_g: 300,
    serving_g: 300,
    servings: 1,
    ts_ms: 1717200060000
  });

  const confirmed = confirmFoodIntakeDraft(selfDraft, {
    confirmed_at_ms: 1717200065000
  });
  if (
    confirmed.t !== "IntakeEvent"
    || confirmed.payload_cid !== "self-issued:meal-001"
    || confirmed.body.source_class !== "measured"
    || confirmed.body.ext?.food_wallet?.record_trust !== "self_issued"
    || confirmed.body.ext?.food_wallet?.nutrition_confidence !== "confirmed"
    || confirmed.body.mean.kcal !== 700
    || confirmed.body.var.kcal !== 0
    || confirmed.body.amount_g !== 300
    || confirmed.body.ext?.food_wallet?.draft_id !== "draft-self-001"
  ) {
    fail("SDK-FOOD-003 confirmed draft is appendable IntakeEvent", "confirmed draft did not produce expected IntakeEvent-shaped object");
  } else {
    ok("SDK-FOOD-003 confirmed draft is appendable IntakeEvent");
  }

  const sdk = new GrainSdk();
  await sdk.identity.createRoot();
  await sdk.events.append(confirmed);
  const reduced = await sdk.events.reduce();
  if (!reduced.pass || String(kcalFromReducerField(reduced.out.sum_mean)) !== "700" || String(kcalFromReducerField(reduced.out.sum_var)) !== "0") {
    fail("SDK-FOOD-003 confirmed draft is appendable IntakeEvent", `unexpected reducer output: ${JSON.stringify(reduced)}`);
  } else {
    ok("SDK-FOOD-003 confirmed draft reduces through SDK ledger path");
  }

  try {
    draftFoodIntakeFromPhotoEstimate({
      estimate_id: "bad-photo-estimate-001",
      mean: { kcal: 1 },
      var: { kcal: 0 },
      raw_photo_b64: "not-for-ledger"
    } as never, {
      draft_id: "draft-bad-photo",
      payload_cid: "bad-photo"
    });
    fail("SDK-FOOD-004 rejects raw photo persistence fields", "raw photo field was accepted into draft flow");
  } catch (err) {
    const code = err instanceof SdkError ? err.code : "SDK_ERR_INTERNAL";
    if (code === "SDK_ERR_FOOD_RAW_PHOTO_PERSISTENCE") {
      ok("SDK-FOOD-004 rejects raw photo persistence fields");
    } else {
      fail("SDK-FOOD-004 rejects raw photo persistence fields", `unexpected code: ${code}`);
    }
  }

  return summarize();
}

run().then((code) => process.exit(code));
