import { SdkError } from "./errors.js";
import type { AppendEventInput } from "./types.js";
import type { Json } from "./utils.js";

export type FoodSourceClass = "attested" | "measured" | "estimated";
export type FoodDraftSource = "photo_estimate" | "serving_offer" | "self_issued";
export type FoodRecordTrust = "verified_source" | "self_issued" | "untrusted";
export type FoodNutritionConfidence = "confirmed" | "estimated" | "incomplete" | "unknown";

export type FoodNutrientKcal = {
  kcal: number;
};

export type FoodRawPhotoPersistencePolicy = {
  raw_photo_persistence: "forbidden";
  allowed_persistent_photo_fields: readonly ["photo_sha256_16"];
};

export type FoodPhotoEstimate = {
  estimate_id: string;
  capture_id?: string;
  mean: FoodNutrientKcal;
  var: FoodNutrientKcal;
  serving_g?: number;
  amount_g?: number;
  servings?: number;
  nutrition_confidence?: FoodNutritionConfidence;
  evidence?: {
    photo_sha256_16?: string;
    model_id?: string;
  };
};

export type VerifiedServingOfferSummary = {
  offer_id: string;
  issuer_kid: string;
  serving_g: number;
  mean: FoodNutrientKcal;
  var: FoodNutrientKcal;
};

export type FoodIntakeDraftOptions = {
  draft_id: string;
  payload_cid: string;
  ts_ms?: number;
};

export type SelfIssuedFoodIntakeDraftInput = FoodIntakeDraftOptions & {
  source_class: FoodSourceClass;
  mean: FoodNutrientKcal;
  var: FoodNutrientKcal;
  amount_g?: number;
  serving_g?: number;
  servings?: number;
};

export type FoodIntakeDraft = {
  draft_v: 1;
  draft_id: string;
  payload_cid: string;
  source: FoodDraftSource;
  source_class: FoodSourceClass;
  record_trust: FoodRecordTrust;
  nutrition_confidence: FoodNutritionConfidence;
  mean: FoodNutrientKcal;
  var: FoodNutrientKcal;
  amount_g?: number;
  serving_g?: number;
  servings?: number;
  ts_ms?: number;
  source_ref?: Record<string, Json>;
  privacy: FoodRawPhotoPersistencePolicy;
};

export type FoodIntakeConfirmation = {
  confirmed_at_ms?: number;
};

export type FoodIntakeEventBody = Record<string, Json> & {
  source_class: FoodSourceClass;
  mean: FoodNutrientKcal;
  var: FoodNutrientKcal;
  amount_g?: number;
  serving_g?: number;
  servings?: number;
  ts_ms?: number;
  ext: {
    food_wallet: {
      draft_id: string;
      source: FoodDraftSource;
      record_trust: FoodRecordTrust;
      nutrition_confidence: FoodNutritionConfidence;
      confirmed_at_ms?: number;
    };
  };
};

export type FoodIntakeEventInput = AppendEventInput & {
  t: "IntakeEvent";
  body: FoodIntakeEventBody;
};

const RAW_PHOTO_PERSISTENCE_FIELDS = new Set([
  "image_bytes",
  "photo_bytes",
  "raw_photo",
  "raw_photo_b64",
  "raw_photo_bytes",
  "photo_b64",
  "image_b64",
  "persisted_photo",
  "photo_payload",
  "photo_data"
]);

export function draftFoodIntakeFromPhotoEstimate(
  estimate: FoodPhotoEstimate,
  options: FoodIntakeDraftOptions
): FoodIntakeDraft {
  assertNoRawPhotoPersistenceFields(estimate);
  return buildDraft({
    ...options,
    source: "photo_estimate",
    source_class: "estimated",
    record_trust: "untrusted",
    nutrition_confidence: estimate.nutrition_confidence ?? "estimated",
    mean: estimate.mean,
    var: estimate.var,
    amount_g: estimate.amount_g,
    serving_g: estimate.serving_g,
    servings: estimate.servings,
    source_ref: compactJsonRecord({
      estimate_id: estimate.estimate_id,
      capture_id: estimate.capture_id,
      nutrition_confidence: estimate.nutrition_confidence,
      evidence: estimate.evidence
    })
  });
}

export function draftFoodIntakeFromServingOffer(
  offer: VerifiedServingOfferSummary,
  options: FoodIntakeDraftOptions
): FoodIntakeDraft {
  assertNoRawPhotoPersistenceFields(offer);
  return buildDraft({
    ...options,
    source: "serving_offer",
    source_class: "attested",
    record_trust: "verified_source",
    nutrition_confidence: "confirmed",
    mean: offer.mean,
    var: offer.var,
    serving_g: offer.serving_g,
    source_ref: {
      offer_id: offer.offer_id,
      issuer_kid: offer.issuer_kid
    }
  });
}

export function draftSelfIssuedFoodIntake(input: SelfIssuedFoodIntakeDraftInput): FoodIntakeDraft {
  assertNoRawPhotoPersistenceFields(input);
  return buildDraft({
    ...input,
    source: "self_issued",
    record_trust: "self_issued",
    nutrition_confidence: "confirmed"
  });
}

export function confirmFoodIntakeDraft(
  draft: FoodIntakeDraft,
  confirmation: FoodIntakeConfirmation = {}
): FoodIntakeEventInput {
  assertNoRawPhotoPersistenceFields(draft);

  const body: FoodIntakeEventBody = {
    source_class: draft.source_class,
    mean: copyNutrients(draft.mean),
    var: copyNutrients(draft.var),
    ext: {
      food_wallet: compactJsonRecord({
        draft_id: draft.draft_id,
        source: draft.source,
        record_trust: draft.record_trust,
        nutrition_confidence: draft.nutrition_confidence,
        confirmed_at_ms: confirmation.confirmed_at_ms
      }) as FoodIntakeEventBody["ext"]["food_wallet"]
    }
  };

  if (draft.amount_g !== undefined) body.amount_g = assertNonNegativeInt64("amount_g", draft.amount_g);
  if (draft.serving_g !== undefined) body.serving_g = assertNonNegativeInt64("serving_g", draft.serving_g);
  if (draft.servings !== undefined) body.servings = assertNonNegativeInt64("servings", draft.servings);
  if (draft.ts_ms !== undefined) body.ts_ms = assertInt64("ts_ms", draft.ts_ms);

  return {
    t: "IntakeEvent",
    payload_cid: draft.payload_cid,
    body
  };
}

export function assertNoRawPhotoPersistenceFields(value: unknown): void {
  const found = findRawPhotoPersistenceField(value, "$");
  if (found) {
    throw new SdkError(
      "SDK_ERR_FOOD_RAW_PHOTO_PERSISTENCE",
      `food wallet drafts must not persist raw photo material at ${found}`
    );
  }
}

function buildDraft(input: {
  draft_id: string;
  payload_cid: string;
  source: FoodDraftSource;
  source_class: FoodSourceClass;
  record_trust: FoodRecordTrust;
  nutrition_confidence: FoodNutritionConfidence;
  mean: FoodNutrientKcal;
  var: FoodNutrientKcal;
  amount_g?: number;
  serving_g?: number;
  servings?: number;
  ts_ms?: number;
  source_ref?: Record<string, Json>;
}): FoodIntakeDraft {
  const draft: FoodIntakeDraft = {
    draft_v: 1,
    draft_id: requireNonEmpty("draft_id", input.draft_id),
    payload_cid: requireNonEmpty("payload_cid", input.payload_cid),
    source: input.source,
    source_class: input.source_class,
    record_trust: input.record_trust,
    nutrition_confidence: input.nutrition_confidence,
    mean: copyNutrients(input.mean),
    var: copyNutrients(input.var),
    privacy: {
      raw_photo_persistence: "forbidden",
      allowed_persistent_photo_fields: ["photo_sha256_16"]
    }
  };

  if (input.amount_g !== undefined) draft.amount_g = assertNonNegativeInt64("amount_g", input.amount_g);
  if (input.serving_g !== undefined) draft.serving_g = assertNonNegativeInt64("serving_g", input.serving_g);
  if (input.servings !== undefined) draft.servings = assertNonNegativeInt64("servings", input.servings);
  if (input.ts_ms !== undefined) draft.ts_ms = assertInt64("ts_ms", input.ts_ms);
  if (input.source_ref && Object.keys(input.source_ref).length > 0) draft.source_ref = input.source_ref;

  return draft;
}

function copyNutrients(value: FoodNutrientKcal): FoodNutrientKcal {
  return {
    kcal: assertInt64("kcal", value.kcal)
  };
}

function assertInt64(field: string, value: number): number {
  if (!Number.isSafeInteger(value)) {
    throw new SdkError("SDK_ERR_FOOD_INTEGER_REQUIRED", `${field} must be a safe integer`);
  }
  if (value < Number.MIN_SAFE_INTEGER || value > Number.MAX_SAFE_INTEGER) {
    throw new SdkError("SDK_ERR_FOOD_INTEGER_RANGE", `${field} is outside the supported JSON integer range`);
  }
  return value;
}

function assertNonNegativeInt64(field: string, value: number): number {
  const parsed = assertInt64(field, value);
  if (parsed < 0) {
    throw new SdkError("SDK_ERR_FOOD_INTEGER_RANGE", `${field} must be non-negative`);
  }
  return parsed;
}

function requireNonEmpty(field: string, value: string): string {
  if (value.length === 0) {
    throw new SdkError("SDK_ERR_FOOD_DRAFT_INVALID", `${field} must be non-empty`);
  }
  return value;
}

function compactJsonRecord(value: Record<string, unknown>): Record<string, Json> {
  const out: Record<string, Json> = {};
  for (const [key, entry] of Object.entries(value)) {
    if (entry === undefined) continue;
    if (isJson(entry)) {
      out[key] = entry;
    }
  }
  return out;
}

function isJson(value: unknown): value is Json {
  if (value === null) return true;
  if (typeof value === "string" || typeof value === "number" || typeof value === "boolean") return true;
  if (Array.isArray(value)) return value.every(isJson);
  if (typeof value === "object" && value !== null) {
    return Object.values(value).every((entry) => entry === undefined || isJson(entry));
  }
  return false;
}

function findRawPhotoPersistenceField(value: unknown, path: string, seen = new WeakSet<object>()): string | null {
  if (typeof value !== "object" || value === null) return null;
  if (seen.has(value)) return null;
  seen.add(value);

  if (Array.isArray(value)) {
    for (let i = 0; i < value.length; i += 1) {
      const found = findRawPhotoPersistenceField(value[i], `${path}[${i}]`, seen);
      if (found) return found;
    }
    return null;
  }

  for (const [key, entry] of Object.entries(value as Record<string, unknown>)) {
    if (RAW_PHOTO_PERSISTENCE_FIELDS.has(key)) {
      return `${path}.${key}`;
    }
    const found = findRawPhotoPersistenceField(entry, `${path}.${key}`, seen);
    if (found) return found;
  }
  return null;
}
