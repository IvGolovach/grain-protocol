import type { Json } from "./utils.js";
import { encodeB64 } from "./utils.js";
import { describeError, toSdkError } from "./errors.js";
import type { TsCoreEngine } from "./engine.js";

export class CanonicalizationToolkit {
  private readonly engine: TsCoreEngine;

  constructor(engine: TsCoreEngine) {
    this.engine = engine;
  }

  strictValidate(bytes: Uint8Array): { bytes: Uint8Array } {
    try {
      this.engine.execute("dagcbor_validate", { bytes_b64: encodeB64(bytes) as Json }, true);
      return { bytes };
    } catch (err) {
      throw toSdkError(err);
    }
  }

  canonicalizeAndCompare(bytes: Uint8Array): { pass: true } {
    this.strictValidate(bytes);
    return { pass: true };
  }

  explain(code: string): {
    code: string;
    category: string;
    summary: string;
    hint: string;
    nes_ref: string;
    vector_refs: string[];
  } {
    const meta = describeError(code);
    return {
      code: meta.code,
      category: meta.category,
      summary: meta.summary,
      hint: meta.human_hint,
      nes_ref: meta.nes_ref,
      vector_refs: [...meta.vector_refs]
    };
  }
}
