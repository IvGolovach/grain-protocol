import { deflateSync } from "node:zlib";

import { SdkError } from "./errors.ts";
import { decodeB64, encodeB64 } from "./utils.ts";
import type { TsCoreEngine } from "./engine.ts";
import type { Json } from "./utils.ts";

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

  gr1Decode(qrString: string): { cose_bytes: Uint8Array } {
    const actual = this.engine.execute("qr_decode_gr1", { qr_string: qrString as Json }, true);
    const b64 = actual.out.cose_b64;
    if (typeof b64 !== "string") {
      throw new SdkError("SDK_ERR_TRANSPORT_DECODE", "Missing COSE bytes in decode output");
    }
    return { cose_bytes: decodeB64(b64) };
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
