# ADR-0001 (conformance): Wave A byte-level ops for court hardening

- Status: Accepted
- Date: 2026-02-20
- Scope: Conformance contract only (`conformance/SPEC.md`), protocol semantics unchanged
- Related TOR: TOR-01

## Context

Protocol v0.1 frozen core requires byte-level interoperability. Existing conformance vectors verified many semantics but left two byte-path classes underspecified in the harness contract:

1. Raw CBOR-seq framing path for ledger/manifest stream ingestion.
2. Deterministic HKDF derivation outputs as exact bytes (key/nonce), independent of decrypt path.

Without explicit harness operations for these classes, implementations can diverge while still passing structure-level vectors.

## Decision

Add two conformance operations:

1. `parse_cborseq_stream_v1`
- Input: `stream_kind`, and either `cborseq_b64` or `segments_b64`.
- Output: accept with `item_sha256_hex[]` or reject with deterministic framing diagnostics.
- Purpose: enforce stream framing correctness before semantic reducers.

2. `e2e_derive_v1`
- Input: `sync_secret_b64`, `cap_id_b64`, `cid_link_bstr_b64`.
- Output: exact `key_b64` and `nonce_b64`.
- Purpose: enforce deterministic HKDF profile at byte level.

## Non-goals

- No protocol invariant changes.
- No change to schema major.
- No changes to frozen NES semantics.

## Consequences

Positive:
- Byte-path interop failures are promoted to conformance failures.
- JS/TS and Rust implementations get direct deterministic evidence for KDF correctness.

Cost:
- Runner implementations must add two operations.
- Vector validator receives additional shape checks.

## Compatibility

This ADR changes conformance contract surface only; protocol remains v0.1 frozen core.

