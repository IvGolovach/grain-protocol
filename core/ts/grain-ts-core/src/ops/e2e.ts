import { createDecipheriv, hkdfSync } from "node:crypto";

import { GrainDiagError, LIMITS } from "../types.js";
import type { Json, OperationActual } from "../types.js";
import {
  STRICT_DAG_CBOR_OPTIONS,
  mapGet,
  nodeAsBytes,
  nodeAsText,
  nodeAsU,
  parseExact
} from "../cbor.js";
import { bytesEq, decodeB64, encodeB64, sha256 } from "../utils.js";
import { schemaChecks } from "./dagcbor.js";

const KEY_INFO = Buffer.from("GrainE2E\0v0.1\0A256GCM\0key", "ascii");
const NONCE_INFO_PREFIX = Buffer.from("GrainE2E\0v0.1\0A256GCM\0nonce\0", "ascii");

export function opE2eDerive(input: Record<string, Json>): OperationActual {
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

export function opE2eDecrypt(input: Record<string, Json>): OperationActual {
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
