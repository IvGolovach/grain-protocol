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
  SDK_ERR_TRANSPORT_VERIFY_TRUST_REQUIRED: {
    category: "CONTRACT",
    summary: "GR1 verification requires an explicit trust public key.",
    human_hint: "Use decodeGR1() for transport decode-only flows, or pass trust.pub_b64 to verifyGR1().",
    nes_ref: "docs/human/sdk/overview.md",
    vector_refs: ["SDK-NEG-0009"]
  },
  SDK_ERR_TRANSPORT_DECODE: {
    category: "VALIDATION",
    summary: "Transport decode output is malformed.",
    human_hint: "Use a valid GR1 payload and keep the qr_decode_gr1 bridge strict.",
    nes_ref: "spec/NES-v0.1.md §8",
    vector_refs: ["NEG-QR-001", "NEG-QR-002", "NEG-QR-003"]
  },
  SDK_ERR_TRANSPORT_BUNDLE_DECODE: {
    category: "VALIDATION",
    summary: "Transport bundle bytes are not valid JSON.",
    human_hint: "Use UTF-8 JSON bytes emitted by bundleExport() or another bundle producer that matches the contract.",
    nes_ref: "docs/human/sdk/overview.md",
    vector_refs: ["SDK-NEG-0008"]
  },
  SDK_ERR_TRANSPORT_BUNDLE_SCHEMA: {
    category: "VALIDATION",
    summary: "Transport bundle payload does not match the strict SDK schema.",
    human_hint: "Keep transport bundle rows on the documented event/manifest shape with string fields and object bodies.",
    nes_ref: "docs/human/sdk/overview.md",
    vector_refs: ["SDK-NEG-0007"]
  },
  SDK_ERR_AI_ENVELOPE_INVALID: {
    category: "VALIDATION",
    summary: "AI candidate envelope is malformed.",
    human_hint: "Use candidate_version=1 envelope with required fields.",
    nes_ref: "docs/human/sdk/ai-boundary.md",
    vector_refs: ["SDK-NEG-AI-0001"]
  },
  SDK_ERR_AI_ENVELOPE_VERSION: {
    category: "CONTRACT",
    summary: "AI candidate version is unsupported.",
    human_hint: "Use candidate_version=1 for TOR-SDK-A03 boundary.",
    nes_ref: "docs/human/sdk/ai-boundary.md",
    vector_refs: ["SDK-NEG-AI-0001"]
  },
  SDK_ERR_AI_SCHEMA_MAJOR: {
    category: "CONTRACT",
    summary: "AI candidate targets unsupported schema major.",
    human_hint: "Use target_schema_major=1 with protocol major 1.",
    nes_ref: "spec/FREEZE-CONFIRMATION-v0.1.md",
    vector_refs: ["SDK-NEG-AI-0001"]
  },
  SDK_ERR_AI_KIND_INVALID: {
    category: "VALIDATION",
    summary: "AI candidate kind is invalid.",
    human_hint: "kind must be object or event.",
    nes_ref: "docs/human/sdk/ai-boundary.md",
    vector_refs: ["SDK-NEG-AI-0001"]
  },
  SDK_ERR_AI_TARGET_TYPE: {
    category: "VALIDATION",
    summary: "AI candidate target_type is invalid.",
    human_hint: "Provide a non-empty target_type string.",
    nes_ref: "docs/human/sdk/ai-boundary.md",
    vector_refs: ["SDK-NEG-AI-0001"]
  },
  SDK_ERR_AI_PAYLOAD_FORMAT: {
    category: "VALIDATION",
    summary: "AI candidate payload_format is invalid.",
    human_hint: "payload_format must be structured_v1 or dagcbor_b64.",
    nes_ref: "docs/human/sdk/ai-boundary.md",
    vector_refs: ["SDK-NEG-AI-0001"]
  },
  SDK_ERR_AI_DAGCBOR_B64: {
    category: "VALIDATION",
    summary: "AI DAG-CBOR payload must be base64 standard bytes.",
    human_hint: "Encode bytes using standard base64 and keep padding canonical.",
    nes_ref: "docs/human/sdk/ai-ingestion.md",
    vector_refs: ["SDK-NEG-AI-0002"]
  },
  SDK_ERR_AI_STRUCTURED_INVALID: {
    category: "VALIDATION",
    summary: "structured_v1 payload is invalid.",
    human_hint: "Use structured_v1 payload with data and optional pointer maps.",
    nes_ref: "docs/human/sdk/ai-ingestion.md",
    vector_refs: ["SDK-NEG-AI-0002"]
  },
  SDK_ERR_AI_NUMERIC_FIELDS: {
    category: "VALIDATION",
    summary: "numeric_fields configuration is invalid.",
    human_hint: "numeric_fields must map json-pointer paths to u63|i64.",
    nes_ref: "docs/human/sdk/ai-ingestion.md",
    vector_refs: ["SDK-NEG-AI-0003"]
  },
  SDK_ERR_AI_NUMERIC_NOT_DECIMAL_STRING: {
    category: "VALIDATION",
    summary: "Numeric ingestion field is not a decimal string.",
    human_hint: "Provide numeric values as decimal strings in structured_v1.",
    nes_ref: "docs/human/sdk/ai-ingestion.md",
    vector_refs: ["SDK-NEG-AI-0003"]
  },
  SDK_ERR_AI_NUMERIC_RANGE: {
    category: "VALIDATION",
    summary: "Numeric ingestion field is out of allowed range.",
    human_hint: "Keep u63/i64 fields inside protocol integer bounds.",
    nes_ref: "spec/NES-v0.1.md §3",
    vector_refs: ["SDK-NEG-AI-0003"]
  },
  SDK_ERR_AI_BYTES_B64: {
    category: "VALIDATION",
    summary: "Bytes ingestion field is not valid base64 standard.",
    human_hint: "Use standard base64 for bytes_fields in structured_v1.",
    nes_ref: "docs/human/sdk/ai-ingestion.md",
    vector_refs: ["SDK-NEG-AI-0004"]
  },
  SDK_ERR_AI_POINTER_INVALID: {
    category: "CONTRACT",
    summary: "JSON pointer format is invalid.",
    human_hint: "Use RFC6901 pointers beginning with '/'.",
    nes_ref: "docs/human/sdk/ai-ingestion.md",
    vector_refs: ["SDK-NEG-AI-0005"]
  },
  SDK_ERR_AI_POINTER_MISSING: {
    category: "VALIDATION",
    summary: "JSON pointer path does not exist in structured payload.",
    human_hint: "Update pointer maps to match the structured payload shape.",
    nes_ref: "docs/human/sdk/ai-ingestion.md",
    vector_refs: ["SDK-NEG-AI-0005"]
  },
  SDK_ERR_AI_PROFILE_ID: {
    category: "VALIDATION",
    summary: "structured_v1 profile_id is invalid.",
    human_hint: "Provide a non-empty profile_id string or omit profile_id.",
    nes_ref: "docs/human/sdk/ai-ingestion.md",
    vector_refs: ["SDK-NEG-AI-0012"]
  },
  SDK_ERR_AI_PROFILE_MISSING: {
    category: "CONTRACT",
    summary: "structured_v1 candidate is missing explicit field profile metadata.",
    human_hint: "Set profile_id or provide explicit numeric/bytes/set field maps.",
    nes_ref: "docs/human/sdk/ai-ingestion.md",
    vector_refs: ["SDK-NEG-AI-0012"]
  },
  SDK_ERR_AI_PROFILE_UNKNOWN: {
    category: "CONTRACT",
    summary: "structured_v1 profile_id is unknown.",
    human_hint: "Use an exported profile_id from ai.exportContract() or explicit field maps.",
    nes_ref: "docs/human/sdk/ai-ingestion.md",
    vector_refs: ["SDK-NEG-AI-0012"]
  },
  SDK_ERR_AI_SET_ARRAY_INVALID: {
    category: "CANONICAL",
    summary: "Set-array ingestion field is invalid.",
    human_hint: "Set-array fields must be arrays of strings; duplicates reject.",
    nes_ref: "spec/NES-v0.1.md §3.5",
    vector_refs: ["SDK-NEG-AI-0006"]
  },
  SDK_ERR_AI_QUARANTINED_UNKNOWN_CRITICAL: {
    category: "QUARANTINE",
    summary: "Candidate references unknown critical extensions and is quarantined.",
    human_hint: "Register/allow known critical extensions or keep candidate in quarantine lane.",
    nes_ref: "spec/NES-v0.1.md §5",
    vector_refs: ["SDK-NEG-AI-0007"]
  },
  SDK_ERR_AI_CID_DERIVE: {
    category: "CONTRACT",
    summary: "CID derivation output is malformed.",
    human_hint: "Treat as SDK/core contract regression and block apply.",
    nes_ref: "conformance/contract/runner_v1.md",
    vector_refs: ["SDK-NEG-AI-0008"]
  },
  SDK_ERR_ACCEPT_TOKEN_FORGED: {
    category: "CONTRACT",
    summary: "Accepted token is forged or external to SDK registry.",
    human_hint: "Only pass opaque token returned by ai.accept().",
    nes_ref: "docs/human/sdk/ai-boundary.md",
    vector_refs: ["SDK-NEG-AI-0009"]
  },
  SDK_ERR_ACCEPT_TOKEN_UNKNOWN: {
    category: "CONTRACT",
    summary: "Accepted token is unknown or already consumed.",
    human_hint: "Do not reuse apply tokens; request a fresh accept().",
    nes_ref: "docs/human/sdk/ai-boundary.md",
    vector_refs: ["SDK-NEG-AI-0009"]
  },
  SDK_ERR_ACCEPT_TOKEN_EXPIRED: {
    category: "CONTRACT",
    summary: "Accepted token expired before apply.",
    human_hint: "Re-run accept() and apply the new token within TTL.",
    nes_ref: "docs/human/sdk/ai-boundary.md",
    vector_refs: ["SDK-NEG-AI-0010"]
  },
  SDK_ERR_ACCEPT_TOKEN_CAP_REACHED: {
    category: "LIMITS",
    summary: "Accepted token registry capacity exceeded.",
    human_hint: "Apply or discard pending tokens before issuing more.",
    nes_ref: "docs/human/sdk/ai-boundary.md",
    vector_refs: ["SDK-NEG-AI-0011"]
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
