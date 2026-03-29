import { createPublicKey, verify } from "node:crypto";

import { GrainDiagError } from "../types.js";
import type { CborNode, Json, OperationActual } from "../types.js";
import {
  encodeCanonical,
  GENERIC_CBOR_CANONICAL_OPTIONS,
  mapGet,
  nodeAsBytes,
  parseExact
} from "../cbor.js";
import { bytesEq, decodeB64 } from "../utils.js";

const ED25519_SPKI_PREFIX = Buffer.from("302a300506032b6570032100", "hex");

export function opCoseVerify(input: Record<string, Json>): OperationActual {
  const coseBytes = decodeB64(input.cose_b64);
  const pubKey = decodeB64(input.pub_b64);
  const externalAad = decodeB64(input.external_aad_b64);

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

  validateProtectedHeaders(protectedNode);

  if (pubKey.length !== 32) {
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

  return { accepted: true, diag: [], out: {} };
}

function validateProtectedHeaders(node: CborNode): void {
  if (node.kind !== "m" || node.entries.length !== 2) {
    throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
  }

  let algOk = false;
  let kidOk = false;
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
      kidOk = true;
      continue;
    }

    throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
  }

  if (!(algOk && kidOk)) {
    throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
  }
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
