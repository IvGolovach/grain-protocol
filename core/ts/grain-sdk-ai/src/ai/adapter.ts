export type AIInput = {
  text?: string;
  bytes_b64?: string;
  refs?: string[];
};

export type AIExplainRequest = {
  code: string;
  summary: string;
  invariant_refs: string[];
};

export type AICandidateEnvelopeV1 = {
  candidate_version: 1;
  kind: "object" | "event";
  target_schema_major: 1;
  target_type: string;
  payload_format: "structured_v1" | "dagcbor_b64";
  payload: unknown;
  critical_extensions?: string[];
};

export type AIExplainChunk = {
  summary: string;
  likely_causes: string[];
  how_to_fix: string[];
};

export interface IntelligenceAdapter {
  propose(input: AIInput): Promise<AICandidateEnvelopeV1[]>;
  explain?(request: AIExplainRequest): Promise<AIExplainChunk>;
}
