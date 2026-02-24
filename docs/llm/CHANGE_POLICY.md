# CHANGE_POLICY (v0.1 frozen core)

This file is written for LLM-assisted contributions.

## Frozen core (v0.1)

The following are locked for v0.1 and MUST NOT change without a protocol major bump:
- DAG-CBOR strictness rules (reject non-canonical; reject duplicate keys; tags only 42)
- blessed CID set (CIDv1 + dag-cbor + sha2-256 + base32 lower)
- COSE narrow profile (Ed25519 only; deterministic bytes; tag18 forbidden)
- set-array closed list + sorting/uniqueness semantics
- numeric domains + overflow behavior
- ledger authorization: root-only grant/revoke + retroactive revoke
- (ak,seq) uniqueness conflict ignore-all rule
- quarantine semantics and precedence
- E2E envelope: HKDF-SHA256 + A256GCM, AAD=cap_id, deterministic nonce, cap_id single-assignment + chash binding
- manifest eligibility, strict op-shape (`put|del`), and deterministic resolution
- GR1 prefix and QR pipeline
- baseline limits + Strict Conformance Mode behavior

## Allowed additive changes (still require ADR + vectors)

- new protocol object types (`t`) within schema major 1
- new transport profiles with new prefixes (GR2:, etc.)
- new pairing mechanisms that distribute sync_secret without changing envelope semantics
- additional tooling/docs

## Conformance contract changes (MUST process)

If `conformance/SPEC.md` changes (new op, input/output shape, diagnostics contract):
- MUST add ADR under `adr/conformance/`.
- MUST update `docs/llm/CONFORMANCE.md`.
- MUST update `docs/llm/INVARIANTS.md` and `docs/llm/EDGE_CASES.md` for new vectors.
- MUST update `CHANGELOG.md`.

## Provenance / CI changes (MUST process)

If PR changes CI gates, evidence artifacts, branch protection policy, tag namespace policy, or migration/provenance docs:
- MUST update `docs/human/github-hardening.md`.
- MUST update `MIGRATION.md` if reconstruction/provenance statements change.
- MUST keep required CI context names stable unless governance update is explicit.
- MUST update `CHANGELOG.md`.
- MUST update `spec/RC-POLICY.md` and `spec/INTEROP-CLAIM.md` when RC/claim process changes.

## Red flags (likely breaking)

- any change in canonicalization rules
- any change in blessed CID set
- any change in COSE headers/algs for core contexts
- any change in ledger reducer semantics or conflict rules
- any change in deterministic nonce derivation or AAD binding
- any change in manifest resolution tie-break
