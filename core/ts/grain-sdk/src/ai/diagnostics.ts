import { describeError, type ErrorCategory } from "../errors.js";

export type AIExplainPayload = {
  code: string;
  category: ErrorCategory;
  summary: string;
  likely_causes: string[];
  how_to_fix: string[];
  spec_refs: string[];
  invariant_refs: string[];
  vector_refs: string[];
  normalization_applied: string[];
  redaction_policy: {
    include_sensitive: boolean;
    includes_raw_candidate_bytes: boolean;
    includes_plaintext_private_bytes: boolean;
  };
  sensitive_details?: {
    candidate_sha256_16?: string;
    payload_bytes?: number;
    token_id_prefix?: string;
  };
};

type ExplainContext = {
  invariant_refs: string[];
  normalization_applied?: string[];
  include_sensitive?: boolean;
  sensitive_details?: {
    candidate_sha256_16?: string;
    payload_bytes?: number;
    token_id_prefix?: string;
  };
};

export function buildAiExplain(code: string, context: ExplainContext): AIExplainPayload {
  const meta = describeError(code);
  const includeSensitive = context.include_sensitive === true;
  return {
    code,
    category: meta.category,
    summary: meta.summary,
    likely_causes: [
      `${meta.code} triggered at SDK AI acceptance boundary.`,
      "Input candidate does not satisfy strict deterministic ingestion rules."
    ],
    how_to_fix: [
      meta.human_hint,
      "Keep candidate_version=1 and align payload with structured_v1 or dagcbor_b64 contract."
    ],
    spec_refs: [meta.nes_ref],
    invariant_refs: [...context.invariant_refs],
    vector_refs: [...meta.vector_refs],
    normalization_applied: [...(context.normalization_applied ?? [])],
    redaction_policy: {
      include_sensitive: includeSensitive,
      includes_raw_candidate_bytes: false,
      includes_plaintext_private_bytes: false
    },
    sensitive_details: includeSensitive ? { ...(context.sensitive_details ?? {}) } : undefined
  };
}
