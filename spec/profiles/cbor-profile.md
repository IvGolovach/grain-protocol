# Grain v0.1 — CBOR / DAG-CBOR Profile (Strict)

This document is normative for Grain Protocol v0.1.

## 1. Payload codec

- Protocol objects MUST be encoded as **DAG-CBOR** with **deterministic (canonical) CBOR** rules.
- Decoders MUST reject non-canonical encodings.
- Decoders MUST reject duplicate map keys at any nesting level.
- Definite length items only (no indefinite length).
- Floats MUST NOT appear.
- Simple values other than `false`, `true`, and `null` MUST NOT appear in protocol objects.

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

### 4.1 Typed Object Validation v1 (MUST when a known type is selected)

The `runner_v1` `dagcbor_validate` operation MAY receive `object_type` to
select one of the 14 top-level productions in `grain-v0.1.cddl`.
`object_type` is validation context and MUST NOT appear in encoded bytes.

Validation MUST cover the complete selected production, not only its
top-level key list:

- required fields and exact CBOR value kinds,
- fixed byte widths (`bstr12`, `bstr16`, `bstr32`),
- complete blessed CID-link bytes after the tag-42 `0x00` prefix,
- nested `CookInput`, `MapDecision`, and `EventRef` maps,
- exactly one `IntakeEvent` source branch,
- exactly one `ManifestRecord` `put` or `del` branch,
- int64, uint63, variance, and Food Profile non-negative domains,
- `ext`, `crit`, and all declared set-array rules,
- generic and type-specific Conformance Baseline Limits.

For fixed-type productions, encoded `t` MUST equal the selected production.
For `LedgerEvent`, `object_type="LedgerEvent"` selects the envelope while the
encoded `t` remains the event-type text string required by CDDL.

Typed validation diagnostic precedence is:

1. runner input/base64 shape, including the JSON type of `object_type`;
2. applicable generic or selected-context pre-parse size limits;
3. strict canonical DAG-CBOR, duplicate-key, tag, and CID-link checks;
4. string-selector recognition, top-level map, schema major, and selected-type
   envelope;
5. unknown keys;
6. common top-level `ext`/`crit` shape, `ext`/`crit` limits, and `crit`
   set-array checks;
7. Manifest `op`/branch shape;
8. remaining selected-production checks in deterministic schema traversal,
   including required/type/fixed-width/nested/union/numeric, type-specific
   set-array, and type-specific limit rules.

Consequently, a non-string `object_type` is an input-shape failure. An unknown
string selector is checked after strict byte validation: malformed canonical
encoding, forbidden map-key shape, tag, or CID-link errors retain precedence.
Common top-level `ext`/`crit` failures precede Manifest branch validation.
Manifest `op`/branch shape then precedes remaining field-width failures.

General shape failures use `GRAIN_ERR_SCHEMA`. Existing specific diagnostics,
including `GRAIN_ERR_UNKNOWN_TOPLEVEL_KEY`, `GRAIN_ERR_BAD_CID_LINK`,
`GRAIN_ERR_MANIFEST_OP`, set-array diagnostics, and `GRAIN_ERR_LIMIT`, remain
stable.

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
- CBL_MAX_GR1_COSE_BYTES = 16_384
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
