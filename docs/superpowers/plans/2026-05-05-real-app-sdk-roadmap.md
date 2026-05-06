# Real App SDK Roadmap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the current Grain protocol plus portable SDK foundation into a real end-to-end app path: issuer creates a signed Grain QR, platform SDKs scan and verify it, accepted records persist safely, and releases ship through auditable SDK artifacts.

**Architecture:** Keep protocol semantics in `core/rust/grain-core` and app-facing workflows in `core/rust/grain-client-core`. Add product slices above that boundary: release channel, issuer kit, trust anchor bundles, iOS vertical slice, Android parity, custody/sync hardening, and developer DX. Each slice must be independently reviewable, tested, merged, and reflected here before the next slice starts.

**Tech Stack:** Rust workspace, UniFFI-generated Swift/Kotlin bindings, SwiftPM, Gradle/Kotlin, WASM/Node, GitHub Actions, repo-native SDK workflow fixtures, source release metadata, SBOM, and evidence bundles.

---

## Execution Rules

- Work in isolated branches or worktrees; never edit `main` directly.
- Keep each PR to one logical slice unless a blocker forces an additional preparatory PR.
- Before each PR: inspect the actual diff, select the narrowest sufficient validation tier, run targeted local checks, run `git diff --check`, stage explicit paths only, commit with validation and rollback sections.
- After each PR: wait for required CI/review gates, fix actionable same-task feedback, merge only when gates pass, fast-forward local `main`, return to this plan, and update the execution log.
- Do not broaden protocol semantics unless a task explicitly requires it.
- Do not publish secrets, local environment files, generated junk, caches, or build artifacts.

## Roadmap Status

| Step | Slice | Status | Branch | PR | Merge commit | Local proof | Remote proof |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | SDK release channel | Merged | `codex/grain-real-app-roadmap` | #49 | `b42f91350449bbc3e776042913b397ccdba1c2a0` | `git diff --check`; `git diff --cached --check`; YAML parse; workflow pinning; docs checks; ledger checks; SDK package smoke | PR CI passed on `86555f5b169754c36f5fa7ef2d81847934ca8dd0`; post-merge main CI run `25413371566` passed |
| 2 | Issuer kit | Merged | `codex/issuer-kit-reference-step2` | #50 | `745dc3518d1a6f484735b82898413ebc2c9cff19` | `cargo test --locked --manifest-path core/rust/Cargo.toml -p grain-core -p grain-client-core -p grain-issuer-kit`; issuer CLI smoke; docs/guard checks; ledger checks | PR CI passed on `fe9b5c6979699d43597b7f0ba4a4024f118f45ec`; post-merge main CI run `25414079835` passed |
| 3 | Trust anchor bundle | Merged | `codex/trust-anchor-bundle-step3` | #51 | `adea8ad6e2eba3345730b72ad2befec8e949b01f` | `cargo test --locked --manifest-path core/rust/Cargo.toml -p grain-client-core`; Swift/WASM/Kotlin package checks; Android example compile; workflow/docs/guard checks; ledger checks; SDK package smoke | PR CI passed on `0cffac08870f03513e0c416c8e9108e1c4b8f906`; post-merge main CI run `25415348249` passed |
| 4 | Production iOS vertical slice | Merged | `codex/ios-scanner-vertical-slice-step4` | #52 | `c988c46649f629d806a7e19e39ff88e7af8a0095` | `cargo build --manifest-path core/rust/Cargo.toml -p grain-client-core`; iOS scanner smoke with scratch path; `scripts/sdk/check_swift_package.sh`; docs/LLM/no-network/trust-boundary/ledger checks | PR CI passed on `3d1054f41ad5e54dac2bf6a52303ea15fdeddc13`; post-merge main CI run `25416330443` passed |
| 5 | Android parity slice | Merged | `codex/android-parity-slice-step5` | #53 | `8b776f560c2143275e945a2a40f0a9735c938a09` | `cargo build --manifest-path core/rust/Cargo.toml -p grain-client-core`; Kotlin SDK/example `compileKotlin compileTestKotlin`; docs/LLM/no-network/trust-boundary/ledger checks | PR CI passed on `b3dc1193553b10634582446c0d4e376b09a20f52`; post-merge main CI run `25417312257` passed |
| 6 | Custody and sync hardening | Merged | `codex/custody-sync-hardening-step6` | #54 | `b2690ab202e742dd0d17b5e4e794a52c9b4cc112` | `cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core`; `scripts/sdk/check_generated_bindings.sh`; `scripts/sdk/check_swift_package.sh`; Kotlin SDK/example compile; WASM package check with rustup toolchain; docs/LLM/no-network/trust-boundary/secret-logging checks; ledger checks | PR CI passed on `484dc20b05709b74aa12560016b8fe66ef42d425`; post-merge main CI run `25418388459` passed |
| 7 | Developer DX closeout | Merged | `codex/developer-dx-closeout-step7` | #55 | `bfba4489ad8317955a32f499c429930d70086c23` | `scripts/sdk/doctor` warning-aware readiness check; docs/LLM/workflow guard checks; spec drift; diff/ledger checks | PR CI run `25419460588` passed on final SHA `56b74a7cdbce329e19b00dc9066181619aa82743`; Greptile requested twice with no actionable review threads; post-merge main CI run `25419781265` passed |

## Step 1: SDK Release Channel

**Goal:** Make SDK release artifacts first-class tagged release assets rather than only CI artifacts.

**Expected scope:**
- Release workflow attaches SDK source package artifacts, `manifest.json`, `SHA256SUMS`, and `sbom.spdx.json` to repo/protocol release entries when the strict SDK gate has proven the same commit.
- Release docs explain the SDK tag/release rule without claiming npm, Maven, Swift Package Index, Play Store, App Store, or production PWA publication.
- Metadata checker remains the authority for artifact cleanliness, same-commit source, strict verification, version matrix hash, checksums, and SBOM package coverage.

**Likely files:**
- `.github/workflows/release-evidence.yml`
- `docs/human/release-process.md`
- `docs/human/sdk/version-matrix.md`
- `sdk/README.md`
- `scripts/sdk/package_client_sdks.sh`
- `tools/ci/check_sdk_release_package.py`

**Validation target:**
- `python3 tools/ci/check_sdk_release_package.py` against a locally packaged artifact when platform prerequisites are available, otherwise targeted workflow/package checker tests plus mandatory GitHub CI.
- `python3 tools/check_llm_docs.py`
- `git diff --check`

## Step 2: Issuer Kit

**Goal:** Provide a reference issuer path that creates real signed Grain QR payloads for scanner apps and examples.

**Expected scope:**
- Add a repo-local issuer CLI/library that builds a deterministic sample payload, signs it under the narrow COSE profile, emits `GR1:` payload text, and writes or prints matching trust public material.
- Keep issuer key material generated or fixture-bound for tests; no private keys committed.
- Add positive and negative tests proving generated QR payloads scan through `grain-client-core` and reject under wrong trust.

**Likely files:**
- `core/rust/grain-core/src/cose.rs`
- `core/rust/grain-runner/src/*` or a new narrow issuer crate/tool under `core/rust`
- `examples/issuer-kit/*`
- `conformance` or `sdk/workflows` fixtures only if the workflow contract needs a stable generated fixture
- `docs/human/sdk/*`

**Validation target:**
- `cargo test --manifest-path core/rust/Cargo.toml -p grain-core -p grain-client-core`
- issuer-specific CLI smoke
- relevant SDK workflow fixture check
- `git diff --check`

## Step 3: Trust Anchor Bundle

**Goal:** Define and implement an app-owned trust anchor bundle that platform SDKs can load without hidden network discovery or fallback trust.

**Expected scope:**
- Add a versioned trust anchor bundle schema and parser/validator.
- Expose platform-wrapper-friendly APIs or adapter helpers that turn stable anchor IDs into explicit `trust_pub_b64`.
- Prove unknown, malformed, revoked, or blank anchors fail closed with deterministic `SDK_ERR_TRUST_ANCHOR_*` or bundle diagnostics.
- Preserve the SDK no-network policy.

**Likely files:**
- `core/rust/grain-client-core/src/platform/trust.rs`
- `sdk/workflows/fixtures/*`
- `sdk/swift/Sources/GrainClient/*`
- `sdk/kotlin/src/main/kotlin/dev/grain/*`
- `sdk/wasm/src/index.mjs`
- `tools/ci/check_sdk_trust_provider_boundary.py`
- docs under `docs/human/sdk` and `docs/llm`

**Validation target:**
- `cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core`
- `scripts/sdk/verify_all_sdks.sh` locally when prerequisites are available, otherwise targeted per-platform checks plus mandatory GitHub `sdk-platform`
- `python3 tools/ci/check_sdk_no_network.py`
- `python3 tools/ci/check_sdk_trust_provider_boundary.py`
- `git diff --check`

## Step 4: Production iOS Vertical Slice

**Goal:** Add a minimal real iOS app shell that scans, previews, accepts, persists, restores, and lists verified Grain scans through the public Swift SDK.

**Expected scope:**
- SwiftUI scanner shell with AVFoundation QR capture adapter, injected test adapter, explicit trust anchor bundle loading, Keychain-backed snapshot persistence, accept/list/export flow, and deterministic simulator-friendly smoke path.
- Do not put protocol semantics into app UI.
- Keep app store signing, TestFlight, and release distribution out of scope unless a future PR explicitly adds credentials and release policy.

**Likely files:**
- `examples/ios-scanner/*`
- `sdk/swift/Sources/GrainClientIOSAdapters/*`
- `scripts/sdk/check_scanner_examples.sh`
- Swift package or example package manifests
- docs under `examples/ios-scanner` and `docs/human/sdk`

**Validation target:**
- `scripts/sdk/check_swift_package.sh`
- `scripts/sdk/check_scanner_examples.sh`
- targeted Swift smoke executable
- mandatory GitHub `sdk-platform`
- `git diff --check`

## Step 5: Android Parity Slice

**Goal:** Add Android-facing parity for the real scanner path without rewriting workflow semantics.

**Expected scope:**
- CameraX-style scanner adapter, trust anchor bundle loading, Keystore-backed cipher implementation boundary, snapshot persistence, accept/list/export flow, and JVM/device-friendly smoke tests.
- Keep Play Store packaging out of scope unless a future PR explicitly adds release credentials and policy.

**Likely files:**
- `examples/android-scanner/*`
- `sdk/kotlin/src/main/kotlin/dev/grain/android/*`
- `sdk/kotlin/src/test/kotlin/dev/grain/android/*`
- `scripts/sdk/check_kotlin_package.sh`
- `scripts/sdk/check_scanner_examples.sh`
- docs under `examples/android-scanner` and `docs/human/sdk`

**Validation target:**
- `scripts/sdk/check_kotlin_package.sh`
- `scripts/sdk/check_scanner_examples.sh`
- mandatory GitHub `sdk-platform`
- `git diff --check`

## Step 6: Custody And Sync Hardening

**Goal:** Move identity, pairing, and sync from portable bundle semantics toward production custody policy for phones, glasses, robots, and future secure devices.

**Expected scope:**
- Define secure-device adapter contracts for Keychain, Keystore, Secure Enclave, robot TPM/HSM, or equivalent app-managed custody.
- Separate portable backup/pairing bundles from device-bound custody claims.
- Add redaction/logging guards around `snapshotB64`, identity bundles, sync bundles, pairing envelopes, trust material, and generated diagnostics.
- Add replay/idempotency and conflict tests for custody/sync flows.

**Likely files:**
- `core/rust/grain-client-core/src/identity.rs`
- `core/rust/grain-client-core/src/pairing.rs`
- `core/rust/grain-client-core/src/sync.rs`
- platform adapter packs under `sdk/swift`, `sdk/kotlin`, `sdk/wasm`
- `docs/human/rationale/TOR-PAIRING-A01.md`
- `docs/llm/SDK_EDGE_CASES.md`
- `tools/ci/*secret*` or scanner guard scripts if needed

**Validation target:**
- `cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core`
- per-platform SDK checks touched by the adapter changes
- no-network/trust-boundary/secret-logging guards
- `git diff --check`

## Step 7: Developer DX Closeout

**Goal:** Give future app developers one clean path from release tag to working scanner flow.

**Expected scope:**
- A concise cross-platform quickstart for: install or unpack SDK release, load trust bundle, scan issuer QR, preview, accept, persist, restore, export.
- Keep docs aligned with actual release/package boundaries; do not claim registry publication or store distribution until implemented.
- Add a small command or doctor check that reports SDK release/channel readiness.
- Close the plan with final proof and residual risks.

**Likely files:**
- `README.md`
- `sdk/README.md`
- `docs/human/sdk/start-here.md`
- `docs/human/sdk/minimal-app-example.md`
- `docs/human/sdk/portable-client-sdk.md`
- `docs/human/maintainer-start-here.md`
- `scripts/doctor` or a focused SDK readiness script if warranted

**Validation target:**
- `python3 tools/ci/check_docs_links.py`
- `python3 tools/ci/check_docs_flow.py`
- `python3 tools/check_llm_docs.py`
- targeted script check if a readiness command is added
- `git diff --check`

## Execution Log

- 2026-05-05: Plan created on branch `codex/grain-real-app-roadmap` from `origin/main` at `d9bd721e86b04fe067398746f051f0dda508d056`.
- 2026-05-05: Step 1 started. Release evidence workflow is being updated to run the strict platform SDK gate before attaching same-commit SDK source package assets to tagged GitHub releases.
- 2026-05-05: Step 1 merged as PR #49. Required PR CI and post-merge `main` CI passed; Greptile was requested and did not return a review before merge readiness.
- 2026-05-05: Step 2 started on `codex/issuer-kit-reference-step2` from `origin/main` at `b42f91350449bbc3e776042913b397ccdba1c2a0`.
- 2026-05-05: Step 2 merged as PR #50. Required PR CI, `sdk-platform`, `evidence-bundle`, and post-merge `main` CI passed; Greptile was requested and did not return a review before merge readiness.
- 2026-05-05: Step 3 started on `codex/trust-anchor-bundle-step3` from `origin/main` at `745dc3518d1a6f484735b82898413ebc2c9cff19`.
- 2026-05-05: Step 3 merged as PR #51. Required PR CI and post-merge `main` CI passed after the Android scanner example received its missing runtime Jackson dependency; Greptile was requested and did not return a review before merge readiness.
- 2026-05-05: Step 4 started on `codex/ios-scanner-vertical-slice-step4` from `origin/main` at `adea8ad6e2eba3345730b72ad2befec8e949b01f`.
- 2026-05-05: Step 4 opened as PR #52 after targeted local iOS scanner, Swift package, docs, no-network, trust-boundary, diff, and ledger checks passed. Full scanner-example proof was delegated to required GitHub `sdk-platform` because the local JVM architecture blocks the Android lane before repo checks.
- 2026-05-05: Step 4 merged as PR #52. Required PR CI passed on `3d1054f41ad5e54dac2bf6a52303ea15fdeddc13`, Greptile was requested and produced no actionable review threads before merge, and post-merge `main` CI run `25416330443` passed including `sdk-platform` and `evidence-bundle`.
- 2026-05-05: Step 5 started on `codex/android-parity-slice-step5` from `origin/main` at `c988c46649f629d806a7e19e39ff88e7af8a0095`.
- 2026-05-05: Step 5 implemented locally. Kotlin SDK and Android scanner sources compile, Rust client-core builds, docs/LLM/no-network/trust-boundary/ledger checks pass, and required full Android smoke proof is pending GitHub `sdk-platform` because local Java is x86_64 on an arm64 host.
- 2026-05-05: Step 5 merged as PR #53. Required PR CI passed on `b3dc1193553b10634582446c0d4e376b09a20f52` after a same-task JSON pointer test fix, Greptile was requested and produced no actionable review threads before merge, and post-merge `main` CI run `25417312257` passed including `sdk-platform` and `evidence-bundle`.
- 2026-05-05: Step 6 started on `codex/custody-sync-hardening-step6` from `origin/main` at `8b776f560c2143275e945a2a40f0a9735c938a09`.
- 2026-05-05: Step 6 implemented locally. Rust pairing/sync custody metadata and redaction tests pass, Swift package and WASM package checks pass, Kotlin SDK and Android scanner sources compile, docs/LLM/no-network/trust-boundary/secret-logging checks pass, and required full Kotlin/scanner runtime proof remains delegated to GitHub `sdk-platform` because local Java is x86_64 on an arm64 host.
- 2026-05-05: Step 6 opened as PR #54. Greptile was requested, required GitHub CI/review gates are pending, and the branch will not merge until final-SHA gates pass.
- 2026-05-05: Step 6 merged as PR #54. Required PR CI passed on `484dc20b05709b74aa12560016b8fe66ef42d425`, Greptile was requested and produced no actionable review threads before merge, and post-merge `main` CI run `25418388459` passed including `sdk-platform` and `evidence-bundle`.
- 2026-05-05: Step 7 started on `codex/developer-dx-closeout-step7` from `origin/main` at `b2690ab202e742dd0d17b5e4e794a52c9b4cc112`.
- 2026-05-05: Step 7 implemented locally. The SDK DX closeout adds a scanner quickstart, lightweight SDK doctor, broader docs/LLM/workflow guards, and updated example entrypoints; local `scripts/sdk/doctor`, docs checks, workflow fixture checks, spec drift check, and `git diff --check` pass. PR CI/review is pending.
- 2026-05-05: Step 7 opened as PR #55. Greptile/review and required GitHub CI are pending; the branch will not merge until final-SHA gates pass.
- 2026-05-05: Step 7 same-task review fix is being applied before merge. The SDK doctor now reports `WARN` instead of a final `PASS` when local SDK readiness gaps remain, and the scanner quickstart now separates deterministic fixture smokes from the generated QR/trust handoff path.
- 2026-05-05: Step 7 merged as PR #55. Required PR CI passed on final SHA `56b74a7cdbce329e19b00dc9066181619aa82743`, Greptile was requested twice and produced no actionable review threads before merge, and post-merge `main` CI run `25419781265` passed including `sdk-platform` and `evidence-bundle`.
- 2026-05-05: All seven roadmap slices are merged and post-merge verified on `main`.
