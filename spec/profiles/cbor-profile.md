# Grain v0.1 — CBOR / DAG-CBOR Profile (Strict)

This document is normative for Grain Protocol v0.1.

## 1. Payload codec

- Protocol objects MUST be encoded as **DAG-CBOR** with **deterministic (canonical) CBOR** rules.
- Decoders MUST reject non-canonical encodings.
- Decoders MUST reject duplicate map keys at any nesting level.
- Definite length items only (no indefinite length).
- Floats MUST NOT appear.

## 2. Tags

- Tags are forbidden inside protocol objects, except:
  - tag 42 for CID links.

Any other tag MUST be rejected.

## 3. String rules

- All tstr MUST be valid UTF-8.
- No Unicode normalization is applied anywhere.
- Sorting/comparison for canonical set semantics MUST be lexicographic by raw UTF-8 bytes.

## 4. Closed top-level keys

Top-level keys for each object type are closed by NES rule.
Unknown top-level keys MUST be rejected.

## 5. Set-array semantics (MUST)

Grain v0.1 defines a **closed list** of fields that MUST be treated as set-arrays:

- `*.crit`
- `CookRun.inputs`
- `NutritionComputeResult.map`
- `DeviceKeyGrant.caps`

(And any other set-field explicitly listed in v0.1 CDDL.)

Requirements for set-arrays:
- MUST be sorted by the specified ordering key.
- MUST contain no duplicates.
- Violation MUST cause object/event rejection.

### Ordering keys

- For arrays of tstr (e.g., `*.crit`, `DeviceKeyGrant.caps`):
  - sort by raw UTF-8 bytes, lexicographic ascending.
  - duplicates defined by exact byte equality.

- For arrays of structured items (e.g., `CookRun.inputs`, `NutritionComputeResult.map`):
  - sort by the canonical bytes of the item (strict DAG-CBOR encoding), lexicographic ascending.
  - duplicates defined by exact canonical bytes equality.

## 6. Fixed numeric domains (MUST)

- Numeric values MUST fit in int64/uint63 as required by the schema.
- Any numeric field outside domain MUST be rejected.

Variance fields:
- MUST be >= 0.
- Negative variance MUST be rejected.

Reducers:
- MUST compute in extended precision.
- MUST return deterministic `GRAIN_ERR_OVERFLOW` if output cannot be represented.
- MUST NOT wrap and MUST NOT saturate.

## 7. Conformance Baseline Limits (CBL)

Implementations MUST support at least these baseline limits:

Parsing / structural:
- CBL_MAX_CBOR_NESTING_DEPTH = 32
- CBL_MAX_CBOR_MAP_PAIRS = 4096
- CBL_MAX_CBOR_ARRAY_LENGTH = 4096
- CBL_MAX_TSTR_UTF8_BYTES = 1024

Payload sizes:
- CBL_MAX_DAGCBOR_OBJECT_BYTES = 5_000_000
- CBL_MAX_EXT_CANONICAL_BYTES = 65_536
- CBL_MAX_CRIT_ENTRIES = 64
- CBL_MAX_CRIT_TOTAL_UTF8_BYTES = 4096

Context-specific:
- CBL_MAX_LEDGER_EVENT_PAYLOAD_BYTES = 32_768
- CBL_MAX_MANIFEST_RECORD_PAYLOAD_BYTES = 8_192
- CBL_MAX_SERVINGOFFER_PAYLOAD_BYTES = 2_048
- CBL_MAX_E2E_CIPHERTEXT_BYTES = 8_000_000

CBOR-seq segments:
- CBL_MAX_CBORSEQ_SEGMENT_BYTES = 64_000_000
- CBL_MAX_CBORSEQ_SEGMENT_ITEMS = 1_000_000

## 8. Strict Conformance Mode (MUST)

Implementations MUST provide a Strict Conformance Mode where:
- The baseline limits above are enforced exactly.
- Exceeding any baseline limit MUST return deterministic `GRAIN_ERR_LIMIT`.

Conformance suite runs only in Strict Conformance Mode.

Implementations MAY support higher limits outside strict mode, but behavior must remain deterministic and documented.

