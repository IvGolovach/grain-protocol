# EDGE_CASES (mandatory negative vectors index)

Hi teammate LLM. Use this as your reject-path checklist.
Every ID below points to a concrete negative vector and expected outcome.
If an implementation disagrees, treat it as a bug or drift candidate.

## Encoding
- NEG-ENC-001: non-canonical map key ordering -> REJECT
- NEG-ENC-002: non-minimal integer encoding -> REJECT
- NEG-ENC-010: duplicate map keys (any nesting) -> REJECT
- NEG-ENC-020: forbidden tag (not 42) in protocol object -> REJECT
- NEG-ENC-030: set-array order drift -> REJECT
- NEG-ENC-040: unknown top-level key -> REJECT

## UTF-8 traps
- NEG-UTF8-WA-0001: NFC/NFD ordering trap in set-array -> REJECT (raw UTF-8 ordering enforced)
- NEG-UTF8-WA-0002: UTF-16/locale sorting trap (`U+1F600` vs `U+E000`) -> REJECT
- NEG-UTF8-WA-0003: duplicate set-array item by exact UTF-8 bytes -> REJECT

## CID links
- NEG-CID-010: tag42 CID link missing 0x00 prefix -> REJECT

## COSE
- NEG-COSE-001: wrong headers / external_aad not empty / unprotected not {} -> REJECT
- NEG-COSE-010: tag18 present -> REJECT
- NEG-COSE-020: non-deterministic COSE encoding -> REJECT in core contexts

## Ledger semantics
- NEG-LED-001: non-root grant/revoke -> IGNORE for authorization
- NEG-LED-010: revoked ak events -> UNAUTHORIZED (ignored)
- NEG-LED-020: duplicate (ak,seq) different payload -> IGNORE ALL + SEQ_CONFLICT
- NEG-LED-030: reducer overflow -> GRAIN_ERR_OVERFLOW

## Ledger stream framing (raw CBOR-seq)
- NEG-LED-WA-0001: truncated final item -> GRAIN_ERR_CBORSEQ_TRUNCATED
- NEG-LED-WA-0002: garbage tail after valid items -> GRAIN_ERR_CBORSEQ_GARBAGE_TAIL
- NEG-LED-WA-0003: invalid initial byte -> GRAIN_ERR_CBORSEQ_INVALID_INITIAL_BYTE
- POS-LED-WA-0004: empty segment payload via `segments_b64` -> empty stream, `item_sha256_hex = []`
- Schema-only reject cases for `parse_cborseq_stream_v1` are specified in `conformance/SPEC.md`:
  invalid `stream_kind` and supplying both `cborseq_b64` + `segments_b64`.
  They are currently documented, but not vectorized, because the vector validator only admits canonical input shapes.
- Precedence: if at least one full item was parsed, trailing non-item bytes classify as GRAIN_ERR_CBORSEQ_GARBAGE_TAIL.

## E2E
- NEG-E2E-010: nonce mismatch (nonce != derived) -> NONCE_PROFILE_MISMATCH (reject)
- NEG-E2E-020: manifest chash mismatch on fetch/decrypt path -> CHASH_MISMATCH (reject)
- NEG-E2E-WA-0001: derive input cap_id length != 32 -> GRAIN_ERR_E2E_INPUT_LENGTH
- NEG-E2E-WA-0002: derive input sync_secret length != 32 -> GRAIN_ERR_E2E_INPUT_LENGTH
- NEG-E2E-WA-0003: derive input CID-link bstr missing 0x00 prefix -> GRAIN_ERR_BAD_CID_LINK
- NEG-E2E-WA-0004: decrypt nonce mismatch -> NONCE_PROFILE_MISMATCH
- NEG-E2E-WA-0005: decrypt missing nonce field -> GRAIN_ERR_SCHEMA
- NEG-E2E-WA-0006: decrypt AAD/auth mismatch -> GRAIN_ERR_AEAD_AUTH

## Manifest resolution
- NEG-MAN-010: ineligible records MUST NOT participate in resolution
- NEG-MAN-020: tombstone dominates put candidates -> UNRESOLVABLE
- NEG-MAN-030: same cap_id with different chash -> filter conflicting cap_id (CAP_CHASH_CONFLICT)
- NEG-MAN-040: manifest op-shape mismatch (put without chash/cap_id, malformed del) -> GRAIN_ERR_MANIFEST_OP
- NEG-MAN-WA-0200: mixed sequence with eligible tombstone still resolves to UNRESOLVABLE
- NEG-MAN-WA-0201: all eligible puts eliminated by cap/chash ambiguity -> UNRESOLVABLE + CAP_CHASH_CONFLICT
- NEG-MAN-WA-0202: mixed ineligible causes no semantic effect; deterministic eligible result preserved

## Manifest stream framing (raw CBOR-seq)
- NEG-MAN-WA-0001: truncated final item -> GRAIN_ERR_CBORSEQ_TRUNCATED
- NEG-MAN-WA-0002: garbage tail after valid items -> GRAIN_ERR_CBORSEQ_GARBAGE_TAIL
- NEG-MAN-WA-0003: invalid initial byte -> GRAIN_ERR_CBORSEQ_INVALID_INITIAL_BYTE
- Same framing precedence as ledger stream parsing.

## QR
- NEG-QR-001: wrong prefix (not GR1:) -> REJECT

## Limits
- NEG-LIM-001: baseline limits exceeded in strict mode -> GRAIN_ERR_LIMIT

See actual vector files under `conformance/vectors/`.

When you finish edge-case review, cross-check `docs/llm/INVARIANTS.md` to confirm each frozen MUST has both positive and negative executable evidence.
