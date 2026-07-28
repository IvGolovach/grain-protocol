import { createPublicKey, verify } from "node:crypto";

import { GrainDiagError } from "../types.js";
import type { CborNode, Json, OperationActual } from "../types.js";
import {
  encodeCanonical,
  GENERIC_CBOR_CANONICAL_OPTIONS,
  nodeAsBytes,
  parseExact
} from "../cbor.js";
import { bytesEq, decodeB64, sha256 } from "../utils.js";

const ED25519_SPKI_PREFIX = Buffer.from("302a300506032b6570032100", "hex");
const ED25519_FIELD_P_LE = Buffer.from(
  "edffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f",
  "hex"
);
const ED25519_SCALAR_L_LE = Buffer.from(
  "edd3f55c1a631258d69cf7a2def9de1400000000000000000000000000000010",
  "hex"
);
const ED25519_SMALL_ORDER_ENCODINGS = [
  "0100000000000000000000000000000000000000000000000000000000000000",
  "c7176a703d4dd84fba3c0b760d10670f2a2053fa2c39ccc64ec7fd7792ac037a",
  "0000000000000000000000000000000000000000000000000000000000000080",
  "26e8958fc2b227b045c3f489f2ef98f0d5dfac05d3c63339b13802886d53fc05",
  "ecffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f",
  "26e8958fc2b227b045c3f489f2ef98f0d5dfac05d3c63339b13802886d53fc85",
  "0000000000000000000000000000000000000000000000000000000000000000",
  "c7176a703d4dd84fba3c0b760d10670f2a2053fa2c39ccc64ec7fd7792ac03fa"
].map((hex) => Buffer.from(hex, "hex"));

export function opCoseVerify(input: Record<string, Json>): OperationActual {
  const coseBytes = decodeB64(input.cose_b64);
  const pubKey = decodeB64(input.pub_b64);
  const externalAad = decodeB64(input.external_aad_b64);

  verifyCoseSign1Payload(coseBytes, pubKey, externalAad);
  return { accepted: true, diag: [], out: {} };
}

export function verifyCoseSign1Payload(
  coseBytes: Uint8Array,
  pubKey: Uint8Array,
  externalAad: Uint8Array
): { payload: Uint8Array; kid: Uint8Array } {
  if (isTopLevelTag18(coseBytes)) {
    throw new GrainDiagError("GRAIN_ERR_COSE_TAG18_FORBIDDEN");
  }

  if (externalAad.length !== 0) {
    throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
  }

  const top = parseExact(coseBytes, GENERIC_CBOR_CANONICAL_OPTIONS);
  const topCanonical = encodeCanonical(top);
  if (!bytesEq(topCanonical, coseBytes)) {
    throw new GrainDiagError("GRAIN_ERR_NONCANONICAL");
  }

  if (top.kind !== "a" || top.items.length !== 4) {
    throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
  }

  const protectedBstr = nodeAsBytes(top.items[0]);
  if (!protectedBstr) {
    throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
  }

  const unprotected = top.items[1];
  if (unprotected.kind !== "m" || unprotected.entries.length !== 0) {
    throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
  }

  const payload = nodeAsBytes(top.items[2]);
  const sigBytes = nodeAsBytes(top.items[3]);
  if (!payload || !sigBytes || sigBytes.length !== 64) {
    throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
  }

  const protectedNode = parseExact(protectedBstr, GENERIC_CBOR_CANONICAL_OPTIONS);
  const protectedCanonical = encodeCanonical(protectedNode);
  if (!bytesEq(protectedCanonical, protectedBstr)) {
    throw new GrainDiagError("GRAIN_ERR_NONCANONICAL");
  }

  const protectedKid = validateProtectedHeaders(protectedNode);

  if (pubKey.length !== 32) {
    throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
  }
  validateStrictEd25519Inputs(pubKey, sigBytes);

  const expectedKid = sha256(pubKey).slice(0, 16);
  if (!bytesEq(protectedKid, expectedKid)) {
    throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
  }

  const sigStructure: CborNode = {
    kind: "a",
    items: [
      { kind: "t", bytes: new TextEncoder().encode("Signature1") },
      { kind: "b", value: protectedBstr },
      { kind: "b", value: externalAad },
      { kind: "b", value: payload }
    ]
  };

  const toSign = encodeCanonical(sigStructure);
  const keyDer = Buffer.concat([ED25519_SPKI_PREFIX, Buffer.from(pubKey)]);

  let keyObj;
  try {
    keyObj = createPublicKey({ key: keyDer, format: "der", type: "spki" });
  } catch {
    throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
  }

  let ok = false;
  try {
    ok = verify(null, Buffer.from(toSign), keyObj, Buffer.from(sigBytes));
  } catch {
    throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
  }

  if (!ok) {
    throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
  }

  return { payload, kid: protectedKid };
}

function validateProtectedHeaders(node: CborNode): Uint8Array {
  if (node.kind !== "m" || node.entries.length !== 2) {
    throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
  }

  let algOk = false;
  let protectedKid: Uint8Array | undefined;
  for (const entry of node.entries) {
    if (entry.key.kind !== "u") {
      throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
    }

    if (entry.key.value === 1n) {
      if (entry.value.kind !== "n" || entry.value.value !== -19n) {
        throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
      }
      algOk = true;
      continue;
    }

    if (entry.key.value === 4n) {
      if (entry.value.kind !== "b") {
        throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
      }
      if (entry.value.value.length !== 16) {
        throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
      }
      protectedKid = entry.value.value;
      continue;
    }

    throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
  }

  if (!algOk || !protectedKid) {
    throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
  }
  return protectedKid;
}

function validateStrictEd25519Inputs(pubKey: Uint8Array, sigBytes: Uint8Array): void {
  const rBytes = sigBytes.subarray(0, 32);
  const sBytes = sigBytes.subarray(32, 64);
  if (
    !isCanonicalEdwardsY(pubKey) ||
    !isCanonicalEdwardsY(rBytes) ||
    isSmallOrderEdwardsEncoding(pubKey) ||
    isSmallOrderEdwardsEncoding(rBytes) ||
    !leBytesLessThan(sBytes, ED25519_SCALAR_L_LE)
  ) {
    throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
  }
}

function isCanonicalEdwardsY(bytes: Uint8Array): boolean {
  if (bytes.length !== 32) {
    return false;
  }
  const signBitSet = (bytes[31] & 0x80) !== 0;
  const y = Uint8Array.from(bytes);
  y[31] &= 0x7f;
  if (!leBytesLessThan(y, ED25519_FIELD_P_LE)) {
    return false;
  }

  // RFC 8032 point decoding rejects x=0 with the x-sign bit set. On
  // Edwards25519, x=0 only when y is 1 or -1.
  return !(signBitSet && edwardsYHasZeroX(y));
}

function edwardsYHasZeroX(y: Uint8Array): boolean {
  const isIdentity = y[0] === 1 && y.subarray(1).every((byte) => byte === 0);
  const isNegativeIdentity =
    y[0] === 0xec &&
    y.subarray(1, 31).every((byte) => byte === 0xff) &&
    y[31] === 0x7f;
  return isIdentity || isNegativeIdentity;
}

function isSmallOrderEdwardsEncoding(bytes: Uint8Array): boolean {
  return ED25519_SMALL_ORDER_ENCODINGS.some((candidate) => bytesEq(bytes, candidate));
}

function leBytesLessThan(value: Uint8Array, limit: Uint8Array): boolean {
  if (value.length !== 32 || limit.length !== 32) {
    return false;
  }
  for (let i = 31; i >= 0; i -= 1) {
    if (value[i] < limit[i]) {
      return true;
    }
    if (value[i] > limit[i]) {
      return false;
    }
  }
  return false;
}

function isTopLevelTag18(bytes: Uint8Array): boolean {
  if (bytes.length === 0) {
    return false;
  }

  const b0 = bytes[0];
  const major = b0 >> 5;
  const ai = b0 & 0x1f;

  if (major !== 6) {
    return false;
  }

  if (ai === 18) {
    return true;
  }
  if (ai === 24) {
    return bytes.length >= 2 && bytes[1] === 18;
  }
  if (ai === 25) {
    return bytes.length >= 3 && bytes[1] === 0 && bytes[2] === 18;
  }

  return false;
}
