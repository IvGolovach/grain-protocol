# Conformance Harness Contract (Protocol v0.1)

This file defines a language-agnostic interface between:
- the Grain conformance suite (vectors)
- any implementation under test (runner)

The goal:
- passing the suite defines v0.1 conformance,
- a strong interoperability claim is made after two independent implementations pass the full suite.

## 1. Runner interface (MUST)

An implementation MUST provide a CLI runner executable that supports:

```
grain-runner run --strict --vector <path/to/vector.json>
```

Requirements:
- MUST run in Strict Conformance Mode when `--strict` is present.
- MUST read the vector file (UTF-8 JSON).
- MUST write a single JSON object to stdout.
- MUST exit with code 0 on pass, non-zero on fail.

## 2. Output JSON schema (MUST)

Runner output MUST include:

- `vector_id` (string) — echo from the vector
- `pass` (boolean)
- `diag` (array of strings) — deterministic diagnostic codes (may be empty)
- `out` (object) — operation-specific outputs (may be empty)

Example:

```json
{
  "vector_id": "POS-CID-001",
  "pass": true,
  "diag": [],
  "out": {
    "cid": "bafy..."
  }
}
```

## 3. Vector file format (MUST)

Vector files are JSON with:

- `vector_id` (string, stable)
- `op` (string) — which operation is tested
- `strict` (boolean, always true for v0.1 vectors)
- `input` (object) — op-specific input
- `expect` (object) — expected behavior and outputs

Binary inputs are base64-encoded strings.
Vectors MUST be concrete test cases. Placeholder/illustrative vectors are forbidden.

## 4. Operations (v0.1)

Implementations MUST support these operations for v0.1 conformance:

- `dagcbor_validate`:
  - input: `bytes_b64`
  - output: accept/reject; if accept, optional canonical bytes

- `cid_derive`:
  - input: `bytes_b64` (canonical DAG-CBOR)
  - output: `cid` (base32 lower, multibase `b`)

- `cose_verify`:
  - input: `cose_b64`, `pub_b64`, `external_aad_b64` (usually empty)
  - output: accept/reject

- `qr_decode_gr1`:
  - input: `qr_string`
  - output: accept/reject; if accept, `cose_b64`

- `e2e_decrypt`:
  - input: `encrypted_object_b64`, `sync_secret_b64`, `cid_link_b64`, optional `manifest_chash_b64`
  - output: accept/reject; if accept, `pt_b64`

- `e2e_derive_v1`:
  - input: `sync_secret_b64`, `cap_id_b64`, `cid_link_bstr_b64`
  - output: `key_b64` (32 bytes), `nonce_b64` (12 bytes)
  - validation:
    - `sync_secret` and `cap_id` MUST be exactly 32 bytes, else `GRAIN_ERR_E2E_INPUT_LENGTH`
    - `cid_link_bstr` MUST begin with `0x00` CID-link prefix, else `GRAIN_ERR_BAD_CID_LINK`
  - purpose: byte-for-byte HKDF profile conformance (labels, separators, and input binding)

- `parse_cborseq_stream_v1`:
  - input:
    - `stream_kind` (`ledger` or `manifest`)
    - either `cborseq_b64` OR `segments_b64` (array of base64 chunks concatenated in order)
  - output:
    - if accept: `item_sha256_hex` (array, one SHA-256 hex digest per decoded item bytes)
    - if reject: deterministic framing error diagnostic; reject output MUST NOT include partial item hashes
  - semantics:
    - empty stream is valid and MUST return `item_sha256_hex = []`
    - if `segments_b64` is used, implementation MUST parse concatenated bytes as one stream
    - result mode is XOR: either accept with hashes, or reject with framing diagnostic
    - deterministic framing diagnostics:
      - truncated item -> `GRAIN_ERR_CBORSEQ_TRUNCATED`
      - invalid initial item byte -> `GRAIN_ERR_CBORSEQ_INVALID_INITIAL_BYTE`
      - trailing non-item bytes after valid parse -> `GRAIN_ERR_CBORSEQ_GARBAGE_TAIL`
      - precedence anchor: when at least one full item was parsed and bytes remain, invalid next-byte classification is `GRAIN_ERR_CBORSEQ_GARBAGE_TAIL`
  - purpose: verify raw CBOR-seq framing path independent of reducer/resolution semantics

- `manifest_resolve`:
  - input:
    - `cid_b64`
    - `eligible_records` (array)
    - `eligible_tombstones` (array)
    - optional `ineligible_records` / `ineligible_tombstones` (MUST be ignored by resolver)
  - output: resolved cap_id or UNRESOLVABLE

- `ledger_reduce`:
  - input:
    - `root_kid` (string)
    - `events` (array of normalized event objects for semantics testing)
  - output: deterministic totals (sum_mean/sum_var) or deterministic error

Implementations MAY provide additional ops, but conformance only depends on the above.

## 5. Diagnostics (recommended)

Suggested deterministic diag codes (non-exhaustive):
- `GRAIN_ERR_NONCANONICAL`
- `GRAIN_ERR_DUP_MAP_KEY`
- `GRAIN_ERR_SET_ARRAY_ORDER`
- `GRAIN_ERR_SET_ARRAY_DUP`
- `GRAIN_ERR_TAG_FORBIDDEN`
- `GRAIN_ERR_UNKNOWN_TOPLEVEL_KEY`
- `GRAIN_ERR_BAD_CID_LINK`
- `GRAIN_ERR_COSE_PROFILE`
- `GRAIN_ERR_COSE_TAG18_FORBIDDEN`
- `NONCE_PROFILE_MISMATCH`
- `GRAIN_ERR_SCHEMA`
- `GRAIN_ERR_E2E_INPUT_LENGTH`
- `GRAIN_ERR_E2E_BAD_LABEL`
- `GRAIN_ERR_AEAD_AUTH`
- `GRAIN_ERR_MANIFEST_OP`
- `GRAIN_ERR_QR_PREFIX`
- `GRAIN_ERR_CBORSEQ_TRUNCATED`
- `GRAIN_ERR_CBORSEQ_GARBAGE_TAIL`
- `GRAIN_ERR_CBORSEQ_INVALID_INITIAL_BYTE`
- `GRAIN_ERR_LIMIT`
- `GRAIN_ERR_OVERFLOW`
- `SEQ_CONFLICT`
- `AK_REVOKED`
- `UNAUTHORIZED_GRANT_IGNORED`
- `CAP_CHASH_CONFLICT`
- `CAP_ID_OVERWRITE`
- `CHASH_MISMATCH`

The suite asserts behavior primarily via pass/fail; diag codes are used for auditability.
