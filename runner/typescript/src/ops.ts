import { createDecipheriv, createHash, hkdfSync } from "node:crypto";
import { inflateSync } from "node:zlib";

import {
  GrainDiagError,
  LIMITS,
  type ParseOptions
} from "./types.ts";
import type { CborNode, Json, OperationActual } from "./types.ts";
import {
  GENERIC_CBOR_LENIENT_OPTIONS,
  STRICT_DAG_CBOR_OPTIONS,
  mapGet,
  nodeAsBytes,
  nodeAsText,
  nodeAsU,
  parseExact,
  parseOne,
  validateSetArrayUtf8
} from "./cbor.ts";
import { base45Decode } from "./base45.ts";
import {
  bytesEq,
  compareBytesLex,
  decodeB64,
  encodeB64,
  normalizeDiag,
  sha256,
  sha256Hex
} from "./utils.ts";

const KEY_INFO = Buffer.from("GrainE2E\0v0.1\0A256GCM\0key", "ascii");
const NONCE_INFO_PREFIX = Buffer.from("GrainE2E\0v0.1\0A256GCM\0nonce\0", "ascii");

export function executeOperation(op: string, input: Record<string, Json>, strict: boolean): OperationActual {
  if (!strict) {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }

  switch (op) {
    case "dagcbor_validate":
      return opDagCborValidate(input);
    case "parse_cborseq_stream_v1":
      return opParseCborSeq(input);
    case "e2e_derive_v1":
      return opE2eDerive(input);
    case "e2e_decrypt":
      return opE2eDecrypt(input);
    case "manifest_resolve":
      return opManifestResolve(input);
    case "qr_decode_gr1":
      return opQrDecodeGr1(input);
    default:
      throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }
}

function opDagCborValidate(input: Record<string, Json>): OperationActual {
  const bytes = decodeB64(input.bytes_b64);
  if (bytes.length > LIMITS.CBL_MAX_DAGCBOR_OBJECT_BYTES) {
    throw new GrainDiagError("GRAIN_ERR_LIMIT");
  }

  const node = parseExact(bytes, STRICT_DAG_CBOR_OPTIONS);
  schemaChecks(node);

  return { accepted: true, diag: [], out: {} };
}

function schemaChecks(node: CborNode): void {
  if (node.kind !== "m") {
    return;
  }

  const t = nodeAsText(mapGet(node, "t"));
  if (!t) return;

  const allowed = allowedTopLevelKeys(t);
  if (allowed) {
    const allowedSet = new Set(allowed);
    for (const entry of node.entries) {
      if (entry.key.kind !== "t") {
        throw new GrainDiagError("GRAIN_ERR_NONCANONICAL");
      }
      const key = new TextDecoder().decode(entry.key.bytes);
      if (!allowedSet.has(key)) {
        throw new GrainDiagError("GRAIN_ERR_UNKNOWN_TOPLEVEL_KEY");
      }
    }
  }

  const crit = mapGet(node, "crit");
  if (crit) {
    if (crit.kind !== "a") throw new GrainDiagError("GRAIN_ERR_SCHEMA");
    if (crit.items.length > 64) throw new GrainDiagError("GRAIN_ERR_LIMIT");
    let total = 0;
    for (const it of crit.items) {
      if (it.kind !== "t") throw new GrainDiagError("GRAIN_ERR_SCHEMA");
      total += it.bytes.length;
    }
    if (total > 4096) throw new GrainDiagError("GRAIN_ERR_LIMIT");

    const check = validateSetArrayUtf8(crit);
    if (!check.orderOk) throw new GrainDiagError("GRAIN_ERR_SET_ARRAY_ORDER");
    if (!check.uniqueOk) throw new GrainDiagError("GRAIN_ERR_SET_ARRAY_DUP");
  }

  if (t === "DeviceKeyGrant") {
    const caps = mapGet(node, "caps");
    if (caps) {
      const check = validateSetArrayUtf8(caps);
      if (!check.orderOk) throw new GrainDiagError("GRAIN_ERR_SET_ARRAY_ORDER");
      if (!check.uniqueOk) throw new GrainDiagError("GRAIN_ERR_SET_ARRAY_DUP");
    }
  }
}

function opParseCborSeq(input: Record<string, Json>): OperationActual {
  const streamKind = input.stream_kind;
  if (streamKind !== "ledger" && streamKind !== "manifest") {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }

  let stream: Uint8Array;
  if ("cborseq_b64" in input && !("segments_b64" in input)) {
    stream = decodeB64(input.cborseq_b64);
  } else if (!("cborseq_b64" in input) && "segments_b64" in input) {
    if (!Array.isArray(input.segments_b64) || input.segments_b64.length === 0) {
      throw new GrainDiagError("GRAIN_ERR_SCHEMA");
    }
    const all: number[] = [];
    for (const seg of input.segments_b64) {
      const b = decodeB64(seg);
      for (const x of b) all.push(x);
    }
    stream = new Uint8Array(all);
  } else {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }

  if (stream.length > LIMITS.CBL_MAX_CBORSEQ_SEGMENT_BYTES) {
    throw new GrainDiagError("GRAIN_ERR_LIMIT");
  }

  const digests: string[] = [];

  if (stream.length === 0) {
    return { accepted: true, diag: [], out: { item_sha256_hex: digests } };
  }

  let pos = 0;
  while (pos < stream.length) {
    try {
      const parsed = parseOne(stream.slice(pos), GENERIC_CBOR_LENIENT_OPTIONS as ParseOptions);
      if (parsed.used <= 0) {
        throw new GrainDiagError(pos === 0 ? "GRAIN_ERR_CBORSEQ_INVALID_INITIAL_BYTE" : "GRAIN_ERR_CBORSEQ_GARBAGE_TAIL");
      }
      const item = stream.slice(pos, pos + parsed.used);
      digests.push(sha256Hex(item));
      pos += parsed.used;

      if (digests.length > LIMITS.CBL_MAX_CBORSEQ_SEGMENT_ITEMS) {
        throw new GrainDiagError("GRAIN_ERR_LIMIT");
      }
    } catch (err) {
      if (err instanceof GrainDiagError) {
        if (err.code === "GRAIN_ERR_CBORSEQ_TRUNCATED") {
          throw err;
        }
        if (err.code === "CBOR_TRUNCATED_INTERNAL") {
          throw new GrainDiagError("GRAIN_ERR_CBORSEQ_TRUNCATED");
        }
        if (err.code === "GRAIN_ERR_NONCANONICAL") {
          throw new GrainDiagError(pos === 0 ? "GRAIN_ERR_CBORSEQ_INVALID_INITIAL_BYTE" : "GRAIN_ERR_CBORSEQ_GARBAGE_TAIL");
        }
        throw err;
      }
      throw new GrainDiagError("GRAIN_ERR_CBORSEQ_TRUNCATED");
    }
  }

  return { accepted: true, diag: [], out: { item_sha256_hex: digests } };
}

function opE2eDerive(input: Record<string, Json>): OperationActual {
  const syncSecret = decodeB64(input.sync_secret_b64);
  const capId = decodeB64(input.cap_id_b64);
  const cidLinkBstr = decodeB64(input.cid_link_bstr_b64);

  const derived = deriveKeyNonce(syncSecret, capId, cidLinkBstr);
  return {
    accepted: true,
    diag: [],
    out: {
      key_b64: encodeB64(derived.key),
      nonce_b64: encodeB64(derived.nonce)
    }
  };
}

function opE2eDecrypt(input: Record<string, Json>): OperationActual {
  const encryptedObjectBytes = decodeB64(input.encrypted_object_b64);
  const syncSecret = decodeB64(input.sync_secret_b64);
  const cidLink = decodeB64(input.cid_link_b64);

  if (encryptedObjectBytes.length > LIMITS.CBL_MAX_E2E_CIPHERTEXT_BYTES) {
    throw new GrainDiagError("GRAIN_ERR_LIMIT");
  }

  if (input.manifest_chash_b64 !== undefined) {
    const expected = decodeB64(input.manifest_chash_b64);
    const actual = sha256(encryptedObjectBytes);
    if (!bytesEq(expected, actual)) {
      throw new GrainDiagError("CHASH_MISMATCH");
    }
  }

  const node = parseExact(encryptedObjectBytes, STRICT_DAG_CBOR_OPTIONS);
  schemaChecks(node);

  if (node.kind !== "m") {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }

  const t = nodeAsText(mapGet(node, "t"));
  const v = nodeAsU(mapGet(node, "v"));
  const alg = nodeAsText(mapGet(node, "alg"));
  const capId = nodeAsBytes(mapGet(node, "cap_id"));
  const nonceEnv = nodeAsBytes(mapGet(node, "nonce"));
  const ct = nodeAsBytes(mapGet(node, "ct"));

  if (t !== "EncryptedObject" || v !== 1n || alg !== "A256GCM" || !capId || !nonceEnv || !ct) {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }

  if (capId.length !== 32 || nonceEnv.length !== 12) {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }

  const derived = deriveKeyNonce(syncSecret, capId, cidLink);

  let pt: Uint8Array;
  try {
    const decipher = createDecipheriv("aes-256-gcm", Buffer.from(derived.key), Buffer.from(derived.nonce), {
      authTagLength: 16
    });
    decipher.setAAD(Buffer.from(capId));

    if (ct.length < 16) {
      throw new GrainDiagError("GRAIN_ERR_AEAD_AUTH");
    }
    const body = ct.slice(0, ct.length - 16);
    const tag = ct.slice(ct.length - 16);
    decipher.setAuthTag(Buffer.from(tag));

    const plain = Buffer.concat([decipher.update(Buffer.from(body)), decipher.final()]);
    pt = new Uint8Array(plain);
  } catch {
    throw new GrainDiagError("GRAIN_ERR_AEAD_AUTH");
  }

  if (!bytesEq(nonceEnv, derived.nonce)) {
    throw new GrainDiagError("NONCE_PROFILE_MISMATCH");
  }

  return {
    accepted: true,
    diag: [],
    out: {
      pt_b64: encodeB64(pt)
    }
  };
}

function opManifestResolve(input: Record<string, Json>): OperationActual {
  const eligibleRecords = parseManifestRecords(input.eligible_records, "eligible_records");
  const eligibleTombstones = parseManifestRecords(input.eligible_tombstones, "eligible_tombstones");
  parseManifestRecords(input.ineligible_records, "ineligible_records");
  parseManifestRecords(input.ineligible_tombstones, "ineligible_tombstones");

  if (eligibleTombstones.length > 0) {
    return { accepted: true, diag: [], out: { status: "UNRESOLVABLE" } };
  }

  const puts = eligibleRecords.filter((r) => r.op === "put");
  const capToChash = new Map<string, Set<string>>();

  for (const rec of puts) {
    const capHex = Buffer.from(rec.capId ?? new Uint8Array()).toString("hex");
    const chashHex = Buffer.from(rec.chash ?? new Uint8Array()).toString("hex");
    if (!capToChash.has(capHex)) capToChash.set(capHex, new Set());
    capToChash.get(capHex)?.add(chashHex);
  }

  const conflicted = new Set<string>();
  for (const [capHex, hashes] of capToChash.entries()) {
    if (hashes.size > 1) conflicted.add(capHex);
  }

  const diagnostics: string[] = [];
  const filtered = puts.filter((r) => !conflicted.has(Buffer.from(r.capId ?? new Uint8Array()).toString("hex")));
  if (conflicted.size > 0) diagnostics.push("CAP_CHASH_CONFLICT");

  if (filtered.length === 0) {
    return { accepted: true, diag: normalizeDiag(diagnostics), out: withDiag({ status: "UNRESOLVABLE" }, diagnostics) };
  }

  let min = filtered[0].capId ?? new Uint8Array();
  for (let i = 1; i < filtered.length; i += 1) {
    const cur = filtered[i].capId ?? new Uint8Array();
    if (compareBytesLex(cur, min) < 0) {
      min = cur;
    }
  }

  return {
    accepted: true,
    diag: normalizeDiag(diagnostics),
    out: withDiag({ cap_id_b64: encodeB64(min) }, diagnostics)
  };
}

function opQrDecodeGr1(input: Record<string, Json>): OperationActual {
  const qr = input.qr_string;
  if (typeof qr !== "string") {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }
  if (!qr.startsWith("GR1:")) {
    throw new GrainDiagError("GRAIN_ERR_QR_PREFIX");
  }

  const body = qr.slice(4);
  const compressed = base45Decode(body);
  let cose: Uint8Array;
  try {
    cose = new Uint8Array(inflateSync(Buffer.from(compressed)));
  } catch {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }
  return {
    accepted: true,
    diag: [],
    out: {
      cose_b64: encodeB64(cose)
    }
  };
}

function deriveKeyNonce(syncSecret: Uint8Array, capId: Uint8Array, cidLinkBstr: Uint8Array): { key: Uint8Array; nonce: Uint8Array } {
  if (syncSecret.length !== 32 || capId.length !== 32) {
    throw new GrainDiagError("GRAIN_ERR_E2E_INPUT_LENGTH");
  }
  if (cidLinkBstr.length === 0 || cidLinkBstr[0] !== 0x00) {
    throw new GrainDiagError("GRAIN_ERR_BAD_CID_LINK");
  }

  const key = new Uint8Array(hkdfSync("sha256", Buffer.from(syncSecret), Buffer.from(capId), KEY_INFO, 32));
  const nonceInfo = Buffer.concat([NONCE_INFO_PREFIX, Buffer.from(cidLinkBstr)]);
  const nonce = new Uint8Array(hkdfSync("sha256", Buffer.from(syncSecret), Buffer.from(capId), nonceInfo, 12));
  return { key, nonce };
}

type ManifestRecord = {
  op: "put" | "del";
  capId?: Uint8Array;
  chash?: Uint8Array;
};

function parseManifestRecords(value: Json | undefined, field: string): ManifestRecord[] {
  if (value === undefined) return [];
  if (!Array.isArray(value)) {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }

  const out: ManifestRecord[] = [];
  for (const rec of value) {
    if (rec === null || typeof rec !== "object" || Array.isArray(rec)) {
      throw new GrainDiagError("GRAIN_ERR_SCHEMA");
    }
    const r = rec as Record<string, Json>;
    const op = r.op;
    if (op !== "put" && op !== "del") {
      throw new GrainDiagError("GRAIN_ERR_MANIFEST_OP");
    }

    const cap = r.cap_id_b64 !== undefined ? decodeB64(r.cap_id_b64) : undefined;
    const chash = r.chash_b64 !== undefined ? decodeB64(r.chash_b64) : undefined;

    if (op === "put") {
      if (!cap || !chash) {
        throw new GrainDiagError("GRAIN_ERR_MANIFEST_OP");
      }
      out.push({ op, capId: cap, chash });
      continue;
    }

    if (cap || chash) {
      throw new GrainDiagError("GRAIN_ERR_MANIFEST_OP");
    }
    out.push({ op });
  }

  void field;
  return out;
}

function withDiag(base: Record<string, Json>, diagnostics: string[]): Record<string, Json> {
  if (diagnostics.length === 0) {
    return base;
  }
  return {
    ...base,
    diag_contains: normalizeDiag(diagnostics)
  };
}

function allowedTopLevelKeys(t: string): string[] | undefined {
  switch (t) {
    case "IngredientRef":
      return ["v", "t", "ref_type", "ref_id", "ref_version", "name", "ext", "crit"];
    case "EncryptedObject":
      return ["v", "t", "alg", "cap_id", "nonce", "ct", "ext", "crit"];
    case "ManifestRecord":
      return ["v", "t", "ak", "seq", "cid", "op", "cap_id", "chash", "size", "ext", "crit"];
    default:
      return undefined;
  }
}
