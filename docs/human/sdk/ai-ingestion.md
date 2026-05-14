# SDK AI Ingestion Contract (Candidate v1)

This is an SDK ingestion contract, not a protocol semantic change.

## Envelope v1

Required fields:

- `candidate_version: 1`
- `kind: "object"`
- `target_schema_major: 1`
- `target_type: string`
- `payload_format: "structured_v1" | "dagcbor_b64"`
- `payload`

Optional:

- `critical_extensions: string[]`

`kind: "event"` is reserved and rejected in this sidecar version until an `event_append` apply path exists.

## payload_format = structured_v1

Shape:

- `data`
- `profile_id?: string`
- `numeric_fields?: { "<json-pointer>": "u63" | "i64" }`
- `bytes_fields?: string[]`
- `set_array_fields?: string[]`

Rules:

- JSON numbers are forbidden in `data`.
- Numeric protocol fields are accepted as decimal strings for ingestion convenience only, then converted deterministically.
- Field typing must be explicit:
  - either via known `profile_id` (see `ai.exportContract().profiles`)
  - or via explicit `numeric_fields` / `bytes_fields` / `set_array_fields`.
- If no profile and no explicit field maps are provided, SDK rejects (`SDK_ERR_AI_PROFILE_MISSING`).
- `bytes_fields` must be canonical base64 standard strings, including canonical padding and zero pad bits.
- `set_array_fields` may be normalized by deterministic sorting.
- Duplicate set entries are rejected.

Important:
This normalization is only in AI ingestion. Strict protocol validation still rejects non-canonical bytes.

## payload_format = dagcbor_b64

- Payload must be canonical base64 standard encoded DAG-CBOR bytes, including canonical padding and zero pad bits.
- Bytes are strict-validated unchanged.

## Quarantine behavior

Unknown critical extensions produce deterministic `quarantined` result.
Quarantined candidates cannot be applied.

## applyAccepted() behavior in v1

`applyAccepted()` persists accepted canonical bytes to object store by CID.
It does not auto-append ledger events in v1.
