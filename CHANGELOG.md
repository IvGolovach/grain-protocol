# Changelog

This project follows a protocol-frozen posture: v0.1 core invariants do not change.

## [Unreleased]
- No entries yet.

## [0.4.0-rc1] - 2026-02-24
- TOR-04 / TOR-TS-IND-C02 (TypeScript full independent engine):
  - TypeScript runner upgraded to full strict operation coverage.
  - Added full profile execution and divergence/property scripts.
  - Full strict parity reached against Rust on full suite.
- TOR-CERT-D01 (interop certification and claim gate):
  - Added formal claim/scope/freeze documents:
    - `spec/INTEROP-v0.1.md`
    - `spec/FREEZE-CONFIRMATION-v0.1.md`
    - `spec/SCOPE-v0.1.md`
  - Added certification workflow and evidence artifacts pipeline.
- TOR-GH-CLEAN-A01 + TOR-GH-DEPS-A02 + TOR-DEPS-STRICT-FINAL:
  - Established strict autonomous GitHub operations lane.
  - Dependabot lane is fail-closed and workflow-safe (`workflow_run` model, no fallback token path).
  - Added branch-protection drift checks and repository hygiene guards.
- TOR-RC-DISCIPLINE-A01:
  - Added RC governance artifacts:
    - `spec/RC-POLICY.md`
    - `spec/INTEROP-CLAIM.md`
    - `spec/rc/**`
- TOR-DOC-A01 (onboarding/doc hardening):
  - Added runnable onboarding flow and deterministic quickstart checks.
  - Added domain-neutral architecture docs and clarified entry paths.
  - Rewrote LLM docs into guided handoff style and expanded mapping checks.
- TOR-SDK-A01 (universal primitives SDK layer):
  - Added TypeScript SDK package: `core/ts/grain-sdk`.
  - Added strict SDK runner path for vector execution via SDK boundary.
  - Added SDK invariants suite and integrated SDK checks into required CI context (`ts-full`).
  - Added SDK docs (human + LLM) and ADR (`adr/sdk/0001-sdk-universal-primitives-layer.md`).
- Protocol boundary: frozen-core semantics unchanged.

## [0.3.1] - 2026-02-21
- Fixed `tools/github/apply_branch_protection.sh`:
  - branch protection API payload now sent as typed JSON via `--input`
  - resolves GitHub API `422` caused by stringified booleans with `-f`
- Fixed CI/release run invocation for `tools/ci/run_runner_suite.py`:
  - CI now invokes `core/rust/target/debug/grain-runner` directly for suite runs (removes Cargo `--` separator ambiguity).
  - Added explicit `cargo build -p grain-runner` step before suite execution in CI and release workflow.
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
