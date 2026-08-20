import { GrainDiagError, LIMITS } from "../types.js";
import type { CborNode, Json, OperationActual } from "../types.js";
import {
  mapGet,
  nodeAsBytes,
  nodeAsText,
  validateSetArrayUtf8
} from "../cbor.js";
import { schemaForLegacyTypeV1 } from "../object-schema.js";
import { parseDagCborStrict, validateTypedObjectV1 } from "../typed-object.js";
import { bytesEq, decodeB64, sha256 } from "../utils.js";

export { parseDagCborStrict, validateTypedObjectV1 } from "../typed-object.js";

export function opDagCborValidate(input: Record<string, Json>): OperationActual {
  const bytes = decodeB64(input.bytes_b64);
  if (input.object_type === undefined) {
    validateDagCborStrict(bytes);
  } else if (typeof input.object_type === "string") {
    validateTypedObjectV1(bytes, input.object_type);
  } else {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }
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
  const node = parseDagCborStrict(bytes);
  schemaChecks(node);
  return node;
}

export function validateServingOfferPayload(payload: Uint8Array, expectedIssuerKid: Uint8Array): CborNode {
  if (expectedIssuerKid.length !== 16) {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }

  const node = validateTypedObjectV1(payload, "ServingOffer");
  const issuerKid = nodeAsBytes(mapGet(node, "issuer_kid"));
  if (!issuerKid || !bytesEq(issuerKid, expectedIssuerKid)) {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }

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

  const schema = schemaForLegacyTypeV1(t);
  if (schema) {
    const allowedSet = new Set(schema.allowedTopLevelKeys);
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
    if (crit.items.length > LIMITS.CBL_MAX_CRIT_ENTRIES) {
      throw new GrainDiagError("GRAIN_ERR_LIMIT");
    }
    let total = 0;
    for (const it of crit.items) {
      if (it.kind !== "t") {
        throw new GrainDiagError("GRAIN_ERR_SCHEMA");
      }
      total += it.bytes.length;
    }
    if (total > LIMITS.CBL_MAX_CRIT_TOTAL_UTF8_BYTES) {
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
