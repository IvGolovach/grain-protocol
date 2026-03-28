import { deflateSync } from "node:zlib";

import { SdkError } from "./errors.js";
import { decodeB64, encodeB64, stableStringify, toUtf8 } from "./utils.js";
import type { TsCoreEngine } from "./engine.js";
import type { Json } from "./utils.js";

const BASE45_ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:";

export class TransportToolkit {
  private readonly engine: TsCoreEngine;

  constructor(engine: TsCoreEngine) {
    this.engine = engine;
  }

  gr1Encode(coseBytes: Uint8Array): string {
    const compressed = new Uint8Array(deflateSync(Buffer.from(coseBytes)));
    return `GR1:${base45Encode(compressed)}`;
  }

  encodeGR1(input: { payload: Uint8Array }): string {
    return this.gr1Encode(input.payload);
  }

  gr1Decode(qrString: string): { cose_bytes: Uint8Array } {
    const actual = this.engine.execute("qr_decode_gr1", { qr_string: qrString as Json }, true);
    const b64 = actual.out.cose_b64;
    if (typeof b64 !== "string") {
      throw new SdkError("SDK_ERR_TRANSPORT_DECODE", "Missing COSE bytes in decode output");
    }
    return { cose_bytes: decodeB64(b64) };
  }

  decodeGR1(input: { qr_string: string }): { payload_bytes: Uint8Array; cose_bytes: Uint8Array } {
    const decoded = this.gr1Decode(input.qr_string);
    return {
      payload_bytes: decoded.cose_bytes,
      cose_bytes: decoded.cose_bytes
    };
  }

  gr1Verify(qrString: string, trust?: { pub_b64: string }): { pass: boolean; diag: string[]; cose_bytes: Uint8Array } {
    const decoded = this.gr1Decode(qrString);
    if (!trust?.pub_b64) {
      return { pass: true, diag: [], cose_bytes: decoded.cose_bytes };
    }

    const actual = this.engine.execute(
      "cose_verify",
      {
        cose_b64: encodeB64(decoded.cose_bytes) as Json,
        pub_b64: trust.pub_b64 as Json,
        external_aad_b64: "" as Json
      },
      true
    );

    return { pass: actual.accepted, diag: actual.diag, cose_bytes: decoded.cose_bytes };
  }

  verifyGR1(input: { qr_string: string; trust?: { pub_b64: string } }): { pass: boolean; diag: string[]; cose_bytes: Uint8Array } {
    return this.gr1Verify(input.qr_string, input.trust);
  }

  bundleExport(input: {
    objects?: Record<string, Uint8Array>;
    events?: Record<string, Json>[];
    manifest?: Record<string, Json>[];
    evidence?: Record<string, Json>;
  }): Uint8Array {
    const objectEntries = Object.entries(input.objects ?? {}).sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0));
    const objects: Record<string, Json> = {};
    for (const [cid, bytes] of objectEntries) {
      objects[cid] = encodeB64(bytes);
    }

    const payload: Record<string, Json> = {
      schema: "grain-transport-bundle-v1",
      strict: true,
      objects,
      events: (input.events ?? []).map((x) => ({ ...x })),
      manifest: (input.manifest ?? []).map((x) => ({ ...x })),
      evidence: { ...(input.evidence ?? {}) }
    };

    return toUtf8(stableStringify(payload));
  }

  bundleImport(bytes: Uint8Array): {
    schema: string;
    strict: boolean;
    objects: Record<string, Uint8Array>;
    events: Record<string, Json>[];
    manifest: Record<string, Json>[];
    evidence: Record<string, Json>;
  } {
    let decoded: Json;
    try {
      decoded = JSON.parse(Buffer.from(bytes).toString("utf8")) as Json;
    } catch {
      throw new SdkError("SDK_ERR_TRANSPORT_BUNDLE_DECODE", "Bundle bytes are not valid JSON");
    }

    if (!decoded || typeof decoded !== "object" || Array.isArray(decoded)) {
      throw new SdkError("SDK_ERR_TRANSPORT_BUNDLE_SCHEMA", "Bundle root must be an object");
    }

    const root = decoded as Record<string, Json>;
    if (root.schema !== "grain-transport-bundle-v1") {
      throw new SdkError("SDK_ERR_TRANSPORT_BUNDLE_SCHEMA", "Unsupported bundle schema");
    }
    if (root.strict !== true) {
      throw new SdkError("SDK_ERR_TRANSPORT_BUNDLE_SCHEMA", "Bundle must declare strict=true");
    }

    const objectsJson = root.objects;
    if (!objectsJson || typeof objectsJson !== "object" || Array.isArray(objectsJson)) {
      throw new SdkError("SDK_ERR_TRANSPORT_BUNDLE_SCHEMA", "Bundle objects section must be an object");
    }
    const objects: Record<string, Uint8Array> = {};
    for (const [cid, b64] of Object.entries(objectsJson as Record<string, Json>)) {
      if (typeof b64 !== "string") {
        throw new SdkError("SDK_ERR_TRANSPORT_BUNDLE_SCHEMA", "Bundle object payload must be base64 string");
      }
      objects[cid] = decodeB64(b64);
    }

    const events = parseRowArray(root.events, "events");
    const manifest = parseRowArray(root.manifest, "manifest");
    const evidence = parseObject(root.evidence, "evidence");

    return {
      schema: "grain-transport-bundle-v1",
      strict: true,
      objects,
      events,
      manifest,
      evidence
    };
  }
}

function base45Encode(data: Uint8Array): string {
  let out = "";
  let i = 0;

  while (i < data.length) {
    if (i + 1 < data.length) {
      const x = data[i] * 256 + data[i + 1];
      const e = x % 45;
      const d = Math.floor(x / 45) % 45;
      const c = Math.floor(x / (45 * 45));
      out += BASE45_ALPHABET[e] + BASE45_ALPHABET[d] + BASE45_ALPHABET[c];
      i += 2;
      continue;
    }

    const x = data[i];
    const d = Math.floor(x / 45);
    const e = x % 45;
    out += BASE45_ALPHABET[e] + BASE45_ALPHABET[d];
    i += 1;
  }

  return out;
}

function parseRowArray(value: Json, field: string): Record<string, Json>[] {
  if (!Array.isArray(value)) {
    throw new SdkError("SDK_ERR_TRANSPORT_BUNDLE_SCHEMA", `Bundle ${field} must be an array`);
  }
  return value.map((row) => parseObject(row, field));
}

function parseObject(value: Json, field: string): Record<string, Json> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new SdkError("SDK_ERR_TRANSPORT_BUNDLE_SCHEMA", `Bundle ${field} entries must be objects`);
  }
  return { ...(value as Record<string, Json>) };
}
