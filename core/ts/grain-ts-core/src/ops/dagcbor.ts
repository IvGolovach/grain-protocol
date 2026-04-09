import { GrainDiagError, LIMITS } from "../types.js";
import type { CborNode, Json, OperationActual } from "../types.js";
import {
  encodeCanonical,
  STRICT_DAG_CBOR_OPTIONS,
  mapGet,
  nodeAsText,
  parseExact,
  validateSetArrayUtf8
} from "../cbor.js";
import { decodeB64, sha256 } from "../utils.js";

export function opDagCborValidate(input: Record<string, Json>): OperationActual {
  const bytes = decodeB64(input.bytes_b64);
  validateDagCborStrict(bytes);
  return { accepted: true, diag: [], out: {} };
}

export function opCidDerive(input: Record<string, Json>): OperationActual {
  const bytes = decodeB64(input.bytes_b64);
  validateDagCborStrict(bytes);
  return {
    accepted: true,
    diag: [],
    out: {
      cid: deriveCidV1DagCborSha256(bytes)
    }
  };
}

export function validateDagCborStrict(bytes: Uint8Array): CborNode {
  if (bytes.length > LIMITS.CBL_MAX_DAGCBOR_OBJECT_BYTES) {
    throw new GrainDiagError("GRAIN_ERR_LIMIT");
  }

  const node = parseExact(bytes, STRICT_DAG_CBOR_OPTIONS);
  schemaChecks(node);
  return node;
}

export function schemaChecks(node: CborNode): void {
  if (node.kind !== "m") {
    return;
  }

  const t = nodeAsText(mapGet(node, "t"));
  if (!t) {
    return;
  }

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
    if (crit.kind !== "a") {
      throw new GrainDiagError("GRAIN_ERR_SCHEMA");
    }
    if (crit.items.length > 64) {
      throw new GrainDiagError("GRAIN_ERR_LIMIT");
    }
    let total = 0;
    for (const it of crit.items) {
      if (it.kind !== "t") {
        throw new GrainDiagError("GRAIN_ERR_SCHEMA");
      }
      total += it.bytes.length;
    }
    if (total > 4096) {
      throw new GrainDiagError("GRAIN_ERR_LIMIT");
    }

    const check = validateSetArrayUtf8(crit);
    if (!check.orderOk) {
      throw new GrainDiagError("GRAIN_ERR_SET_ARRAY_ORDER");
    }
    if (!check.uniqueOk) {
      throw new GrainDiagError("GRAIN_ERR_SET_ARRAY_DUP");
    }
  }

  if (t === "DeviceKeyGrant") {
    const caps = mapGet(node, "caps");
    if (caps) {
      const check = validateSetArrayUtf8(caps);
      if (!check.orderOk) {
        throw new GrainDiagError("GRAIN_ERR_SET_ARRAY_ORDER");
      }
      if (!check.uniqueOk) {
        throw new GrainDiagError("GRAIN_ERR_SET_ARRAY_DUP");
      }
    }
  }
}

function deriveCidV1DagCborSha256(bytes: Uint8Array): string {
  const digest = sha256(bytes);
  const cidBytes: number[] = [];
  pushVarint(1n, cidBytes);
  pushVarint(0x71n, cidBytes);
  pushVarint(0x12n, cidBytes);
  pushVarint(32n, cidBytes);
  for (const b of digest) {
    cidBytes.push(b);
  }
  return `b${base32LowerNoPad(new Uint8Array(cidBytes))}`;
}

function pushVarint(v: bigint, out: number[]): void {
  if (v < 0n) {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }

  let x = v;
  while (true) {
    let b = Number(x & 0x7fn);
    x >>= 7n;
    if (x !== 0n) {
      b |= 0x80;
    }
    out.push(b);
    if (x === 0n) {
      break;
    }
  }
}

function base32LowerNoPad(data: Uint8Array): string {
  const alphabet = "abcdefghijklmnopqrstuvwxyz234567";
  let out = "";
  let buffer = 0;
  let bits = 0;

  for (const byte of data) {
    buffer = (buffer << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      const idx = (buffer >> (bits - 5)) & 0x1f;
      out += alphabet[idx];
      bits -= 5;
    }
  }

  if (bits > 0) {
    const idx = (buffer << (5 - bits)) & 0x1f;
    out += alphabet[idx];
  }

  return out;
}

function allowedTopLevelKeys(t: string): string[] | undefined {
  switch (t) {
    case "IngredientRef":
      return ["v", "t", "ref_type", "ref_id", "ref_version", "name", "ext", "crit"];
    case "NutrientProfile":
      return ["v", "t", "dataset_snapshot_id", "source", "basis", "nutr", "uncert", "ext", "crit"];
    case "CookRun":
      return ["v", "t", "inputs", "yield_g", "ts_ms", "ext", "crit"];
    case "NutritionComputeResult":
      return ["v", "t", "cookrun", "engine_id", "engine_version", "dataset_snapshot_id", "map", "out", "ext", "crit"];
    case "IntakeEvent":
      return ["v", "t", "source_class", "mean", "var", "mode", "cookrun", "amount_g", "ing", "profile", "servings", "ts_ms", "ext", "crit"];
    case "ServingOffer":
      return ["v", "t", "issuer_kid", "serving_g", "mean", "var", "nonce", "ext", "crit"];
    case "LedgerGenesis":
      return ["v", "t", "root_kid", "root_pub", "ext", "crit"];
    case "DeviceKeyGrant":
      return ["v", "t", "ak", "pub", "caps", "ext", "crit"];
    case "DeviceKeyRevoke":
      return ["v", "t", "ak", "ext", "crit"];
    case "VoidEvent":
      return ["v", "t", "target", "reason", "ext", "crit"];
    case "CorrectionEvent":
      return ["v", "t", "target", "reason", "ext", "crit"];
    case "LedgerEvent":
      return ["v", "t", "ak", "seq", "ts_ms", "body", "ext", "crit"];
    case "EncryptedObject":
      return ["v", "t", "alg", "cap_id", "nonce", "ct", "ext", "crit"];
    case "ManifestRecord":
      return ["v", "t", "ak", "seq", "cid", "op", "cap_id", "chash", "size", "ext", "crit"];
    default:
      return undefined;
  }
}
