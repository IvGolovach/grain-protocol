import { createHash } from "node:crypto";

import { SdkError } from "grain-sdk-ts/errors";

type Json = null | boolean | number | string | Json[] | { [key: string]: Json };

export type FoodSourceClass = "attested" | "measured" | "estimated";
export type FoodDraftSource = "photo_estimate" | "serving_offer" | "self_issued";
export type FoodRecordTrust = "verified_source" | "self_issued" | "untrusted";
export type FoodNutritionConfidence = "confirmed" | "estimated" | "incomplete" | "unknown";

export type FoodNutrientKcal = {
  kcal: number;
};

export type FoodPhotoEstimate = {
  estimate_id: string;
  capture_id?: string;
  mean: FoodNutrientKcal;
  var: FoodNutrientKcal;
  serving_g?: number;
  amount_g?: number;
  servings?: number;
  confidence?: number;
  nutrition_confidence?: FoodNutritionConfidence;
  evidence?: {
    photo_sha256_16?: string;
    model_id?: string;
  };
};

export type FoodIntakeDraftOptions = {
  draft_id: string;
  payload_cid: string;
  ts_ms?: number;
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
  privacy: {
    raw_photo_persistence: "forbidden";
    allowed_persistent_photo_fields: readonly ["photo_sha256_16"];
  };
};

export type FoodIntakeEventInput = {
  t: "IntakeEvent";
  payload_cid: string;
  body: Record<string, Json> & {
    source_class: FoodSourceClass;
    mean: FoodNutrientKcal;
    var: FoodNutrientKcal;
  };
};

export type FoodPhotoEstimateRequest = {
  image_bytes: Uint8Array;
  media_type: "image/jpeg" | "image/png" | "image/webp" | "application/octet-stream";
  capture_id?: string;
};

export type FoodPhotoEstimatorProvider = {
  estimateFoodPhoto(input: FoodPhotoEstimateRequest): Promise<FoodPhotoEstimate>;
};

export type FoodAdviceContext = {
  drafts?: readonly FoodIntakeDraft[];
  confirmed_intakes?: readonly FoodIntakeEventInput[];
  policy: {
    ledger_writes_allowed: false;
    raw_photo_persistence_allowed: false;
  };
};

export type FoodInsightResult = {
  summary: string;
  draft_count: number;
  confirmed_count: number;
  ledger_write_intent: "never";
  raw_photo_persistence: "forbidden";
};

export type FoodInsightProvider = {
  foodInsight(context: FoodAdviceContext): Promise<FoodInsightResult>;
};

export type DeterministicFakeFoodProviderOptions = {
  mean: FoodNutrientKcal;
  var: FoodNutrientKcal;
  serving_g?: number;
  amount_g?: number;
  servings?: number;
  confidence?: number;
};

export async function estimateFoodPhotoDraft(
  provider: FoodPhotoEstimatorProvider,
  request: FoodPhotoEstimateRequest,
  options: FoodIntakeDraftOptions
): Promise<FoodIntakeDraft> {
  assertTransientPhotoRequest(request);
  const estimate = await provider.estimateFoodPhoto(request);
  assertNoRawPhotoPersistenceFields(estimate);
  return draftFoodIntakeFromPhotoEstimate(estimate, options);
}

export class DeterministicFakeFoodProvider implements FoodPhotoEstimatorProvider, FoodInsightProvider {
  public readonly observed_photo_sha256_16: string[] = [];
  private readonly estimate: DeterministicFakeFoodProviderOptions;

  constructor(estimate: DeterministicFakeFoodProviderOptions) {
    this.estimate = {
      ...estimate,
      mean: { ...estimate.mean },
      var: { ...estimate.var }
    };
  }

  async estimateFoodPhoto(input: FoodPhotoEstimateRequest): Promise<FoodPhotoEstimate> {
    assertTransientPhotoRequest(input);
    const digest = sha256Hex(input.image_bytes).slice(0, 16);
    this.observed_photo_sha256_16.push(digest);
    return {
      estimate_id: `deterministic-fake-photo:${digest}`,
      capture_id: input.capture_id,
      mean: { ...this.estimate.mean },
      var: { ...this.estimate.var },
      amount_g: this.estimate.amount_g,
      serving_g: this.estimate.serving_g,
      servings: this.estimate.servings,
      confidence: this.estimate.confidence,
      evidence: {
        photo_sha256_16: digest,
        model_id: "deterministic-fake-food-provider-v1"
      }
    };
  }

  async foodInsight(context: FoodAdviceContext): Promise<FoodInsightResult> {
    if (context.policy.ledger_writes_allowed !== false || context.policy.raw_photo_persistence_allowed !== false) {
      throw new Error("FoodInsightProvider requires read-only ledger and no raw photo persistence policy");
    }

    return {
      summary: "deterministic fake insight: food advice is read-only",
      draft_count: context.drafts?.length ?? 0,
      confirmed_count: context.confirmed_intakes?.length ?? 0,
      ledger_write_intent: "never",
      raw_photo_persistence: "forbidden"
    };
  }
}

function assertTransientPhotoRequest(input: FoodPhotoEstimateRequest): void {
  if (!(input.image_bytes instanceof Uint8Array)) {
    throw new Error("FoodPhotoEstimateRequest.image_bytes must be a Uint8Array");
  }
}

function sha256Hex(bytes: Uint8Array): string {
  return createHash("sha256").update(bytes).digest("hex");
}

function draftFoodIntakeFromPhotoEstimate(
  estimate: FoodPhotoEstimate,
  options: FoodIntakeDraftOptions
): FoodIntakeDraft {
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
      confidence: estimate.confidence,
      nutrition_confidence: estimate.nutrition_confidence,
      evidence: estimate.evidence
    })
  });
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

function assertNoRawPhotoPersistenceFields(value: unknown): void {
  const found = findRawPhotoPersistenceField(value, "$");
  if (found) {
    throw new SdkError(
      "SDK_ERR_FOOD_RAW_PHOTO_PERSISTENCE",
      `food wallet drafts must not persist raw photo material at ${found}`
    );
  }
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
