import type { CborNode, Json } from "../../../../../runner/typescript/dist/src/types.js";
import type { TsCoreEngine } from "../engine.js";
import { SdkError, toSdkError } from "../errors.js";
import { compareCanonicalMapKey, encodeCanonical } from "../runner-bridge.js";
import type { GrainSdkStore } from "../store.js";
import { compareBytesLex, decodeB64, encodeB64, sha256Hex, toUtf8 } from "../utils.js";
import type { AICandidateEnvelopeV1 } from "./adapter.js";
import { parseCandidateEnvelopeV1, parseStructuredPayloadV1, type NumericKind } from "./candidate_v1.js";
import { exportAiContract, type ContractExportV1 } from "./contract_export.js";
import { buildAiExplain, type AIExplainPayload } from "./diagnostics.js";
import { listProfiles, resolveDefaultProfileForTarget, resolveProfileById } from "./profiles.js";
import { AcceptedToken, AcceptedTokenRegistry, type AcceptedPayload } from "./token_registry.js";

type InternalValue = null | boolean | string | bigint | Uint8Array | InternalValue[] | { [k: string]: InternalValue };

export type AcceptOptions = {
  known_critical_extensions?: string[];
  include_sensitive?: boolean;
};

export type ApplyOptions = {
  include_sensitive?: boolean;
};

export type AcceptResult =
  | {
      status: "accepted";
      cid: string;
      canonical_bytes: Uint8Array;
      digest_hex: string;
      normalization_applied: string[];
      token: AcceptedToken;
    }
  | {
      status: "quarantined" | "rejected";
      error: AIExplainPayload;
    };

export type ApplyResult =
  | {
      status: "applied";
      cid: string;
      digest_hex: string;
    }
  | {
      status: "rejected";
      error: AIExplainPayload;
    };

export class AiBoundary {
  private readonly core: TsCoreEngine;
  private readonly store: GrainSdkStore;
  private readonly tokens: AcceptedTokenRegistry;

  constructor(core: TsCoreEngine, store: GrainSdkStore, cfg?: { token_ttl_ms?: number; max_pending_tokens?: number; now_ms?: () => number }) {
    this.core = core;
    this.store = store;
    this.tokens = new AcceptedTokenRegistry({
      ttl_ms: cfg?.token_ttl_ms,
      max_pending: cfg?.max_pending_tokens,
      now_ms: cfg?.now_ms
    });
  }

  async accept(candidateRaw: unknown, options: AcceptOptions = {}): Promise<AcceptResult> {
    const includeSensitive = options.include_sensitive === true;

    try {
      const candidate = parseCandidateEnvelopeV1(candidateRaw);
      const candidateDigest = sha256Hex(toUtf8(JSON.stringify(redactedCandidateForHash(candidate))));
      const unknownCritical = findUnknownCritical(candidate, options.known_critical_extensions ?? []);
      if (unknownCritical.length > 0) {
        return {
          status: "quarantined",
          error: buildAiExplain("SDK_ERR_AI_QUARANTINED_UNKNOWN_CRITICAL", {
            include_sensitive: includeSensitive,
            invariant_refs: ["SDK-AI-007"],
            normalization_applied: [`unknown_critical:${unknownCritical.join(",")}`],
            sensitive_details: {
              candidate_sha256_16: candidateDigest.slice(0, 16)
            }
          })
        };
      }

      const normalized = this.normalizeCandidate(candidate);
      this.strictValidate(normalized.canonical_bytes);
      const cid = this.deriveCid(normalized.canonical_bytes);
      const payload: AcceptedPayload = {
        kind: candidate.kind,
        target_type: candidate.target_type,
        cid,
        canonical_bytes: normalized.canonical_bytes,
        apply_plan: { mode: "object_put" }
      };
      const token = this.tokens.issue(payload);

      return {
        status: "accepted",
        cid,
        canonical_bytes: normalized.canonical_bytes,
        digest_hex: sha256Hex(normalized.canonical_bytes),
        normalization_applied: normalized.normalization_applied,
        token
      };
    } catch (err) {
      const sdkErr = toSdkError(err);
      return {
        status: "rejected",
        error: buildAiExplain(sdkErr.code, {
          include_sensitive: includeSensitive,
          invariant_refs: invariantRefsForCode(sdkErr.code),
          normalization_applied: [],
          sensitive_details: {
            candidate_sha256_16: sha256Hex(toUtf8(JSON.stringify(redactedUnknownForHash(candidateRaw)))).slice(0, 16)
          }
        })
      };
    }
  }

  async applyAccepted(token: unknown, options: ApplyOptions = {}): Promise<ApplyResult> {
    const includeSensitive = options.include_sensitive === true;
    try {
      const consumed = this.tokens.consume(token);
      await this.store.objects.put(consumed.payload.cid, consumed.payload.canonical_bytes);
      return {
        status: "applied",
        cid: consumed.payload.cid,
        digest_hex: consumed.digest_hex
      };
    } catch (err) {
      const sdkErr = toSdkError(err);
      return {
        status: "rejected",
        error: buildAiExplain(sdkErr.code, {
          include_sensitive: includeSensitive,
          invariant_refs: invariantRefsForCode(sdkErr.code),
          normalization_applied: [],
          sensitive_details: {
            token_id_prefix: tokenPrefix(token)
          }
        })
      };
    }
  }

  exportContract(): ContractExportV1 {
    const base = exportAiContract();
    return {
      ...base,
      profiles: listProfiles()
    };
  }

  private normalizeCandidate(candidate: AICandidateEnvelopeV1): { canonical_bytes: Uint8Array; normalization_applied: string[] } {
    if (candidate.payload_format === "dagcbor_b64") {
      const bytes = decodeB64(candidate.payload as string);
      return {
        canonical_bytes: new Uint8Array(bytes),
        normalization_applied: []
      };
    }

    const structured = parseStructuredPayloadV1(candidate.payload);
    const normalizationApplied: string[] = [];
    const data = rejectNumbersAndClone(structured.data, "");
    const resolvedProfile = resolveStructuredProfile(candidate.target_type, structured);

    applyNumericConversions(data, resolvedProfile.numeric_fields);
    applyByteConversions(data, resolvedProfile.bytes_fields);
    applySetArrayNormalization(data, resolvedProfile.set_array_fields, normalizationApplied);

    const node = toCborNode(data);
    const bytes = encodeCanonical(node);
    return {
      canonical_bytes: bytes,
      normalization_applied: normalizationApplied
    };
  }

  private strictValidate(bytes: Uint8Array): void {
    this.core.execute("dagcbor_validate", { bytes_b64: encodeB64(bytes) as Json }, true);
  }

  private deriveCid(bytes: Uint8Array): string {
    const out = this.core.execute("cid_derive", { bytes_b64: encodeB64(bytes) as Json }, true);
    const cid = out.out.cid;
    if (typeof cid !== "string" || cid.length === 0) {
      throw new SdkError("SDK_ERR_AI_CID_DERIVE", "cid_derive did not return string cid");
    }
    return cid;
  }
}

function findUnknownCritical(candidate: AICandidateEnvelopeV1, known: string[]): string[] {
  const knownSet = new Set(known);
  const unknown: string[] = [];
  for (const ext of candidate.critical_extensions ?? []) {
    if (!knownSet.has(ext)) {
      unknown.push(ext);
    }
  }
  unknown.sort();
  return unknown;
}

function rejectNumbersAndClone(value: unknown, path: string): InternalValue {
  if (value === null || typeof value === "boolean" || typeof value === "string") {
    return value;
  }
  if (typeof value === "number") {
    throw new SdkError("SDK_ERR_AI_NUMERIC_NOT_DECIMAL_STRING", `JSON numbers are forbidden in structured_v1 at ${path || "/"}`);
  }
  if (value instanceof Uint8Array) {
    return new Uint8Array(value);
  }
  if (Array.isArray(value)) {
    return value.map((item, idx) => rejectNumbersAndClone(item, `${path}/${idx}`));
  }
  if (typeof value === "object" && value !== null) {
    const out: Record<string, InternalValue> = {};
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
      out[k] = rejectNumbersAndClone(v, `${path}/${escapePointerSegment(k)}`);
    }
    return out;
  }
  throw new SdkError("SDK_ERR_AI_STRUCTURED_INVALID", `unsupported structured_v1 value at ${path || "/"}`);
}

function applyNumericConversions(root: InternalValue, fields: Record<string, NumericKind> | undefined): void {
  if (!fields) return;
  for (const [path, kind] of Object.entries(fields)) {
    const current = getByPointer(root, path);
    if (typeof current !== "string" || !/^-?(0|[1-9][0-9]*)$/.test(current)) {
      throw new SdkError("SDK_ERR_AI_NUMERIC_NOT_DECIMAL_STRING", `numeric field must be decimal string at ${path}`);
    }
    const parsed = BigInt(current);
    if (kind === "u63") {
      if (parsed < 0n || parsed > ((1n << 63n) - 1n)) {
        throw new SdkError("SDK_ERR_AI_NUMERIC_RANGE", `u63 out of range at ${path}`);
      }
    } else if (parsed < -(1n << 63n) || parsed > ((1n << 63n) - 1n)) {
      throw new SdkError("SDK_ERR_AI_NUMERIC_RANGE", `i64 out of range at ${path}`);
    }
    setByPointer(root, path, parsed);
  }
}

function applyByteConversions(root: InternalValue, paths: string[] | undefined): void {
  if (!paths) return;
  for (const path of paths) {
    const current = getByPointer(root, path);
    if (typeof current !== "string") {
      throw new SdkError("SDK_ERR_AI_BYTES_B64", `bytes field must be base64 string at ${path}`);
    }
    if (!isBase64Standard(current)) {
      throw new SdkError("SDK_ERR_AI_BYTES_B64", `bytes field is not base64 standard at ${path}`);
    }
    setByPointer(root, path, decodeB64(current));
  }
}

function applySetArrayNormalization(root: InternalValue, paths: string[] | undefined, normalizationApplied: string[]): void {
  if (!paths) return;
  for (const path of paths) {
    const current = getByPointer(root, path);
    if (!Array.isArray(current)) {
      throw new SdkError("SDK_ERR_AI_SET_ARRAY_INVALID", `set-array field is not an array at ${path}`);
    }
    if (!current.every((item) => typeof item === "string")) {
      throw new SdkError("SDK_ERR_AI_SET_ARRAY_INVALID", `set-array field must contain only strings at ${path}`);
    }

    const rows = current.map((item) => ({ value: item as string, bytes: toUtf8(item as string) }));
    rows.sort((a, b) => compareBytesLex(a.bytes, b.bytes));
    for (let i = 1; i < rows.length; i += 1) {
      if (compareBytesLex(rows[i - 1].bytes, rows[i].bytes) === 0) {
        throw new SdkError("GRAIN_ERR_SET_ARRAY_DUP", `duplicate set-array entry at ${path}`);
      }
    }
    const sorted = rows.map((row) => row.value);
    const before = JSON.stringify(current);
    const after = JSON.stringify(sorted);
    if (before !== after) {
      normalizationApplied.push(`set_array_sorted:${path}`);
    }
    setByPointer(root, path, sorted as unknown as InternalValue);
  }
}

function toCborNode(value: InternalValue): CborNode {
  if (value === null) {
    return { kind: "null" };
  }
  if (typeof value === "boolean") {
    return { kind: "bool", value };
  }
  if (typeof value === "string") {
    return { kind: "t", bytes: toUtf8(value) };
  }
  if (typeof value === "bigint") {
    if (value >= 0n) return { kind: "u", value };
    return { kind: "n", value };
  }
  if (value instanceof Uint8Array) {
    return { kind: "b", value: new Uint8Array(value) };
  }
  if (Array.isArray(value)) {
    return { kind: "a", items: value.map((item) => toCborNode(item)) };
  }
  const entries = Object.entries(value).map(([k, v]) => {
    const keyBytes = toUtf8(k);
    return {
      key: { kind: "t", bytes: keyBytes } as CborNode,
      keyBytes,
      value: toCborNode(v)
    };
  });
  entries.sort((a, b) => compareCanonicalMapKey(a.keyBytes, b.keyBytes));
  return { kind: "m", entries };
}

function getByPointer(root: InternalValue, pointer: string): InternalValue {
  if (pointer === "") return root;
  const parts = parsePointer(pointer);
  let cur: InternalValue = root;
  for (const part of parts) {
    if (Array.isArray(cur)) {
      const idx = Number(part);
      if (!Number.isInteger(idx) || idx < 0 || idx >= cur.length) {
        throw new SdkError("SDK_ERR_AI_POINTER_MISSING", `json pointer not found: ${pointer}`);
      }
      cur = cur[idx];
      continue;
    }
    if (cur === null || typeof cur !== "object" || cur instanceof Uint8Array) {
      throw new SdkError("SDK_ERR_AI_POINTER_MISSING", `json pointer not found: ${pointer}`);
    }
    if (!(part in cur)) {
      throw new SdkError("SDK_ERR_AI_POINTER_MISSING", `json pointer not found: ${pointer}`);
    }
    cur = (cur as Record<string, InternalValue>)[part];
  }
  return cur;
}

function setByPointer(root: InternalValue, pointer: string, value: InternalValue): void {
  if (pointer === "") {
    throw new SdkError("SDK_ERR_AI_POINTER_INVALID", "root pointer replacement is not allowed");
  }
  const parts = parsePointer(pointer);
  const leaf = parts[parts.length - 1];
  let cur: InternalValue = root;
  for (let i = 0; i < parts.length - 1; i += 1) {
    const part = parts[i];
    if (Array.isArray(cur)) {
      const idx = Number(part);
      if (!Number.isInteger(idx) || idx < 0 || idx >= cur.length) {
        throw new SdkError("SDK_ERR_AI_POINTER_MISSING", `json pointer not found: ${pointer}`);
      }
      cur = cur[idx];
      continue;
    }
    if (cur === null || typeof cur !== "object" || cur instanceof Uint8Array) {
      throw new SdkError("SDK_ERR_AI_POINTER_MISSING", `json pointer not found: ${pointer}`);
    }
    if (!(part in cur)) {
      throw new SdkError("SDK_ERR_AI_POINTER_MISSING", `json pointer not found: ${pointer}`);
    }
    cur = (cur as Record<string, InternalValue>)[part];
  }
  if (Array.isArray(cur)) {
    const idx = Number(leaf);
    if (!Number.isInteger(idx) || idx < 0 || idx >= cur.length) {
      throw new SdkError("SDK_ERR_AI_POINTER_MISSING", `json pointer not found: ${pointer}`);
    }
    cur[idx] = value;
    return;
  }
  if (cur === null || typeof cur !== "object" || cur instanceof Uint8Array) {
    throw new SdkError("SDK_ERR_AI_POINTER_MISSING", `json pointer not found: ${pointer}`);
  }
  if (!(leaf in cur)) {
    throw new SdkError("SDK_ERR_AI_POINTER_MISSING", `json pointer not found: ${pointer}`);
  }
  (cur as Record<string, InternalValue>)[leaf] = value;
}

function parsePointer(pointer: string): string[] {
  if (!pointer.startsWith("/")) {
    throw new SdkError("SDK_ERR_AI_POINTER_INVALID", `invalid json pointer: ${pointer}`);
  }
  return pointer
    .slice(1)
    .split("/")
    .map((seg) => seg.replace(/~1/g, "/").replace(/~0/g, "~"));
}

function escapePointerSegment(segment: string): string {
  return segment.replace(/~/g, "~0").replace(/\//g, "~1");
}

function invariantRefsForCode(code: string): string[] {
  if (code.startsWith("SDK_ERR_ACCEPT_TOKEN_")) {
    return ["SDK-AI-001", "SDK-AI-002"];
  }
  switch (code) {
    case "SDK_ERR_AI_NUMERIC_NOT_DECIMAL_STRING":
    case "SDK_ERR_AI_NUMERIC_RANGE":
    case "SDK_ERR_AI_PROFILE_MISSING":
    case "SDK_ERR_AI_PROFILE_UNKNOWN":
      return ["SDK-AI-005"];
    case "SDK_ERR_AI_SET_ARRAY_INVALID":
    case "GRAIN_ERR_SET_ARRAY_DUP":
      return ["SDK-AI-006"];
    case "SDK_ERR_AI_QUARANTINED_UNKNOWN_CRITICAL":
      return ["SDK-AI-007"];
    default:
      return ["SDK-AI-002"];
  }
}

function isBase64Standard(value: string): boolean {
  if (value.length === 0 || value.length % 4 !== 0) return false;
  return /^[A-Za-z0-9+/]*={0,2}$/.test(value);
}

function resolveStructuredProfile(
  targetType: string,
  structured: ReturnType<typeof parseStructuredPayloadV1>
): {
  numeric_fields?: Record<string, NumericKind>;
  bytes_fields?: string[];
  set_array_fields?: string[];
} {
  let numeric: Record<string, NumericKind> = {};
  let bytes: string[] = [];
  let sets: string[] = [];

  const fromProfile = structured.profile_id
    ? resolveProfileById(structured.profile_id)
    : resolveDefaultProfileForTarget(targetType);

  if (structured.profile_id && !fromProfile) {
    throw new SdkError("SDK_ERR_AI_PROFILE_UNKNOWN", `unknown structured profile_id: ${structured.profile_id}`);
  }

  if (fromProfile) {
    for (const pointer of fromProfile.numeric_fields) {
      numeric[pointer] = "u63";
    }
    bytes = [...fromProfile.bytes_fields];
    sets = [...fromProfile.set_array_fields];
  }

  if (structured.numeric_fields) {
    numeric = { ...numeric, ...structured.numeric_fields };
  }
  if (structured.bytes_fields) {
    bytes = mergeUniqueSorted(bytes, structured.bytes_fields);
  }
  if (structured.set_array_fields) {
    sets = mergeUniqueSorted(sets, structured.set_array_fields);
  }

  if (!fromProfile && !structured.numeric_fields && !structured.bytes_fields && !structured.set_array_fields) {
    throw new SdkError("SDK_ERR_AI_PROFILE_MISSING", "structured_v1 requires explicit field profile or field maps");
  }

  return {
    numeric_fields: Object.keys(numeric).length > 0 ? numeric : undefined,
    bytes_fields: bytes.length > 0 ? bytes : undefined,
    set_array_fields: sets.length > 0 ? sets : undefined
  };
}

function mergeUniqueSorted(a: string[], b: string[]): string[] {
  const set = new Set<string>([...a, ...b]);
  return [...set].sort();
}

function tokenPrefix(token: unknown): string | undefined {
  if (token && typeof token === "object" && "id" in token && typeof (token as { id: unknown }).id === "string") {
    return (token as { id: string }).id.slice(0, 24);
  }
  return undefined;
}

function redactedCandidateForHash(candidate: AICandidateEnvelopeV1): Record<string, unknown> {
  return {
    candidate_version: candidate.candidate_version,
    kind: candidate.kind,
    target_schema_major: candidate.target_schema_major,
    target_type: candidate.target_type,
    payload_format: candidate.payload_format,
    critical_extensions: candidate.critical_extensions ?? [],
    payload_shape: payloadShape(candidate.payload)
  };
}

function redactedUnknownForHash(input: unknown): Record<string, unknown> {
  return {
    input_type: typeof input,
    input_shape: payloadShape(input)
  };
}

function payloadShape(value: unknown): unknown {
  if (value === null) return null;
  if (Array.isArray(value)) return value.map((v) => payloadShape(v));
  if (value instanceof Uint8Array) return { type: "bytes", len: value.length };
  if (typeof value === "string") return { type: "string", len: value.length };
  if (typeof value === "number") return { type: "number" };
  if (typeof value === "boolean") return { type: "boolean" };
  if (typeof value === "bigint") return { type: "bigint" };
  if (typeof value === "object") {
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
      out[k] = payloadShape(v);
    }
    return out;
  }
  return { type: typeof value };
}
