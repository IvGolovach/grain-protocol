import { SdkError } from "grain-sdk-ts/errors";
import type { AICandidateEnvelopeV1 } from "./adapter.js";

export type NumericKind = "u63" | "i64";

export type StructuredPayloadV1 = {
  data: unknown;
  profile_id?: string;
  numeric_fields?: Record<string, NumericKind>;
  bytes_fields?: string[];
  set_array_fields?: string[];
};

export function parseCandidateEnvelopeV1(input: unknown): AICandidateEnvelopeV1 {
  if (!isObject(input)) {
    throw new SdkError("SDK_ERR_AI_ENVELOPE_INVALID", "candidate envelope must be an object");
  }

  if (input.candidate_version !== 1) {
    throw new SdkError("SDK_ERR_AI_ENVELOPE_VERSION", "candidate_version must be 1");
  }
  if (input.target_schema_major !== 1) {
    throw new SdkError("SDK_ERR_AI_SCHEMA_MAJOR", "target_schema_major must be 1");
  }
  if (input.kind !== "object" && input.kind !== "event") {
    throw new SdkError("SDK_ERR_AI_KIND_INVALID", "kind must be object|event");
  }
  if (typeof input.target_type !== "string" || input.target_type.length === 0) {
    throw new SdkError("SDK_ERR_AI_TARGET_TYPE", "target_type must be a non-empty string");
  }
  if (input.payload_format !== "structured_v1" && input.payload_format !== "dagcbor_b64") {
    throw new SdkError("SDK_ERR_AI_PAYLOAD_FORMAT", "payload_format must be structured_v1|dagcbor_b64");
  }

  const critical = parseCriticalExtensions(input.critical_extensions);
  if (input.payload_format === "structured_v1") {
    parseStructuredPayloadV1(input.payload);
  } else {
    if (typeof input.payload !== "string" || !isBase64Standard(input.payload)) {
      throw new SdkError("SDK_ERR_AI_DAGCBOR_B64", "dagcbor_b64 payload must be base64 string");
    }
  }

  return {
    candidate_version: 1,
    kind: input.kind,
    target_schema_major: 1,
    target_type: input.target_type,
    payload_format: input.payload_format,
    payload: input.payload,
    critical_extensions: critical
  };
}

export function parseStructuredPayloadV1(input: unknown): StructuredPayloadV1 {
  if (!isObject(input)) {
    throw new SdkError("SDK_ERR_AI_STRUCTURED_INVALID", "structured_v1 payload must be an object");
  }

  if (!("data" in input)) {
    throw new SdkError("SDK_ERR_AI_STRUCTURED_INVALID", "structured_v1 payload missing data");
  }

  const numericFields = parseNumericFields(input.numeric_fields);
  const bytesFields = parsePathArray(input.bytes_fields, "bytes_fields");
  const setArrayFields = parsePathArray(input.set_array_fields, "set_array_fields");
  const profileId = parseProfileId(input.profile_id);

  return {
    data: input.data,
    profile_id: profileId,
    numeric_fields: numericFields,
    bytes_fields: bytesFields,
    set_array_fields: setArrayFields
  };
}

function parseCriticalExtensions(input: unknown): string[] | undefined {
  if (input === undefined) {
    return undefined;
  }
  if (!Array.isArray(input)) {
    throw new SdkError("SDK_ERR_AI_CRITICAL_EXTENSIONS", "critical_extensions must be an array of strings");
  }
  const values = input.map((v) => {
    if (typeof v !== "string" || v.length === 0) {
      throw new SdkError("SDK_ERR_AI_CRITICAL_EXTENSIONS", "critical_extensions must contain non-empty strings");
    }
    return v;
  });
  values.sort();
  return values;
}

function parseNumericFields(input: unknown): Record<string, NumericKind> | undefined {
  if (input === undefined) {
    return undefined;
  }
  if (!isObject(input)) {
    throw new SdkError("SDK_ERR_AI_NUMERIC_FIELDS", "numeric_fields must be a map of json-pointer -> kind");
  }
  const out: Record<string, NumericKind> = {};
  for (const [path, kind] of Object.entries(input)) {
    if (!isJsonPointer(path)) {
      throw new SdkError("SDK_ERR_AI_POINTER_INVALID", `numeric_fields path is invalid: ${path}`);
    }
    if (kind !== "u63" && kind !== "i64") {
      throw new SdkError("SDK_ERR_AI_NUMERIC_FIELDS", `numeric_fields kind must be u63|i64 for ${path}`);
    }
    out[path] = kind;
  }
  return Object.keys(out).length === 0 ? undefined : out;
}

function parsePathArray(input: unknown, field: string): string[] | undefined {
  if (input === undefined) {
    return undefined;
  }
  if (!Array.isArray(input)) {
    throw new SdkError("SDK_ERR_AI_POINTER_INVALID", `${field} must be an array of json-pointers`);
  }
  const out = input.map((raw) => {
    if (typeof raw !== "string" || !isJsonPointer(raw)) {
      throw new SdkError("SDK_ERR_AI_POINTER_INVALID", `${field} has invalid pointer entry`);
    }
    return raw;
  });
  out.sort();
  return out.length === 0 ? undefined : out;
}

function parseProfileId(input: unknown): string | undefined {
  if (input === undefined) return undefined;
  if (typeof input !== "string" || input.length === 0) {
    throw new SdkError("SDK_ERR_AI_PROFILE_ID", "profile_id must be a non-empty string");
  }
  return input;
}

function isObject(input: unknown): input is Record<string, unknown> {
  return typeof input === "object" && input !== null && !Array.isArray(input);
}

function isJsonPointer(path: string): boolean {
  return path.startsWith("/") || path === "";
}

function isBase64Standard(value: string): boolean {
  if (value.length === 0 || value.length % 4 !== 0) {
    return false;
  }
  return /^[A-Za-z0-9+/]*={0,2}$/.test(value);
}
