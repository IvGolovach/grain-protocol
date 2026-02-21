# Changelog

This project follows a protocol-frozen posture: v0.1 core invariants do not change.

## [Unreleased]
- No pending entries.

## [0.3.1] - 2026-02-21
- Fixed `tools/github/apply_branch_protection.sh`:
  - branch protection API payload now sent as typed JSON via `--input`
  - resolves GitHub API `422` caused by stringified booleans with `-f`
- No protocol/conformance semantic changes.

## [0.3.0] - 2026-02-21
- Repository provenance migration and GitHub hardening (TOR-GH-P01):
  - commit-bound evidence artifacts in CI (`evidence-<sha>.zip`)
  - release tag evidence workflow (`.github/workflows/release-evidence.yml`)
  - branch-protection helper and governance hardening files
  - migration disclosure (`MIGRATION.md`, ADR-0002)
  - `.gitattributes` and `.nvmrc` pinning for cross-platform determinism
- Rust reference Core included (TOR-02):
  - `core/rust/grain-core`
  - `core/rust/grain-runner`
  - strict conformance execution in CI
- TypeScript C01 smoke runner included (TOR-03):
  - `runner/typescript` with C01 profile (Wave A vectors)
  - Rust↔TS divergence reporting
- Protocol semantics unchanged (frozen v0.1 core preserved).

## [0.2.0] - 2026-02-20
- TOR-01 / Wave A completed for byte-level conformance closure.
- Conformance contract extended with:
  - `parse_cborseq_stream_v1` for raw CBOR-seq framing checks
  - `e2e_derive_v1` for deterministic HKDF expected-bytes checks
- Added Wave A vector packs:
  - ledger raw stream framing (`*-LED-WA-*`)
  - manifest raw stream framing (`*-MAN-WA-000*`)
  - E2E derive expected-bytes (`*-E2E-WA-*`)
  - UTF-8 sorting traps (`*-UTF8-WA-*`)
  - mixed manifest sequences (`*-MAN-WA-01**` / `*-MAN-WA-02**`)
- Added ADR for contract change: `adr/conformance/0001-wave-a-byte-level-ops.md`.
- Updated human and LLM docs with Wave A guidance and invariant mappings.
- Protocol semantics unchanged (frozen v0.1 core preserved).

## [0.1.1] - 2026-02-20
- Audit hardening release for conformance and frozen-core clarity.
- ManifestRecord schema tightened: `op` is strict (`put|del`), with required/forbidden field shape enforced.
- NES/E2E profile updated to include explicit manifest op-shape MUST + deterministic rejection code `GRAIN_ERR_MANIFEST_OP`.
- Replaced placeholder vectors with concrete vectors across encoding/COSE/E2E/ledger/manifest.
- Added new manifest negative vectors:
  - `NEG-MAN-030` (CAP_CHASH_CONFLICT filtering)
  - `NEG-MAN-040` (manifest op-shape mismatch rejection)
- Conformance contract aligned on diagnostic codes (`NONCE_PROFILE_MISMATCH` naming consistency).
- Tooling and CI strengthened:
  - op-specific vector validation
  - placeholder/illustrative text ban in vectors
  - stricter LLM-doc mapping checks
  - expanded spec drift anchors
  - `.DS_Store` fail-fast check in CI

## [0.1.0] - 2026-02-20
- Protocol v0.1 frozen core published (NES + CDDL + profiles).
- Conformance suite scaffold published (vectors structure + harness contract).
- Documentation for humans and LLM-first indexes published.
- Governance, security, contribution, and change policies published.
