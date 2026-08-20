# Grain Core Rust Diagnostics (TOR-02)

This file defines deterministic error/diagnostic behavior for `core/rust/grain-core`.

## Verdict diagnostics (reject)

- `GRAIN_ERR_NONCANONICAL`
- `GRAIN_ERR_DUP_MAP_KEY`
- `GRAIN_ERR_SET_ARRAY_ORDER`
- `GRAIN_ERR_SET_ARRAY_DUP`
- `GRAIN_ERR_TAG_FORBIDDEN`
- `GRAIN_ERR_UNKNOWN_TOPLEVEL_KEY`
- `GRAIN_ERR_BAD_CID_LINK`
- `GRAIN_ERR_COSE_PROFILE`
- `GRAIN_ERR_COSE_TAG18_FORBIDDEN`
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
- `CHASH_MISMATCH`
- `NONCE_PROFILE_MISMATCH`

## Auxiliary diagnostics (pass-with-diag)

- `SEQ_CONFLICT`
- `AK_REVOKED`
- `UNAUTHORIZED_GRANT_IGNORED`
- `CAP_CHASH_CONFLICT`

## Precedence (deterministic)

Global rule: once an operation reaches a deterministic terminal verdict, later checks are not evaluated.

Operation precedence order:

- `dagcbor_validate`
  1. Runner input/base64 shape, including non-string `object_type`
     (`GRAIN_ERR_SCHEMA`)
  2. Generic or selected-context structural/size limits (`GRAIN_ERR_LIMIT`)
  3. Strict CBOR canonical checks (`GRAIN_ERR_NONCANONICAL`)
  4. Duplicate map keys (`GRAIN_ERR_DUP_MAP_KEY`)
  5. Tag/CID policy (`GRAIN_ERR_TAG_FORBIDDEN`, `GRAIN_ERR_BAD_CID_LINK`)
  6. String-selector recognition and typed envelope (`GRAIN_ERR_SCHEMA`)
  7. Unknown keys (`GRAIN_ERR_UNKNOWN_TOPLEVEL_KEY`)
  8. Common top-level `ext`/`crit` shape, limits, and `crit` set-array checks
     (`GRAIN_ERR_SCHEMA`, `GRAIN_ERR_LIMIT`, set-array diagnostics)
  9. Manifest op/branch shape (`GRAIN_ERR_MANIFEST_OP`)
  10. Remaining selected-production checks in deterministic schema traversal
      (`GRAIN_ERR_SCHEMA`, set-array diagnostics, `GRAIN_ERR_LIMIT`)

The typed steps apply when vector input includes `object_type`. Without it,
`dagcbor_validate` keeps the existing generic strict DAG-CBOR path.
Unknown string selectors do not bypass byte validation; Manifest op/branch
diagnostics follow common top-level `ext`/`crit` validation and precede
remaining typed field-width diagnostics.

- `cose_verify`
  1. Tag18 gate (`GRAIN_ERR_COSE_TAG18_FORBIDDEN`)
  2. Canonical CBOR checks (`GRAIN_ERR_NONCANONICAL`)
  3. Narrow-profile shape/headers/signature checks (`GRAIN_ERR_COSE_PROFILE`)

- `parse_cborseq_stream_v1`
  1. Segment/item limits (`GRAIN_ERR_LIMIT`)
  2. Truncated terminal item (`GRAIN_ERR_CBORSEQ_TRUNCATED`)
  3. Invalid first item byte (`GRAIN_ERR_CBORSEQ_INVALID_INITIAL_BYTE`)
  4. Non-item tail after at least one valid item (`GRAIN_ERR_CBORSEQ_GARBAGE_TAIL`)

- `e2e_derive_v1`
  1. Input length (`GRAIN_ERR_E2E_INPUT_LENGTH`)
  2. CID link prefix (`GRAIN_ERR_BAD_CID_LINK`)
  3. HKDF expand errors (`GRAIN_ERR_E2E_BAD_LABEL`)

- `e2e_decrypt`
  1. Encrypted-object byte limit (`GRAIN_ERR_LIMIT`)
  2. `manifest_chash` mismatch (`CHASH_MISMATCH`)
  3. Typed `EncryptedObject` validation, following `dagcbor_validate` steps
     2-10 above: context limit; strict-byte diagnostics
     (`GRAIN_ERR_NONCANONICAL`, `GRAIN_ERR_DUP_MAP_KEY`,
     `GRAIN_ERR_TAG_FORBIDDEN`); recursive CID checks
     (`GRAIN_ERR_BAD_CID_LINK`); then typed envelope, unknown-key, `ext`/`crit`,
     set-array, limit, and schema diagnostics (`GRAIN_ERR_SCHEMA`,
     `GRAIN_ERR_UNKNOWN_TOPLEVEL_KEY`, `GRAIN_ERR_SET_ARRAY_ORDER`,
     `GRAIN_ERR_SET_ARRAY_DUP`, `GRAIN_ERR_LIMIT`)
  4. Envelope nonce differs from derived nonce (`NONCE_PROFILE_MISMATCH`)
  5. AEAD decrypt/auth failure (`GRAIN_ERR_AEAD_AUTH`)

- `manifest_resolve`
  1. Manifest op-shape validation (`GRAIN_ERR_MANIFEST_OP`)
  2. Deterministic resolution (including `CAP_CHASH_CONFLICT` as auxiliary)

- `ledger_reduce`
  1. Schema/type errors (`GRAIN_ERR_SCHEMA`)
  2. Numeric overflow (`GRAIN_ERR_OVERFLOW`)
  3. Auxiliary diagnostics (`SEQ_CONFLICT`, `AK_REVOKED`, `UNAUTHORIZED_GRANT_IGNORED`)

Contract alignment: diagnostics names match `conformance/SPEC.md` and current vectors.
