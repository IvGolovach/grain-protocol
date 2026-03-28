import { createCipheriv } from "node:crypto";

import type { CborNode, Json } from "../../../../runner/typescript/dist/src/types.js";

import { SdkError, toSdkError } from "./errors.js";
import { compareCanonicalMapKey, encodeCanonical } from "./runner-bridge.js";
import { randomBytes32, decodeB64, encodeB64, sha256, bytesEq } from "./utils.js";
import type { GrainSdkStore } from "./store.js";
import type { IdentityManager } from "./identity.js";
import type { TsCoreEngine } from "./engine.js";
import type { ManifestManager } from "./manifest.js";
import type { ManifestResolution } from "./types.js";

export class E2ePrimitives {
  private readonly store: GrainSdkStore;
  private readonly identity: IdentityManager;
  private readonly manifest: ManifestManager;
  private readonly engine: TsCoreEngine;

  constructor(
    store: GrainSdkStore,
    identity: IdentityManager,
    manifest: ManifestManager,
    engine: TsCoreEngine
  ) {
    this.store = store;
    this.identity = identity;
    this.manifest = manifest;
    this.engine = engine;
  }

  async encrypt(plaintextObjectBytes: Uint8Array, opts: { cid_link_bstr: Uint8Array; cap_id?: Uint8Array } ): Promise<{ cap_id: Uint8Array; envelope_bytes: Uint8Array; chash: Uint8Array }> {
    const syncSecret = await this.identity.getSyncSecret();
    const capId = opts.cap_id ? new Uint8Array(opts.cap_id) : randomBytes32();

    if (capId.length !== 32) {
      throw new SdkError("SDK_ERR_CAP_ID_LENGTH", "cap_id must be 32 bytes");
    }

    const derived = this.engine.execute(
      "e2e_derive_v1",
      {
        sync_secret_b64: encodeB64(syncSecret) as Json,
        cap_id_b64: encodeB64(capId) as Json,
        cid_link_bstr_b64: encodeB64(opts.cid_link_bstr) as Json
      },
      true
    );

    const keyB64 = derived.out.key_b64;
    const nonceB64 = derived.out.nonce_b64;
    if (typeof keyB64 !== "string" || typeof nonceB64 !== "string") {
      throw new SdkError("SDK_ERR_E2E_DERIVE_OUTPUT", "Missing key/nonce from derivation output");
    }

    const key = decodeB64(keyB64);
    const nonce = decodeB64(nonceB64);

    let ctWithTag: Uint8Array;
    try {
      const cipher = createCipheriv("aes-256-gcm", Buffer.from(key), Buffer.from(nonce), { authTagLength: 16 });
      cipher.setAAD(Buffer.from(capId));
      const body = Buffer.concat([cipher.update(Buffer.from(plaintextObjectBytes)), cipher.final()]);
      const tag = cipher.getAuthTag();
      ctWithTag = new Uint8Array(Buffer.concat([body, tag]));
    } catch {
      throw new SdkError("SDK_ERR_AEAD_ENCRYPT", "Failed to encrypt payload with A256GCM");
    }

    const envelopeNode = textMap({
      alg: textNode("A256GCM"),
      cap_id: bytesNode(capId),
      ct: bytesNode(ctWithTag),
      nonce: bytesNode(nonce),
      t: textNode("EncryptedObject"),
      v: uintNode(1n)
    });

    const envelopeBytes = encodeCanonical(envelopeNode);
    const chash = sha256(envelopeBytes);

    await this.store.blobs.put(capId, envelopeBytes, chash);
    return {
      cap_id: capId,
      envelope_bytes: envelopeBytes,
      chash
    };
  }

  async encryptObject(input: {
    plaintext_cid: string;
    plaintext_bytes: Uint8Array;
    cid_link_bstr: Uint8Array;
    cap_id?: Uint8Array;
  }): Promise<{ cap_id: Uint8Array; envelope_bytes: Uint8Array; chash: Uint8Array }> {
    if (!input.plaintext_cid || input.plaintext_cid.length === 0) {
      throw new SdkError("SDK_ERR_E2E_INPUT", "plaintext_cid is required");
    }
    return this.encrypt(input.plaintext_bytes, {
      cid_link_bstr: input.cid_link_bstr,
      cap_id: input.cap_id
    });
  }

  async decrypt(capId: Uint8Array, envelopeBytes: Uint8Array, opts: { cid_link_bstr: Uint8Array; expected_chash?: Uint8Array }): Promise<Uint8Array> {
    const syncSecret = await this.identity.getSyncSecret();

    if (opts.expected_chash && !bytesEq(opts.expected_chash, sha256(envelopeBytes))) {
      throw new SdkError("CHASH_MISMATCH", "Ciphertext hash mismatch");
    }

    const input: Record<string, Json> = {
      encrypted_object_b64: encodeB64(envelopeBytes) as Json,
      sync_secret_b64: encodeB64(syncSecret) as Json,
      cid_link_b64: encodeB64(opts.cid_link_bstr) as Json
    };
    if (opts.expected_chash) {
      input.manifest_chash_b64 = encodeB64(opts.expected_chash) as Json;
    }

    const actual = this.engine.execute(
      "e2e_decrypt",
      input,
      true
    );

    const ptB64 = actual.out.pt_b64;
    if (typeof ptB64 !== "string") {
      throw new SdkError("SDK_ERR_E2E_DECRYPT_OUTPUT", "Missing plaintext bytes in decrypt output");
    }

    const persisted = await this.store.blobs.get(capId);
    if (persisted && !bytesEq(persisted.ciphertext, envelopeBytes)) {
      throw new SdkError("SDK_ERR_CAP_OVERWRITE_OR_CORRUPTION", "Stored ciphertext mismatch for cap_id");
    }

    return decodeB64(ptB64);
  }

  async decryptObject(input: {
    cap_id: Uint8Array;
    envelope_bytes: Uint8Array;
    cid_link_bstr: Uint8Array;
    expected_chash?: Uint8Array;
  }): Promise<Uint8Array> {
    return this.decrypt(input.cap_id, input.envelope_bytes, {
      cid_link_bstr: input.cid_link_bstr,
      expected_chash: input.expected_chash
    });
  }

  async putManifest(plaintextCid: string, capId: Uint8Array, chash: Uint8Array): Promise<void> {
    await this.manifest.put(plaintextCid, capId, chash);
  }

  async delManifest(plaintextCid: string): Promise<void> {
    await this.manifest.del(plaintextCid);
  }

  async resolveManifest(plaintextCid: string): Promise<ManifestResolution> {
    try {
      return await this.manifest.resolve(plaintextCid);
    } catch (err) {
      throw toSdkError(err);
    }
  }
}

function textNode(value: string): CborNode {
  return { kind: "t", bytes: new TextEncoder().encode(value) };
}

function bytesNode(value: Uint8Array): CborNode {
  return { kind: "b", value: new Uint8Array(value) };
}

function uintNode(value: bigint): CborNode {
  return { kind: "u", value };
}

function textMap(values: Record<string, CborNode>): CborNode {
  const entries = Object.entries(values).map(([k, v]) => {
    const key = textNode(k) as Extract<CborNode, { kind: "t" }>;
    return {
      key,
      keyBytes: key.bytes,
      value: v
    };
  });

  entries.sort((a, b) => compareCanonicalMapKey(a.keyBytes, b.keyBytes));
  return { kind: "m", entries };
}
