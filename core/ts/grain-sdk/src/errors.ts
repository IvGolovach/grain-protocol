export type ErrorCategory =
  | "VALIDATION"
  | "CANONICAL"
  | "CRYPTO"
  | "E2E"
  | "MANIFEST"
  | "LEDGER"
  | "LIMITS"
  | "QUARANTINE"
  | "CONTRACT";

export type ErrorLayer = "sdk" | "core";

export type ErrorDescriptor = {
  code: string;
  category: ErrorCategory;
  summary: string;
  human_hint: string;
  nes_ref: string;
  vector_refs: string[];
};

type ErrorInit = {
  layer?: ErrorLayer;
  category?: ErrorCategory;
  summary?: string;
  human_hint?: string;
  nes_ref?: string;
  vector_refs?: string[];
  details?: Record<string, unknown>;
};

const DEFAULT_DESCRIPTOR: ErrorDescriptor = {
  code: "SDK_ERR_INTERNAL",
  category: "CONTRACT",
  summary: "Unexpected SDK error.",
  human_hint: "Capture diagnostics and inspect SDK/core logs.",
  nes_ref: "spec/NES-v0.1.md",
  vector_refs: []
};

const ERROR_MAP: Record<string, Omit<ErrorDescriptor, "code">> = {
  SDK_ERR_STRICT_REQUIRED: {
    category: "CONTRACT",
    summary: "Strict mode is mandatory for SDK runner execution.",
    human_hint: "Pass --strict and ensure vector.strict=true.",
    nes_ref: "spec/NES-v0.1.md §9",
    vector_refs: ["INV-LIM-001"]
  },
  SDK_ERR_UNAUTHORIZED_AK: {
    category: "LEDGER",
    summary: "Active author key is not authorized.",
    human_hint: "Use root grant/revoke flow and ensure AK is not revoked.",
    nes_ref: "spec/NES-v0.1.md §6",
    vector_refs: ["INV-LED-001", "INV-LED-002"]
  },
  SDK_ERR_CAP_OVERWRITE_OR_CORRUPTION: {
    category: "E2E",
    summary: "cap_id single-assignment guard detected overwrite/corruption.",
    human_hint: "Treat storage as corrupted and prevent reuse under different ciphertext/chash.",
    nes_ref: "spec/NES-v0.1.md §7",
    vector_refs: ["INV-E2E-004"]
  },
  SDK_ERR_CSPRNG_UNAVAILABLE: {
    category: "CRYPTO",
    summary: "CSPRNG is unavailable for cap_id generation.",
    human_hint: "Fail closed and repair runtime entropy source before retry.",
    nes_ref: "spec/NES-v0.1.md §7.2",
    vector_refs: ["INV-E2E-001"]
  },
  SDK_ERR_CAP_ID_LENGTH: {
    category: "E2E",
    summary: "cap_id length is invalid.",
    human_hint: "Use exactly 32 raw bytes for cap_id.",
    nes_ref: "spec/NES-v0.1.md §7.2",
    vector_refs: ["INV-E2E-001"]
  },
  SDK_ERR_IDENTITY_BUNDLE_VERSION: {
    category: "CONTRACT",
    summary: "Identity bundle version is unsupported.",
    human_hint: "Upgrade/downgrade bundle to sdk_bundle_v1 before import.",
    nes_ref: "docs/human/sdk/overview.md",
    vector_refs: ["SDK-NEG-0005"]
  },
  SDK_ERR_IDENTITY_BUNDLE_INVALID: {
    category: "VALIDATION",
    summary: "Identity bundle is malformed.",
    human_hint: "Validate required fields and base64 payloads before import.",
    nes_ref: "docs/human/sdk/overview.md",
    vector_refs: ["SDK-NEG-0005"]
  },
  GRAIN_ERR_NONCANONICAL: {
    category: "CANONICAL",
    summary: "Input bytes are non-canonical under strict DAG-CBOR.",
    human_hint: "Serialize deterministically and reject any non-canonical bytes.",
    nes_ref: "spec/NES-v0.1.md §3",
    vector_refs: ["INV-ENC-001"]
  },
  GRAIN_ERR_SET_ARRAY_ORDER: {
    category: "CANONICAL",
    summary: "Set-array ordering is non-canonical.",
    human_hint: "Sort set-arrays by raw UTF-8 byte ordering.",
    nes_ref: "spec/NES-v0.1.md §3.5",
    vector_refs: ["INV-ENC-004"]
  },
  GRAIN_ERR_SET_ARRAY_DUP: {
    category: "CANONICAL",
    summary: "Set-array includes duplicate entries.",
    human_hint: "Deduplicate after canonical byte sort and reject duplicates.",
    nes_ref: "spec/NES-v0.1.md §3.5",
    vector_refs: ["INV-ENC-005"]
  },
  GRAIN_ERR_LIMIT: {
    category: "LIMITS",
    summary: "Input exceeds strict conformance limits.",
    human_hint: "Run in Strict Conformance Mode and enforce baseline limits exactly.",
    nes_ref: "spec/NES-v0.1.md §9",
    vector_refs: ["INV-LIM-001"]
  },
  NONCE_PROFILE_MISMATCH: {
    category: "E2E",
    summary: "Envelope nonce does not match deterministic profile derivation.",
    human_hint: "Re-derive nonce from profile labels and cid_link bytes; reject mismatch.",
    nes_ref: "spec/NES-v0.1.md §7.4",
    vector_refs: ["INV-E2E-003"]
  },
  GRAIN_ERR_AEAD_AUTH: {
    category: "CRYPTO",
    summary: "AEAD authentication failed.",
    human_hint: "Verify cap_id AAD binding, nonce derivation, and ciphertext integrity.",
    nes_ref: "spec/NES-v0.1.md §7",
    vector_refs: ["INV-E2E-002"]
  }
};

export class SdkError extends Error {
  public readonly code: string;
  public readonly layer: ErrorLayer;
  public readonly category: ErrorCategory;
  public readonly nes_ref: string;
  public readonly vector_refs: string[];
  public readonly details: Record<string, unknown>;
  public readonly human_hint: string;
  public readonly summary: string;

  constructor(code: string, message?: string, init: ErrorInit = {}) {
    const descriptor = describeError(code);
    super(message ?? descriptor.summary);
    this.code = code;
    this.layer = init.layer ?? (code.startsWith("SDK_ERR_") ? "sdk" : "core");
    this.category = init.category ?? descriptor.category;
    this.nes_ref = init.nes_ref ?? descriptor.nes_ref;
    this.vector_refs = init.vector_refs ?? descriptor.vector_refs;
    this.details = init.details ?? {};
    this.human_hint = init.human_hint ?? descriptor.human_hint;
    this.summary = init.summary ?? descriptor.summary;
    this.name = "SdkError";
  }

  toRecord(): Record<string, unknown> {
    return {
      code: this.code,
      category: this.category,
      layer: this.layer,
      nes_ref: this.nes_ref,
      vector_refs: this.vector_refs,
      details: this.details,
      human_hint: this.human_hint,
      summary: this.summary,
      message: this.message
    };
  }
}

export function describeError(code: string): ErrorDescriptor {
  const mapped = ERROR_MAP[code];
  if (mapped) {
    return {
      code,
      category: mapped.category,
      summary: mapped.summary,
      human_hint: mapped.human_hint,
      nes_ref: mapped.nes_ref,
      vector_refs: [...mapped.vector_refs]
    };
  }

  if (code.startsWith("SDK_ERR_")) {
    return {
      code,
      category: "CONTRACT",
      summary: "SDK boundary rejected the operation.",
      human_hint: "Inspect SDK call inputs and strict mode assumptions.",
      nes_ref: "docs/human/sdk/overview.md",
      vector_refs: []
    };
  }

  return {
    ...DEFAULT_DESCRIPTOR,
    code
  };
}

export function toSdkError(err: unknown): SdkError {
  if (err instanceof SdkError) {
    return err;
  }

  if (err && typeof err === "object" && "code" in err) {
    const code = (err as { code: unknown }).code;
    if (typeof code === "string") {
      return new SdkError(code, undefined, {
        layer: code.startsWith("SDK_ERR_") ? "sdk" : "core"
      });
    }
  }

  return new SdkError("SDK_ERR_INTERNAL", "Unexpected SDK error");
}
