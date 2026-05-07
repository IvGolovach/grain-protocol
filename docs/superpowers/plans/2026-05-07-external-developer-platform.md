# External Developer Platform Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move Grain from source-only internal SDK proof to an externally verifiable developer platform with starter apps, package dry-runs, API guards, custody checks, and certification tooling.

**Architecture:** Keep protocol semantics in `core/rust/*` and product workflow semantics in `core/rust/grain-client-core`. Add external-consumer proof, starter templates, API snapshots, registry dry-run packaging, custody/security guards, and developer docs above the existing SDK boundary. Do not add registry publishing, app-store publishing, or external-account dependencies in this plan.

**Tech Stack:** Rust workspace, UniFFI-generated Swift/Kotlin bindings, SwiftPM, Gradle/Kotlin, WASM/Node, Python CI tools, GitHub Actions, release assets, SDK workflow fixtures, source-only SDK handoff artifacts.

---

## Execution Rules

- Work from clean branch `codex/external-developer-platform` in an isolated worktree.
- Preserve the dirty primary Grain checkout; do not stage, reset, clean, stash, or overwrite it.
- Keep changes in a small number of logical PRs. Current implementation uses
  one external-developer-platform PR because the release package, CI gates,
  starter templates, certification command, and custody/security policy are one
  integrated handoff surface.
- Before each PR: inspect diff, run targeted local checks, `git diff --check`, ledger checks if required, stage explicit paths only, commit with validation/rollback proof.
- After each PR: wait for required CI/review gates, fix actionable feedback, merge only when gates pass, fast-forward local `main`, return here, and update status.
- Use TDD for new executable tools and guards: add failing tests first, verify failure, implement, verify pass.
- Do not claim npm, Maven Central, Swift Package Index, App Store, Play Store, PWA, glasses, robot, secure-element, or hardware certification.

## Roadmap Status

| Step | Slice | Status | Branch/PR | Proof |
| --- | --- | --- | --- | --- |
| 0 | Local artifact and worktree hygiene | Complete | `codex/external-developer-platform` | Plan file created; clean isolated worktree verified |
| 1 | Dirty branch inventory | Complete | Platform PR | `docs/superpowers/plans/2026-05-07-sdk-release-assets-inventory.md`; no destructive cleanup |
| 2 | External consumer harness | Implemented locally | Platform PR | Python tests plus release-asset smoke |
| 3 | API freeze v0.1 guard | Implemented locally | Platform PR | Snapshot check rejects drift |
| 4 | Compatibility matrix guard | Implemented locally | Platform PR | Same-SHA matrix check rejects mixed artifacts |
| 5 | Registry dry-run packaging | Implemented locally | Platform PR | SwiftPM/Maven/npm dry-run checks without publishing |
| 6 | iOS starter template | Implemented locally | Platform PR | Swift package/template smoke |
| 7 | Android starter template | Implemented locally | Platform PR | Gradle/Kotlin template smoke |
| 8 | Web/WASM starter template | Implemented locally | Platform PR | Node/WASM template smoke |
| 9 | Third-party certification command | Implemented locally | Platform PR | Runs workflow/no-network/trust/custody gates |
| 10 | No-secret telemetry guard | Implemented locally | Platform PR | Guard rejects unsafe telemetry/log fields |
| 11 | Trust governance hardening | Implemented locally | Platform PR | Schema/checksum/docs/tests for bundle governance |
| 12 | Custody adapter hardening | Implemented locally | Platform PR | Adapter contract docs/tests for Keychain/Keystore/IndexedDB/secure storage |
| 13 | Security review pass | Implemented locally | Platform PR | Threat-model doc plus automated doc/guard checks |
| 14 | Release train and final handoff | Implemented locally | Platform PR | Release train docs, final CI, release asset proof |

## Task 0: Local Artifact And Worktree Hygiene

**Files:**
- Create: `docs/superpowers/plans/2026-05-07-external-developer-platform.md`

- [x] Verify clean isolated worktree.
- [x] Create branch `codex/external-developer-platform`.
- [x] Save this implementation plan.
- [x] Update this file before opening the platform PR.
- [ ] Update this file after PR/merge/release promotion.

## Task 1: Dirty Branch Inventory

**Files:**
- Create: `docs/superpowers/plans/2026-05-07-sdk-release-assets-inventory.md`

- [x] Record current primary checkout branch, HEAD, and dirty paths.
- [x] Compare dirty paths against `origin/main`.
- [x] Classify each path as already merged, still useful, obsolete, or uncertain.
- [x] Do not mutate the primary checkout.
- [x] Include next-action recommendation for any still-useful path.

## Task 2: External Consumer Harness

**Files:**
- Create: `tools/ci/check_external_consumer_templates.py`
- Create: `tools/ci/test_check_external_consumer_templates.py`
- Modify: `.github/workflows/ci.yml`
- Modify: `docs/human/sdk/source-sdk-handoff.md`
- Modify: `sdk/README.md`

- [x] Write tests for a fake release asset directory that must pass when Swift/Kotlin/WASM/template inputs are same-SHA and outside the monorepo.
- [x] Verify the tests fail before implementation.
- [x] Implement the checker that extracts release/source artifacts into a temporary external layout and validates public consumer inputs.
- [x] Add CI invocation after existing SDK handoff checks.
- [x] Document the command and what it proves.

## Task 3: API Freeze v0.1 Guard

**Files:**
- Create: `sdk/api/public-sdk-v0.1.json`
- Create: `tools/ci/check_public_sdk_api.py`
- Create: `tools/ci/test_check_public_sdk_api.py`
- Modify: `.github/actions/python-policy-checks/action.yml`
- Modify: `docs/human/sdk/version-matrix.md`

- [x] Write tests proving unchanged API snapshots pass and missing/renamed stable symbols fail.
- [x] Verify tests fail before implementation.
- [x] Define the v0.1 stable method/diagnostic snapshot for Swift, Kotlin, WASM, and workflow contract.
- [x] Implement the guard.
- [x] Wire the guard into policy checks.
- [x] Document stable versus experimental surface.

## Task 4: Compatibility Matrix Guard

**Files:**
- Create: `tools/ci/check_sdk_compatibility_matrix.py`
- Create: `tools/ci/test_check_sdk_compatibility_matrix.py`
- Modify: `docs/human/sdk/version-matrix.md`
- Modify: `.github/actions/python-policy-checks/action.yml`

- [x] Write tests for same-SHA pass and mixed-SHA/version mismatch failure.
- [x] Verify tests fail before implementation.
- [x] Implement machine-readable matrix validation using existing manifest/version docs.
- [x] Wire it into policy checks.
- [x] Document that cross-version pairings require explicit matrix entries.

## Task 5: Registry Dry-Run Packaging

**Files:**
- Create: `scripts/sdk/check_registry_dry_runs.sh`
- Create: `tools/ci/check_registry_dry_run_metadata.py`
- Create: `tools/ci/test_check_registry_dry_run_metadata.py`
- Modify: `.github/workflows/ci.yml`
- Modify: `docs/human/sdk/distribution-roadmap.md`

- [x] Add tests for metadata that rejects real publication claims and accepts dry-run-only channels.
- [x] Verify tests fail before implementation.
- [x] Implement SwiftPM, Maven local-publish, and npm pack dry-run orchestration without registry credentials.
- [x] Add CI check where host prerequisites exist or mark unsupported local prerequisites explicitly.
- [x] Document dry-run outputs and non-publication boundary.

## Task 6: Starter Templates

**Files:**
- Create: `templates/ios-starter/*`
- Create: `templates/android-starter/*`
- Create: `templates/web-wasm-starter/*`
- Create: `scripts/sdk/check_starter_templates.sh`
- Modify: `.github/workflows/ci.yml`
- Modify: `docs/human/sdk/start-here.md`
- Modify: `docs/human/sdk/scan-quickstart.md`

- [x] Build iOS starter with scan/paste, local trust bundle, preview, accept, snapshot restore/list/export stubs over public Swift SDK.
- [x] Build Android starter with QR input, local trust bundle, preview, accept, Keystore-boundary snapshot storage stubs over public Kotlin SDK.
- [x] Build Web/WASM starter with paste/QR input, local trust bundle, preview, accept, IndexedDB snapshot storage over public WASM SDK.
- [x] Add template smoke script.
- [x] Document templates as starter code, not store-ready apps.

## Task 7: Third-Party Certification Command

**Files:**
- Create: `scripts/sdk/certify_external_client.sh`
- Create: `tools/ci/check_external_client_certification.py`
- Create: `tools/ci/test_check_external_client_certification.py`
- Modify: `sdk/README.md`
- Modify: `docs/human/sdk/source-sdk-handoff.md`

- [x] Write tests for certification manifest pass/fail.
- [x] Verify tests fail before implementation.
- [x] Implement certification command that runs workflow fixture, no-network, trust-provider, secret-logging, API, compatibility, and template checks.
- [x] Emit a concise local report for outside app teams.
- [x] Document how external app teams run it.

## Task 8: No-Secret Telemetry Guard

**Files:**
- Create: `sdk/workflows/contract/safe_diagnostic_event_v1.schema.json`
- Create: `tools/ci/check_no_secret_telemetry.py`
- Create: `tools/ci/test_check_no_secret_telemetry.py`
- Modify: `.github/actions/python-policy-checks/action.yml`
- Modify: `docs/human/sdk/custody-threat-model.md`
- Modify: `docs/llm/SDK_EDGE_CASES.md`

- [x] Write tests that reject `snapshotB64`, identity bundle, pairing envelope, sync bundle, COSE payload, and trust material in telemetry schemas/examples.
- [x] Verify tests fail before implementation.
- [x] Add safe diagnostic event schema.
- [x] Implement repository guard for unsafe telemetry/log surfaces.
- [x] Document safe event shape.

## Task 9: Trust Governance And Custody Hardening

**Files:**
- Modify: `sdk/trust/trust_anchor_bundle_v1.schema.json`
- Modify: `sdk/trust/README.md`
- Create: `tools/ci/check_trust_bundle_governance.py`
- Create: `tools/ci/test_check_trust_bundle_governance.py`
- Create: `sdk/custody/secure_storage_adapter_v1.md`
- Modify: `docs/human/sdk/custody-threat-model.md`

- [x] Write tests for trust bundle checksum/signing metadata requirements and fail-closed anchor states.
- [x] Verify tests fail before implementation.
- [x] Add governance metadata to trust bundle schema/docs without requiring network lookup.
- [x] Add secure storage adapter contract for Keychain, Keystore, IndexedDB, and robot/TPM/HSM style adapters.
- [x] Wire trust governance guard into policy checks.

## Task 10: Security Review And Release Train

**Files:**
- Create: `docs/human/sdk/security-review.md`
- Create: `docs/human/sdk/release-train.md`
- Create: `tools/ci/check_release_train_docs.py`
- Create: `tools/ci/test_check_release_train_docs.py`
- Modify: `docs/human/sdk/start-here.md`
- Modify: `README.md`

- [x] Document replay, trust injection, snapshot leakage, pairing misuse, bad logs, backup leakage, and app-shell divergence risks.
- [x] Document separate protocol/core, SDK source, starter-template, registry-ready, and app release trains.
- [x] Add doc guard that rejects registry/store/hardware claims without release evidence language.
- [x] Update start-here/front-door docs.
- [x] Prepare final release promotion after all PRs land and remote gates pass.

## Final Validation Target

- `git diff --check`
- `scripts/ledger/check`
- `scripts/ledger/check --history --base origin/main`
- `python3 -m unittest` for new CI tooling tests
- `python3 tools/ci/check_docs_links.py`
- `python3 tools/ci/check_docs_flow.py`
- `python3 tools/check_llm_docs.py`
- `python3 tools/check_spec_drift.py`
- `scripts/sdk/doctor`
- targeted SDK/template/certification checks added in this plan
- mandatory GitHub CI before merge
- final release asset checks if a release tag is created
