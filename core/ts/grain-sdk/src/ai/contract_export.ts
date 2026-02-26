export type ContractExportV1 = {
  contract_version: 1;
  candidate_schema: {
    candidate_version: 1;
    kind: ["object", "event"];
    payload_format: ["structured_v1", "dagcbor_b64"];
  };
  structured_v1_rules: {
    numeric_policy: string;
    bytes_policy: string;
    set_array_policy: string;
  };
  prohibitions: string[];
  examples: {
    valid_structured_object: Record<string, unknown>;
    invalid_numeric_number: Record<string, unknown>;
  };
  profiles?: Array<{
    profile_id: string;
    numeric_fields: string[];
    bytes_fields: string[];
    set_array_fields: string[];
  }>;
};

export function exportAiContract(): ContractExportV1 {
  return {
    contract_version: 1,
    candidate_schema: {
      candidate_version: 1,
      kind: ["object", "event"],
      payload_format: ["structured_v1", "dagcbor_b64"]
    },
    structured_v1_rules: {
      numeric_policy: "Ingestion convenience only: numeric protocol fields are accepted as decimal strings and converted deterministically.",
      bytes_policy: "Bytes in structured_v1 MUST be base64 standard (A-Z a-z 0-9 + / with optional = padding).",
      set_array_policy: "AI ingestion may normalize unsorted set-arrays; duplicates are always rejected."
    },
    prohibitions: [
      "No network calls from SDK AI boundary.",
      "No append bypass around accept() -> applyAccepted().",
      "No unknown critical extension auto-apply."
    ],
    examples: {
      valid_structured_object: {
        candidate_version: 1,
        kind: "object",
        target_schema_major: 1,
        target_type: "Claim",
        payload_format: "structured_v1",
        payload: {
          data: {
            claim_id: "abc-1",
            amount: "42",
            tags: ["gamma", "alpha", "beta"]
          },
          numeric_fields: {
            "/amount": "u63"
          },
          set_array_fields: ["/tags"]
        }
      },
      invalid_numeric_number: {
        candidate_version: 1,
        kind: "object",
        target_schema_major: 1,
        target_type: "Claim",
        payload_format: "structured_v1",
        payload: {
          data: {
            amount: 42
          },
          numeric_fields: {
            "/amount": "u63"
          }
        }
      }
    }
  };
}
