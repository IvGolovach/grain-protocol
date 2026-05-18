import { createHash, randomUUID } from "node:crypto";

import { BrokerError } from "./errors.js";
import { MAX_IMAGE_BYTES } from "./schema.js";
import type { FoodAnalyzePhotoRequest, FoodObservation, SupportedImageMediaType } from "./types.js";

const MEDIA_TYPES = new Set<SupportedImageMediaType>(["image/jpeg", "image/png", "image/webp"]);

export function parseAnalyzePhotoRequest(value: unknown): {
  request: FoodAnalyzePhotoRequest;
  imageBytes: Uint8Array;
  photoSha25616: string;
  requestId: string;
} {
  if (!isRecord(value)) {
    throw new BrokerError(400, "BAD_REQUEST", "request body must be a JSON object");
  }

  const photo = value.photo;
  if (!isRecord(photo)) {
    throw new BrokerError(400, "BAD_REQUEST", "photo must be an object");
  }

  const mediaType = photo.media_type;
  if (typeof mediaType !== "string" || !MEDIA_TYPES.has(mediaType as SupportedImageMediaType)) {
    throw new BrokerError(400, "BAD_REQUEST", "photo.media_type must be image/jpeg, image/png, or image/webp");
  }

  if (typeof photo.bytes_b64 !== "string" || photo.bytes_b64.length === 0) {
    throw new BrokerError(400, "BAD_REQUEST", "photo.bytes_b64 must be a non-empty base64 string");
  }

  const estimatedBytes = Math.floor((photo.bytes_b64.length * 3) / 4);
  if (estimatedBytes > MAX_IMAGE_BYTES) {
    throw new BrokerError(413, "PAYLOAD_TOO_LARGE", "photo.bytes_b64 exceeds image byte cap", {
      max_image_bytes: MAX_IMAGE_BYTES
    });
  }

  const imageBytes = decodeBase64(photo.bytes_b64);
  if (imageBytes.byteLength > MAX_IMAGE_BYTES) {
    throw new BrokerError(413, "PAYLOAD_TOO_LARGE", "decoded photo exceeds image byte cap", {
      max_image_bytes: MAX_IMAGE_BYTES
    });
  }

  const request = value as FoodAnalyzePhotoRequest;
  validateOptionalString("request_id", request.request_id, 96);
  validateOptionalString("capture_id", request.capture_id, 128);
  if (request.draft) {
    validateOptionalString("draft.draft_id", request.draft.draft_id, 128);
    validateOptionalString("draft.payload_cid", request.draft.payload_cid, 256);
    if (request.draft.ts_ms !== undefined && !Number.isSafeInteger(request.draft.ts_ms)) {
      throw new BrokerError(400, "BAD_REQUEST", "draft.ts_ms must be a safe integer");
    }
  }

  const requestId = request.request_id || randomUUID();
  const photoSha25616 = createHash("sha256").update(imageBytes).digest("hex").slice(0, 16);
  return { request, imageBytes, photoSha25616, requestId };
}

export function assertObservation(value: unknown): FoodObservation {
  if (!isRecord(value)) {
    throw new BrokerError(502, "UPSTREAM_ERROR", "upstream observation was not an object");
  }

  const observation: FoodObservation = {
    items: parseItems(value.items),
    total_kcal: parseNonNegativeInteger(value.total_kcal, "total_kcal"),
    kcal_variance: parseNonNegativeInteger(value.kcal_variance, "kcal_variance"),
    serving_g: parseNullableNonNegativeInteger(value.serving_g, "serving_g"),
    amount_g: parseNullableNonNegativeInteger(value.amount_g, "amount_g"),
    servings: parseNullableNonNegativeInteger(value.servings, "servings"),
    confidence: parseConfidence(value.confidence, "confidence"),
    rationale: parseString(value.rationale, "rationale", 240)
  };

  return observation;
}

function parseItems(value: unknown): FoodObservation["items"] {
  if (!Array.isArray(value) || value.length > 8) {
    throw new BrokerError(502, "UPSTREAM_ERROR", "upstream observation items were invalid");
  }
  return value.map((entry, index) => {
    if (!isRecord(entry)) {
      throw new BrokerError(502, "UPSTREAM_ERROR", `upstream observation item ${index} was invalid`);
    }
    return {
      label: parseString(entry.label, `items[${index}].label`, 80),
      confidence: parseConfidence(entry.confidence, `items[${index}].confidence`)
    };
  });
}

function decodeBase64(value: string): Uint8Array {
  if (!/^[A-Za-z0-9+/]*={0,2}$/.test(value) || value.length % 4 !== 0) {
    throw new BrokerError(400, "BAD_REQUEST", "photo.bytes_b64 must be canonical base64");
  }
  try {
    const bytes = Buffer.from(value, "base64");
    if (bytes.length === 0) {
      throw new Error("empty decoded bytes");
    }
    return bytes;
  } catch {
    throw new BrokerError(400, "BAD_REQUEST", "photo.bytes_b64 could not be decoded");
  }
}

function validateOptionalString(field: string, value: unknown, maxLength: number): void {
  if (value === undefined) return;
  if (typeof value !== "string" || value.length === 0 || value.length > maxLength) {
    throw new BrokerError(400, "BAD_REQUEST", `${field} must be a non-empty string no longer than ${maxLength}`);
  }
}

function parseString(value: unknown, field: string, maxLength: number): string {
  if (typeof value !== "string" || value.length === 0 || value.length > maxLength) {
    throw new BrokerError(502, "UPSTREAM_ERROR", `${field} was not a valid string`);
  }
  return value;
}

function parseConfidence(value: unknown, field: string): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0 || value > 1) {
    throw new BrokerError(502, "UPSTREAM_ERROR", `${field} was not a valid confidence score`);
  }
  return value;
}

function parseNullableNonNegativeInteger(value: unknown, field: string): number | null {
  if (value === null) return null;
  return parseNonNegativeInteger(value, field);
}

function parseNonNegativeInteger(value: unknown, field: string): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) {
    throw new BrokerError(502, "UPSTREAM_ERROR", `${field} was not a non-negative safe integer`);
  }
  return value;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
