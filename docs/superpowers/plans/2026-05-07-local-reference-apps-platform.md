# Local Reference Apps Platform Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the no-paid-Apple-account path from the existing Grain SDK platform into runnable local reference apps, device abstractions, certification checks, and developer-facing quickstarts.

**Architecture:** Keep Rust Core and generated SDKs as the protocol truth. iOS, Android, and Web examples must stay thin: they own platform input, local persistence, and display state, while Grain SDK owns trust verification, accept/idempotency, diagnostics, snapshot format, and export. Public examples must be source-level, locally runnable, and free of signing secrets, registry credentials, hidden trust lookup, secret logging, or app-store publication claims.

**Tech Stack:** Rust Core, Swift Package Manager/SwiftUI, Kotlin/Gradle, WASM/Node, Python CI guards, shell verification scripts, GitHub Actions.

---

## Current Repo State

- Base branch: `origin/main`
- Base release: `repo-v0.4.3`
- Base SHA at plan creation: `d648457dc64a803cf8dd49d8b3038376caad331b`
- Existing foundations:
  - `examples/ios-reference-app`
  - `examples/ios-scanner`
  - `examples/android-reference-app`
  - `examples/wasm-scanner`
  - `templates/ios-starter`
  - `templates/android-starter`
  - `templates/web-wasm-starter`
  - `scripts/sdk/check_ios_reference_app.sh`
  - `scripts/sdk/check_android_reference_app.sh`
  - `scripts/sdk/check_registry_dry_runs.sh`
  - `scripts/sdk/certify_external_client.sh`
- Boundary:
  - No paid Apple Developer Program is required for this plan.
  - No TestFlight, App Store, Ad Hoc distribution, npm publish, or Maven Central publish.
  - Local iPhone testing is documented as Xcode + ordinary Apple ID + automatic signing.
  - CI/local checks validate source packages and simulator-free smoke paths where Xcode is unavailable.

## Implementation Phases

### Phase 1: iOS Reference App Flow

**Files:**
- Modify: `examples/ios-reference-app/Sources/GrainIOSReferenceAppCore/GrainReferenceScannerRootView.swift`
- Modify: `examples/ios-reference-app/Sources/GrainIOSReferenceAppCore/GrainReferenceScannerSession.swift`
- Modify: `examples/ios-scanner/Sources/GrainIOSScanner/ScannerShellModel.swift`
- Modify: `examples/ios-scanner/Sources/GrainIOSScanner/ScannerView.swift`
- Modify: `examples/ios-reference-app/Sources/GrainIOSReferenceAppSmoke/main.swift`
- Modify: `examples/ios-reference-app/README.md`
- Modify: `scripts/sdk/check_ios_reference_app.sh`

**Acceptance:**
- User can run the source-level app locally without paid Apple Developer Program.
- The UI has a clear scan/paste -> preview -> accept -> saved -> export/debug path.
- Accept remains disabled until a verified preview exists.
- Demo QR and manual paste both use the same public SDK handoff.
- Export/debug shows counts and diagnostics only; no snapshot/trust/secret material is displayed or logged.
- Smoke covers boot, local identity, demo preview, accept, persist, restore, idempotent accept, and export.

### Phase 2: Android Reference App Parity

**Files:**
- Modify: `examples/android-reference-app/src/main/kotlin/dev/grain/examples/androidreferenceapp/GrainReferenceScannerSession.kt`
- Modify: `examples/android-reference-app/src/main/kotlin/dev/grain/examples/androidreferenceapp/GrainAndroidReferenceApp.kt`
- Modify: `examples/android-reference-app/README.md`
- Modify: `scripts/sdk/check_android_reference_app.sh`

**Acceptance:**
- Android reference app exposes the same logical flow as iOS.
- It can run as a local Gradle/JVM smoke without Play Console or Android signing.
- It rejects raw protocol APIs, hidden trust lookup, and secret logging.
- Demo, accept, persisted state, restored state, and export are all checked.

### Phase 3: Device Abstraction Contract

**Files:**
- Create: `sdk/device/device_adapter_v1.schema.json`
- Create: `sdk/device/README.md`
- Create: `tools/ci/check_device_adapter_contract.py`
- Create: `tools/ci/test_check_device_adapter_contract.py`
- Modify: `tools/ci/check_public_sdk_api.py`
- Modify: `sdk/api/public-sdk-v0.1.json`

**Acceptance:**
- Contract names platform edges: scan input, device capabilities, secure local store, export sink, diagnostic sink, trust provider.
- Contract explicitly avoids accounts, network trust discovery, platform stores, and publication credentials.
- Public SDK API snapshot references the device-adapter contract.
- Unit tests reject missing capabilities, hidden network trust, secret export fields, and platform-store-only assumptions.

### Phase 4: Local Publication and Dry-Run Hardening

**Files:**
- Modify: `scripts/sdk/check_registry_dry_runs.sh`
- Modify: `tools/ci/check_registry_dry_run_metadata.py`
- Modify: `tools/ci/test_check_registry_dry_run_metadata.py`
- Modify: `scripts/sdk/package_client_sdks.sh`
- Modify: `tools/ci/check_sdk_release_package.py`
- Modify: `tools/ci/test_check_sdk_release_package.py`

**Acceptance:**
- SwiftPM, npm pack, and Maven-local/dry-run metadata remain credential-free.
- Release package exposes source artifacts for iOS, Android, WASM, workflow contracts, device contracts, and starter/reference examples.
- Checks fail if metadata claims App Store, TestFlight, Play Console, npm publish, Maven Central publish, or required external credentials.

### Phase 5: Developer Certification Flow

**Files:**
- Modify: `scripts/sdk/certify_external_client.sh`
- Modify: `tools/ci/check_external_client_certification.py`
- Modify: `tools/ci/test_check_external_client_certification.py`
- Modify: `tools/ci/check_external_consumer_templates.py`
- Modify: `tools/ci/test_check_external_consumer_templates.py`

**Acceptance:**
- Certification report includes iOS reference app, Android reference app, starter templates, device contract, no-secret telemetry, trust governance, public API, and release consumer checks.
- Report distinguishes local source validation from real registry/app-store publication.
- It remains runnable without paid Apple account or external registry credentials.

### Phase 6: CI Integration

**Files:**
- Modify: `.github/actions/python-policy-checks/action.yml`
- Modify: `.github/workflows/ci.yml`
- Modify: `scripts/sdk/verify_all_sdks.sh`

**Acceptance:**
- New Python guards are part of shared policy checks.
- SDK platform CI validates reference apps, starter templates, local dry-runs, device contract, and external-client certification in strict mode.
- CI does not require App Store, TestFlight, npm publish, Maven Central, Play Console, or secrets for PR validation.

### Phase 7: Developer Experience Docs

**Files:**
- Modify: `README.md`
- Modify: `examples/README.md`
- Modify: `docs/human/sdk/start-here.md`
- Modify: `docs/human/sdk/overview.md`
- Create: `docs/human/sdk/quickstart-ios-reference-app.md`
- Create: `docs/human/sdk/quickstart-android-reference-app.md`
- Create: `docs/human/sdk/device-abstraction.md`
- Create: `docs/human/sdk/local-publication.md`
- Create: `docs/human/sdk/certification.md`

**Acceptance:**
- Docs state plainly what works without paid accounts.
- Docs separate local iPhone testing from TestFlight/App Store distribution.
- New developer path is one happy path: clone, run checks, open iOS reference app, paste/demo QR, preview, accept, saved list, export/debug.
- Android path mirrors iOS without Play Console.
- Publication docs clearly mark real registry publication as later work.

## Validation Plan

- [x] `git status --short --untracked-files=all`
- [x] `python3 -m unittest tools.ci.test_check_device_adapter_contract tools.ci.test_check_public_sdk_api tools.ci.test_check_registry_dry_run_metadata tools.ci.test_check_sdk_release_package tools.ci.test_check_external_client_certification tools.ci.test_check_external_consumer_templates`
- [x] `python3 tools/ci/check_device_adapter_contract.py`
- [x] `python3 tools/ci/check_public_sdk_api.py`
- [x] `scripts/sdk/check_ios_reference_app.sh`
- [x] `scripts/sdk/check_android_reference_app.sh`
- [x] `PATH="$HOME/.cargo/bin:$PATH" scripts/sdk/check_kotlin_package.sh`
- [x] `PATH="$HOME/.cargo/bin:$PATH" scripts/sdk/check_scanner_examples.sh`
- [x] `scripts/sdk/check_registry_dry_runs.sh --out-dir artifacts/sdk-registry-dry-runs-local-reference-final`
- [x] `scripts/sdk/package_client_sdks.sh --out-dir artifacts/sdk-release-local-reference-final --skip-verify --allow-dirty`
- [x] `python3 tools/ci/check_external_consumer_templates.py --out-dir artifacts/sdk-release-local-reference-final`
- [x] `CLIENT_NAME=grain-local-reference-apps CLIENT_OWNER=grain-maintainers OUT_DIR=artifacts/external-client-certification-local-reference-final scripts/sdk/certify_external_client.sh`
- [x] `PATH="$HOME/.cargo/bin:$PATH" scripts/sdk/verify_all_sdks.sh --strict --out-dir artifacts/sdk-verify-local-reference-final-3`
- [x] `python3 tools/check_llm_docs.py`
- [x] `python3 tools/ci/check_docs_links.py`
- [x] `python3 tools/ci/check_docs_flow.py`
- [x] `python3 tools/ci/check_real_app_docs.py`
- [x] `python3 tools/ci/check_workflow_action_pinning.py`
- [x] `bash -n scripts/sdk/verify_all_sdks.sh && bash -n scripts/sdk/check_ios_reference_app.sh && bash -n scripts/sdk/check_android_reference_app.sh && bash -n scripts/sdk/check_registry_dry_runs.sh && bash -n scripts/sdk/certify_external_client.sh && bash -n scripts/sdk/package_client_sdks.sh`
- [x] `scripts/ledger/check`
- [x] `git fetch --no-tags origin main:refs/remotes/origin/main && scripts/ledger/check --history --base origin/main`
- [x] `git diff --check`
- [ ] `git diff --cached --check`

## Execution Notes

- 2026-05-07: Created a clean isolated worktree from `origin/main`.
- 2026-05-07: Used five workers for iOS, Android, device contract, publication/certification, and DX/CI slices.
- 2026-05-07: Corrected integration issues found during review:
  - device capabilities are explicit booleans instead of always-true constants, so future device edges can report missing capabilities honestly
  - iOS UI shows the saved scan list and has a refresh action
  - CI no longer re-runs certification after `verify_all_sdks.sh --strict`; it uploads the certification report produced by the strict SDK gate
  - Kotlin and scanner example checks now support Apple Silicon hosts with x86_64 JVMs by building and passing a JVM-matching Rust dylib

## PR Strategy

- Prefer one integrated PR because the reference apps, device contract, certification flow, and docs validate one product slice.
- Split only if CI/review shows a real need.
- Do not create separate PRs for cosmetic text or tiny guard additions.

## Deferred Until External Accounts Exist

- Apple Developer Program signing for distribution.
- TestFlight and App Store.
- Ad Hoc distribution to registered devices.
- Play Console.
- npm publish.
- Maven Central publish.
- Any registry or app-store credential handling.
