import type { Json } from "./utils.ts";
import { encodeB64 } from "./utils.ts";
import { SdkError, toSdkError } from "./errors.ts";
import type { TsCoreEngine } from "./engine.ts";

const SECTION_REFS: Record<string, string[]> = {
  GRAIN_ERR_NONCANONICAL: ["NES §3.2", "spec/profiles/cbor-profile.md"],
  GRAIN_ERR_UNKNOWN_TOPLEVEL_KEY: ["NES §2.2"],
  GRAIN_ERR_SET_ARRAY_ORDER: ["NES §3.5", "spec/profiles/cbor-profile.md §5"],
  GRAIN_ERR_SET_ARRAY_DUP: ["NES §3.5", "spec/profiles/cbor-profile.md §5"],
  GRAIN_ERR_LIMIT: ["NES §9", "spec/profiles/cbor-profile.md §7-8"]
};

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

  explain(code: string): { code: string; message: string; section_refs: string[] } {
    return {
      code,
      message: shortMessage(code),
      section_refs: SECTION_REFS[code] ?? ["spec/NES-v0.1.md"]
    };
  }
}

function shortMessage(code: string): string {
  switch (code) {
    case "GRAIN_ERR_NONCANONICAL":
      return "Input bytes are not canonical under strict DAG-CBOR.";
    case "GRAIN_ERR_UNKNOWN_TOPLEVEL_KEY":
      return "Object contains unknown top-level keys for this type.";
    case "GRAIN_ERR_SET_ARRAY_ORDER":
      return "Set-array ordering is not canonical (raw UTF-8 byte order required).";
    case "GRAIN_ERR_SET_ARRAY_DUP":
      return "Set-array contains duplicate items.";
    case "GRAIN_ERR_LIMIT":
      return "Input exceeds strict conformance baseline limits.";
    default:
      if (code.startsWith("SDK_ERR_")) {
        return "SDK fail-closed guard rejected the operation.";
      }
      return "Core diagnostic propagated without translation.";
  }
}
