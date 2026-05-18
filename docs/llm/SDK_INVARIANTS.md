# SDK_INVARIANTS

Hi teammate LLM. These are SDK-level MUST invariants for TOR-SDK-A01.

- SDK-INV-0001: strict-by-default execution for public SDK APIs.
  Tests: `core/ts/grain-sdk/scripts/test-sdk-invariants.ts` (`SDK-INV-0001 strict-by-default reducer`)
  Modules: `core/ts/grain-sdk/src/sdk.ts`, `core/ts/grain-sdk/src/events.ts`

- SDK-INV-0002: unauthorized append attempts MUST reject at SDK boundary.
  Tests: `core/ts/grain-sdk/scripts/test-sdk-invariants.ts` (`SDK-INV-0002 unauthorized append guard`)
  Modules: `core/ts/grain-sdk/src/identity.ts`, `core/ts/grain-sdk/src/events.ts`

- SDK-INV-0003: cap_id generation MUST be CSPRNG random; no deterministic derivation from plaintext identifiers.
  Tests: `core/ts/grain-sdk/scripts/test-sdk-invariants.ts` (`SDK-INV-0003 cap_id randomness`)
  Modules: `core/ts/grain-sdk/src/e2e.ts`, `core/ts/grain-sdk/src/utils.ts`

- SDK-INV-0004: deterministic nonce lifecycle MUST follow core profile; decrypt mismatch MUST reject.
  Tests: `core/ts/grain-sdk/scripts/test-sdk-invariants.ts` (`SDK-INV-0004 deterministic nonce lifecycle`)
  Modules: `core/ts/grain-sdk/src/e2e.ts`

- SDK-INV-0005: manifest resolution MUST stay deterministic and surface tombstone/not-found/found outcomes explicitly.
  Tests: `core/ts/grain-sdk/scripts/test-sdk-invariants.ts` (`SDK-INV-0005 manifest deterministic resolution`)
  Modules: `core/ts/grain-sdk/src/manifest.ts`

- SDK-INV-0006: cap_id single-assignment MUST be enforced at blob-store boundary.
  Tests: `core/ts/grain-sdk/scripts/test-sdk-invariants.ts` (`SDK-INV-0006 cap_id single-assignment`)
  Modules: `core/ts/grain-sdk/src/memory-store.ts`

- SDK-INV-0007: canonicalization toolkit MUST reject non-canonical bytes.
  Tests: `core/ts/grain-sdk/scripts/test-sdk-invariants.ts` (`SDK-INV-0007 canonicalization guard`)
  Modules: `core/ts/grain-sdk/src/codec.ts`

- SDK-INV-0008: set-array builder MUST reject duplicates and enforce byte-level canonical set semantics.
  Tests: `core/ts/grain-sdk/scripts/test-sdk-invariants.ts` (`SDK-INV-0008 set-array builder strictness`)
  Modules: `core/ts/grain-sdk/src/primitives.ts`

- SDK-INV-0009: error explain contract MUST return deterministic category + NES/vector references for diagnostics.
  Tests: `core/ts/grain-sdk/scripts/test-sdk-invariants.ts` (`SDK-INV-0009 deterministic error model`)
  Modules: `core/ts/grain-sdk/src/errors.ts`, `core/ts/grain-sdk/src/codec.ts`

- SDK-INV-0010: transport decode and verify MUST stay separate; verify requires explicit trust, enforces strict `ServingOffer` payload/profile validation, and bundle import/export MUST be deterministic + schema-checked + strict-base64-validated on imported binary fields.
  Tests: `core/ts/grain-sdk/scripts/test-sdk-invariants.ts` (`SDK-INV-0010 transport bundle determinism`, `SDK-INV-0010 transport verify requires explicit trust`, `SDK-NEG-0029 verifyGR1 rejects ServingOffer issuer_kid mismatch`)
  Modules: `core/ts/grain-sdk/src/transport.ts`

- SDK-INV-0011: raw ledger CBOR-seq export MUST be deterministic and parseable as canonical CBOR sequence.
  Tests: `core/ts/grain-sdk/scripts/test-sdk-invariants.ts` (`SDK-INV-0011 raw CBOR-seq export determinism`)
  Modules: `core/ts/grain-sdk/src/events.ts`

- SDK-INV-0012: public device lifecycle APIs MUST keep bundle authorization state synchronized with persisted grant/revoke ledger events.
  Tests: `core/ts/grain-sdk/scripts/test-sdk-invariants.ts` (`SDK-INV-0012 identity lifecycle stays synced with ledger`)
  Modules: `core/ts/grain-sdk/src/identity.ts`, `core/ts/grain-sdk/src/events.ts`

- SDK-INV-0013: public multi-step SDK mutations MUST roll back on failure instead of leaving partial persisted state.
  Tests: `core/ts/grain-sdk/scripts/test-sdk-invariants.ts` (`SDK-INV-0013 identity import rollback`, `SDK-INV-0013 correct rollback`)
  Modules: `core/ts/grain-sdk/src/store.ts`, `core/ts/grain-sdk/src/memory-store.ts`, `core/ts/grain-sdk/src/identity.ts`, `core/ts/grain-sdk/src/events.ts`, `core/ts/grain-sdk/src/manifest.ts`

- SDK-INV-0014: public import surfaces MUST reject non-standard base64 on binary fields before mutation or verification.
  Tests: `core/ts/grain-sdk/scripts/test-sdk-invariants.ts` (`SDK-NEG-0005 identity bundle base64 validation`, `SDK-NEG-0007 transport bundle base64 validation`, `SDK-NEG-0009 verifyGR1 rejects malformed trust bytes`)
  Modules: `core/ts/grain-sdk/src/identity.ts`, `core/ts/grain-sdk/src/transport.ts`, `core/ts/grain-sdk/src/utils.ts`

- SDK-INV-0015: portable client scan preview MUST preserve explicit trust boundaries across generated platform SDKs.
  Tests: `core/rust/grain-client-core/tests/scan_preview.rs`
  Modules: `core/rust/grain-client-core/src/scan.rs`, `core/rust/grain-client-core/src/types.rs`, `core/rust/grain-client-core/src/trust.rs`, `core/rust/grain-client-core/src/diag.rs`, `core/rust/grain-core/src/qr.rs`, `core/rust/grain-core/src/cose.rs`

- SDK-INV-0016: portable client scan accept preparation MUST require explicit verified trust, derive a deterministic `scan-sha256:<hex>` ID from verified COSE bytes, and perform no storage mutation.
  Tests: `core/rust/grain-client-core/tests/scan_accept_prepare.rs`
  Modules: `core/rust/grain-client-core/src/scan.rs`, `core/rust/grain-client-core/src/types.rs`, `core/rust/grain-client-core/src/trust.rs`, `core/rust/grain-client-core/src/diag.rs`, `core/rust/grain-core/src/qr.rs`, `core/rust/grain-core/src/cose.rs`

- SDK-INV-0017: portable client scan accept MUST persist verified scans only inside an atomic client-store boundary; rejected scans MUST write nothing, duplicate scans MUST be idempotent, failed atomic mutations MUST roll back, and nested atomic mutations MUST reject.
  Tests: `core/rust/grain-client-core/tests/scan_accept.rs`, `core/rust/grain-client-core/tests/store_atomic.rs`, `core/rust/grain-client-core/tests/client_workflow_fixtures.rs`
  Modules: `core/rust/grain-client-core/src/scan.rs`, `core/rust/grain-client-core/src/store.rs`, `core/rust/grain-client-core/src/memory_store.rs`, `core/rust/grain-client-core/src/types.rs`, `core/rust/grain-client-core/src/diag.rs`

- SDK-INV-0018: portable platform adapters MUST preserve storage/trust contracts before generated SDKs bind them: deterministic accepted-scan ordering, idempotent re-put, rollback at the repository boundary, no hidden trust fallback, no network trust lookup in Rust core, and owned FFI DTO values only.
  Tests: `core/rust/grain-client-core/tests/storage_contract.rs`, `core/rust/grain-client-core/tests/trust_adapter_contract.rs`, `core/rust/grain-client-core/tests/platform_scan_accept.rs`
  Modules: `core/rust/grain-client-core/src/platform/storage.rs`, `core/rust/grain-client-core/src/platform/trust.rs`, `core/rust/grain-client-core/src/ffi_types.rs`, `core/rust/grain-client-core/src/store.rs`, `core/rust/grain-client-core/src/diag.rs`

- SDK-INV-0018a: generated platform SDKs MUST persist client state through an opaque versioned store snapshot bridge rather than raw store mutation APIs; snapshot restore MUST reject malformed or unsupported payloads, including forged lifecycle events, without mutating existing state.
  Tests: `core/rust/grain-client-core/tests/storage_contract.rs`, `scripts/sdk/check_swift_package.sh`, `scripts/sdk/check_kotlin_package.sh`, `scripts/sdk/check_wasm_package.sh`
  Modules: `core/rust/grain-client-core/src/memory_store.rs`, `core/rust/grain-client-core/src/types.rs`, `core/rust/grain-client-core/src/ffi_types.rs`, `core/rust/grain-client-core/src/binding_api.rs`, `core/rust/grain-client-core/src/grain_client_core.udl`, `core/rust/grain-client-wasm/src/lib.rs`, `sdk/swift/Sources/GrainClient/GrainClient.swift`, `sdk/kotlin/src/main/kotlin/dev/grain/GrainClient.kt`, `sdk/wasm/src/index.mjs`

- SDK-INV-0018b: generated platform SDKs MUST expose production trust-provider surfaces that take explicit trust anchor IDs, fail closed for missing/unknown anchors, and never perform hidden fallback trust or network trust lookup.
  Tests: `core/rust/grain-client-core/tests/trust_adapter_contract.rs`, `sdk/workflows/fixtures/scan-preview/SDK-WF-SCAN-PREVIEW-0006.json`, `sdk/workflows/fixtures/scan-preview/SDK-WF-SCAN-PREVIEW-0007.json`, `sdk/workflows/fixtures/scan-accept/SDK-WF-SCAN-ACCEPT-0004.json`, `sdk/workflows/fixtures/scan-accept/SDK-WF-SCAN-ACCEPT-0005.json`, `scripts/sdk/check_swift_package.sh`, `scripts/sdk/check_kotlin_package.sh`, `scripts/sdk/check_wasm_package.sh`, `tools/ci/check_sdk_trust_provider_boundary.py`
  Modules: `core/rust/grain-client-core/src/platform/trust.rs`, `sdk/swift/Sources/GrainClient/GrainClient.swift`, `sdk/kotlin/src/main/kotlin/dev/grain/GrainClient.kt`, `sdk/wasm/src/index.mjs`

- SDK-INV-0018c: generated platform SDKs MUST load app-owned trust anchor bundles from local JSON only, reject unsupported/ambiguous/malformed bundles before trust resolution, and preserve the same fail-closed trust-provider behavior for unknown anchors.
  Tests: `core/rust/grain-client-core/tests/trust_adapter_contract.rs`, `core/rust/grain-client-core/tests/client_workflow_fixtures.rs`, `sdk/workflows/fixtures/scan-preview/SDK-WF-SCAN-PREVIEW-0006.json`, `sdk/workflows/fixtures/scan-preview/SDK-WF-SCAN-PREVIEW-0007.json`, `sdk/workflows/fixtures/scan-accept/SDK-WF-SCAN-ACCEPT-0004.json`, `sdk/workflows/fixtures/scan-accept/SDK-WF-SCAN-ACCEPT-0005.json`, `scripts/sdk/check_swift_package.sh`, `scripts/sdk/check_kotlin_package.sh`, `scripts/sdk/check_wasm_package.sh`
  Modules: `sdk/trust/**`, `core/rust/grain-client-core/src/platform/trust.rs`, `sdk/swift/Sources/GrainClient/GrainClient.swift`, `sdk/kotlin/src/main/kotlin/dev/grain/GrainClient.kt`, `sdk/wasm/src/index.mjs`

- SDK-INV-0019: generated binding harness MUST expose workflow APIs over binding-safe DTOs, generate Swift/Kotlin bindings reproducibly from checked-in UDL/scripts, leave no generated repository junk during checks, and avoid raw QR/COSE/DAG-CBOR/protocol-runner operations as app APIs.
  Tests: `core/rust/grain-client-core/tests/binding_api.rs`, `scripts/sdk/check_generated_bindings.sh`
  Modules: `core/rust/grain-client-core/src/binding_api.rs`, `core/rust/grain-client-core/src/grain_client_core.udl`, `core/rust/grain-client-core/build.rs`, `core/rust/uniffi-bindgen/src/main.rs`, `scripts/sdk/generate_client_bindings.sh`, `scripts/sdk/check_generated_bindings.sh`

- SDK-INV-0020: Swift client package MUST wrap generated workflow bindings with a small app-facing API, expose typed preview/accept statuses, execute shared workflow fixtures through `GrainClient`, constrain fixture references to protocol vectors, and fail checks on generated Swift drift.
  Tests: `scripts/sdk/check_swift_package.sh`, `scripts/sdk/sync_swift_bindings.sh`, `sdk/swift/Sources/GrainClientFixtureRunner/main.swift`
  Modules: `sdk/swift/Package.swift`, `sdk/swift/Sources/GrainClient/GrainClient.swift`, `sdk/swift/Sources/GrainClientFFI/grain_client_core.swift`, `sdk/swift/Sources/grain_client_coreFFI/include/grain_client_coreFFI.h`

- SDK-INV-0021: Kotlin client package MUST wrap generated workflow bindings with a small app-facing API, expose typed preview/accept statuses, execute shared workflow fixtures through `GrainClient`, constrain fixture references to protocol vectors, and fail checks on generated Kotlin drift.
  Tests: `scripts/sdk/check_kotlin_package.sh`, `scripts/sdk/sync_kotlin_bindings.sh`, `sdk/kotlin/src/test/kotlin/dev/grain/fixture/GrainClientFixtureRunner.kt`
  Modules: `sdk/kotlin/settings.gradle.kts`, `sdk/kotlin/build.gradle.kts`, `sdk/kotlin/src/main/kotlin/dev/grain/GrainClient.kt`, `sdk/kotlin/src/main/kotlin/uniffi/grain_client_core/grain_client_core.kt`

- SDK-INV-0022: WASM/mobile-web client package MUST wrap client workflow bindings with a small app-facing API, expose typed preview/accept statuses, execute shared workflow fixtures through `GrainClient`, constrain fixture references to protocol vectors, and fail checks on WASM build/load drift or raw protocol API exposure.
  Tests: `scripts/sdk/check_wasm_package.sh`, `sdk/wasm/tests/run-workflow-fixtures.mjs`
  Modules: `core/rust/grain-client-wasm/src/lib.rs`, `sdk/wasm/src/index.mjs`, `sdk/wasm/src/node.mjs`, `sdk/wasm/package.json`

- SDK-INV-0023: portable identity and device lifecycle workflows MUST create CSPRNG-backed identity material, reject malformed imported bundles before mutation, keep active/revoked device state synchronized with derived root-authored grant/revoke lifecycle events, and report client lifecycle counts through generated SDKs.
  Tests: `core/rust/grain-client-core/tests/identity_device_lifecycle.rs`, `core/rust/grain-client-core/tests/client_workflow_fixtures.rs`, `core/rust/grain-client-core/tests/pairing_sync_bundle.rs`, `core/rust/grain-client-core/tests/storage_contract.rs`, `scripts/sdk/check_swift_package.sh`, `scripts/sdk/check_kotlin_package.sh`, `scripts/sdk/check_wasm_package.sh`
  Modules: `core/rust/grain-client-core/src/identity.rs`, `core/rust/grain-client-core/src/device.rs`, `core/rust/grain-client-core/src/store.rs`, `core/rust/grain-client-core/src/memory_store.rs`, `sdk/workflows/fixtures/device-lifecycle/*.json`

- SDK-INV-0024: pairing workflows MUST preview app-transferred envelopes without mutation, accept valid envelopes atomically into an uninitialized client, reject malformed or conflicting envelopes, and treat replay of the same envelope as idempotent.
  Tests: `core/rust/grain-client-core/tests/pairing_sync_bundle.rs`, `core/rust/grain-client-core/tests/client_workflow_fixtures.rs`, `scripts/sdk/check_swift_package.sh`, `scripts/sdk/check_kotlin_package.sh`, `scripts/sdk/check_wasm_package.sh`
  Modules: `core/rust/grain-client-core/src/pairing.rs`, `core/rust/grain-client-core/src/identity.rs`, `core/rust/grain-client-core/src/memory_store.rs`, `sdk/workflows/fixtures/pairing/*.json`

- SDK-INV-0025: sync bundle workflows MUST export identity, accepted scans, and lifecycle events together, import them atomically, reject identity root conflicts and forged lifecycle event IDs/types/payloads/sequences before partial writes, and treat repeated imports as idempotent.
  Tests: `core/rust/grain-client-core/tests/pairing_sync_bundle.rs`, `core/rust/grain-client-core/tests/client_workflow_fixtures.rs`, `scripts/sdk/check_swift_package.sh`, `scripts/sdk/check_kotlin_package.sh`, `scripts/sdk/check_wasm_package.sh`
  Modules: `core/rust/grain-client-core/src/sync.rs`, `core/rust/grain-client-core/src/store.rs`, `core/rust/grain-client-core/src/memory_store.rs`, `sdk/workflows/fixtures/sync-bundle/*.json`

- SDK-INV-0026: generated platform SDKs MUST expose the expanded workflow surface consistently across Swift, Kotlin, and WASM while keeping app APIs workflow-shaped and raw QR/COSE/DAG-CBOR/protocol-runner operations out of public wrappers.
  Tests: `scripts/sdk/check_generated_bindings.sh`, `scripts/sdk/check_swift_package.sh`, `scripts/sdk/check_kotlin_package.sh`, `scripts/sdk/check_wasm_package.sh`
  Modules: `core/rust/grain-client-core/src/binding_api.rs`, `core/rust/grain-client-core/src/grain_client_core.udl`, `sdk/swift/Sources/GrainClient/GrainClient.swift`, `sdk/kotlin/src/main/kotlin/dev/grain/GrainClient.kt`, `sdk/wasm/src/index.mjs`

- SDK-INV-0027: iOS adapter pack MUST keep app code workflow-shaped: scanner preview/accept use explicit `trustAnchorID` plus `GrainTrustProvider`, production setup loads app-managed trust bundle JSON and Keychain-backed snapshot persistence, durable state is persisted only as opaque `snapshotB64` through `GrainClientIOSAdapters`, accepted-scan list/export UI state MUST avoid exposing snapshot or bundle payload material, injected camera payloads become GR1 strings, and scanner code MUST NOT perform raw protocol operations, hidden trust lookup, network trust discovery, TOFU, fallback trust, or secret snapshot/trust logging.
  Tests: `scripts/sdk/check_swift_package.sh`, `scripts/sdk/check_scanner_examples.sh`, `examples/ios-scanner/Sources/GrainIOSScannerSmoke/main.swift`
  Modules: `sdk/swift/Sources/GrainClientIOSAdapters/GrainSnapshotPersistence.swift`, `sdk/swift/Sources/GrainClientIOSAdaptersSmoke/main.swift`, `examples/ios-scanner/Sources/GrainIOSScanner/ScannerShellModel.swift`, `examples/ios-scanner/Sources/GrainIOSScanner/CameraScanAdapter.swift`, `examples/ios-scanner/Sources/GrainIOSScannerSmoke/main.swift`

- SDK-INV-0028: Android adapter pack MUST keep app code workflow-shaped: scanner preview/accept use explicit `trustAnchorId` plus `GrainTrustProvider`, production setup loads app-managed trust bundle JSON, durable state is persisted only as opaque `snapshotB64` through `dev.grain.android`, AES-GCM snapshot sealing uses an app-supplied Android Keystore `SecretKey` boundary, accepted-scan list/export UI state MUST avoid exposing snapshot or bundle payload material, injected CameraX-style payloads become GR1 strings, and scanner code MUST NOT perform raw protocol operations, hidden trust lookup, network trust discovery, TOFU, fallback trust, or secret snapshot/trust logging.
  Tests: `scripts/sdk/check_kotlin_package.sh`, `scripts/sdk/check_scanner_examples.sh`, `examples/android-scanner/src/test/kotlin/dev/grain/examples/androidscanner/ScannerShellTest.kt`
  Modules: `sdk/kotlin/src/main/kotlin/dev/grain/android/GrainSnapshotPersistence.kt`, `sdk/kotlin/src/test/kotlin/dev/grain/android/GrainAndroidAdaptersSmoke.kt`, `examples/android-scanner/src/main/kotlin/dev/grain/examples/androidscanner/ScannerShell.kt`, `examples/android-scanner/src/main/kotlin/dev/grain/examples/androidscanner/CameraScanAdapter.kt`, `examples/android-scanner/src/test/kotlin/dev/grain/examples/androidscanner/ScannerShellTest.kt`

- SDK-INV-0029: WASM/mobile-web adapter pack MUST keep app code workflow-shaped: scanner preview/accept use explicit `trustAnchorId` plus `GrainTrustProvider`, durable state is persisted only as opaque `snapshotB64` through browser/mobile-web persistence adapters, injected/browser camera payloads become GR1 strings, and scanner code MUST NOT perform raw protocol operations, hidden trust lookup, network trust discovery, TOFU, fallback trust, or secret snapshot/trust logging.
  Tests: `scripts/sdk/check_wasm_package.sh`, `scripts/sdk/check_scanner_examples.sh`, `sdk/wasm/tests/run-browser-adapters-smoke.mjs`, `examples/wasm-scanner/tests/scanner-shell-smoke.mjs`
  Modules: `sdk/wasm/src/index.mjs`, `sdk/wasm/src/browser-storage.mjs`, `sdk/wasm/tests/run-browser-adapters-smoke.mjs`, `examples/wasm-scanner/src/scanner-shell.mjs`, `examples/wasm-scanner/src/camera-adapter.mjs`, `examples/wasm-scanner/tests/scanner-shell-smoke.mjs`

- SDK-INV-0030: reference issuer tooling MUST generate signed `GR1:` scanner examples from strict DAG-CBOR `ServingOffer` payloads, emit only public trust material, reject mismatched issuer IDs before signing, and prove the output verifies through `grain-client-core`.
  Tests: `cargo test --manifest-path core/rust/Cargo.toml -p grain-issuer-kit`
  Modules: `core/rust/grain-issuer-kit`, `core/rust/grain-core/src/cose.rs`, `core/rust/grain-core/src/qr.rs`, `core/rust/grain-client-core/src/scan.rs`

- SDK-INV-0031: generated platform SDKs MUST keep device-bound custody separate from portable transfer artifacts. Store snapshots stay opaque and protected by app/device storage; identity bundles, pairing envelopes, and sync bundles are secret portable transfer payloads; UI/logs expose only statuses, counts, IDs, and diagnostics. Public Rust/FFI/Swift/Kotlin debug output and WASM logging helpers MUST redact raw snapshot, bundle, envelope, accepted-scan COSE, and trust material.
  Tests: `core/rust/grain-client-core/tests/pairing_sync_bundle.rs`, `sdk/swift/Sources/GrainClientFixtureRunner/main.swift`, `sdk/kotlin/src/test/kotlin/dev/grain/fixture/GrainClientFixtureRunner.kt`, `sdk/wasm/tests/run-workflow-fixtures.mjs`, `tools/ci/check_sdk_secret_logging.py`
  Modules: `core/rust/grain-client-core/src/custody.rs`, `core/rust/grain-client-core/src/types.rs`, `core/rust/grain-client-core/src/ffi_types.rs`, `core/rust/grain-client-core/src/pairing.rs`, `core/rust/grain-client-core/src/sync.rs`, `sdk/swift/Sources/GrainClient/GrainClient.swift`, `sdk/kotlin/src/main/kotlin/dev/grain/GrainClient.kt`, `sdk/wasm/src/index.mjs`

- SDK-INV-0032: Food Wallet app surfaces MUST preserve the Food Profile reducer contract while keeping photo/model inputs draft-first and safe-summary-only. Drafts can come from verified serving offers, self-issued/manual entry, or estimated photo/model output; user confirmation is required before append; raw photos, raw QR strings, trust material, snapshots, sync bundles, identity bundles, COSE payloads, and private keys MUST NOT appear in SDK safe reports, fixtures, or starter outputs.
  Tests: `tools/ci/test_check_food_wallet_contract.py`, `tools/ci/check_food_wallet_contract.py`, `scripts/sdk/check_food_wallet_contract.sh`, `scripts/sdk/run_food_wallet_pilot.sh`, `core/ts/grain-sdk/scripts/test-food-wallet.ts`, `scripts/sdk/check_swift_food_wallet.sh`, `scripts/sdk/check_kotlin_food_wallet.sh`, `scripts/sdk/verify_all_sdks.sh`
  Modules: `sdk/food/contract/food_wallet_v1.schema.json`, `sdk/food/README.md`, `examples/reference-fixtures/food-wallet-*.v1.json`, `core/ts/grain-sdk/src/food-wallet.ts`, `sdk/swift/Sources/GrainFoodWallet/GrainFoodWallet.swift`, `sdk/kotlin/src/main/kotlin/dev/grain/food/FoodWallet.kt`, `templates/ios-food-wallet-starter`, `templates/android-food-wallet-starter`

- SDK-AI-000: AI surface MUST stay opt-in and out of the default `GrainSdk` API.
  Tests: `core/ts/grain-sdk-ai/scripts/test-sdk-ai-boundary.ts` (`SDK-AI-000 sidecar stays optional`)
  Modules: `core/ts/grain-sdk/src/sdk.ts`, `core/ts/grain-sdk/src/ai-host.ts`

- SDK-AI-001: AI candidate MUST pass `accept()` before any apply side effect; opaque token only; default SDK must not expose a public raw AI host writer, the sidecar bridge must only write bytes under their derived CID, and exported candidate contracts MUST NOT advertise unsupported event candidates before `event_append` exists.
  Tests: `core/ts/grain-sdk-ai/scripts/test-sdk-ai-boundary.ts` (`SDK-AI-001 no public sdk.store`, `SDK-AI-001 no public sdk.createAiHost`, `SDK-AI-001 host cid mismatch rejects`, `SDK-AI-001 apply accepted token`, `SDK-AI-001 forged token reject`, `SDK-AI-001 contract narrows unsupported event candidates`, `SDK-AI-001 event candidates reject until append is implemented`)
  Modules: `core/ts/grain-sdk/src/sdk.ts`, `core/ts/grain-sdk-ai/src/ai/token_registry.ts`, `core/ts/grain-sdk-ai/src/ai/accept.ts`

- SDK-AI-002: AI acceptance/apply MUST be deterministic for same input class, and `dagcbor_b64` payloads MUST be canonical base64 standard before strict DAG-CBOR validation.
  Tests: `core/ts/grain-sdk-ai/scripts/test-sdk-ai-boundary.ts` (`SDK-AI-002 deterministic accept`, `SDK-AI-002 replay reject`, `SDK-AI-002 token expiry`, `SDK-AI-002 dagcbor accept path`, `SDK-AI-002 dagcbor rejects non-canonical base64`)
  Modules: `core/ts/grain-sdk-ai/src/ai/accept.ts`, `core/ts/grain-sdk-ai/src/ai/token_registry.ts`

- SDK-AI-003: SDK core MUST have no outbound network calls (model/vendor agnostic boundary).
  Tests: `tools/ci/check_sdk_no_network.py` (`SDK no-network guard: OK (core + ai sidecar)`), `tools/ci/check_sdk_ai_boundary.py` (`SDK AI boundary guard: OK`)
  Modules: `core/ts/grain-sdk/src/**`, `core/ts/grain-sdk-ai/src/**`, `tools/ci/check_sdk_no_network.py`, `tools/ci/check_sdk_ai_boundary.py`

- SDK-AI-004: AI explain payload MUST be redacted by default, and structured bytes fields MUST be canonical base64 standard before byte conversion.
  Tests: `core/ts/grain-sdk-ai/scripts/test-sdk-ai-boundary.ts` (`SDK-AI-004 redaction default`, `SDK-AI-004 sensitive mode bounded`, `SDK-AI-004 bytes field rejects non-canonical base64`)
  Modules: `core/ts/grain-sdk-ai/src/ai/diagnostics.ts`, `core/ts/grain-sdk-ai/src/ai/accept.ts`

- SDK-AI-005: Numeric ingestion MUST accept decimal strings only and convert deterministically.
  Tests: `core/ts/grain-sdk-ai/scripts/test-sdk-ai-boundary.ts` (`SDK-AI-005 numeric fields reject JS number`, `SDK-AI-005 explicit profile required`)
  Modules: `core/ts/grain-sdk-ai/src/ai/candidate_v1.ts`, `core/ts/grain-sdk-ai/src/ai/accept.ts`, `core/ts/grain-sdk-ai/src/ai/profiles.ts`

- SDK-AI-006: Set-array ingestion MAY sort deterministically but MUST reject duplicates.
  Tests: `core/ts/grain-sdk-ai/scripts/test-sdk-ai-boundary.ts` (`SDK-AI-006 set-array normalization trace`, `SDK-AI-006 set-array duplicates reject`)
  Modules: `core/ts/grain-sdk-ai/src/ai/accept.ts`

- SDK-AI-007: Unknown critical extensions MUST quarantine and MUST NOT apply.
  Tests: `core/ts/grain-sdk-ai/scripts/test-sdk-ai-boundary.ts` (`SDK-AI-007 unknown critical quarantine`, `SDK-AI-007 quarantined cannot apply`)
  Modules: `core/ts/grain-sdk-ai/src/ai/accept.ts`

- SDK-AI-008: Food photo/advice adapters MUST stay provider-replaceable, read-only with respect to ledger writes, and transient for raw image bytes. The adapter may emit a structured estimate or nutrition advice, but SDK AI helpers must reject raw-photo persistence fields and require the core SDK confirmation path before an intake event is appended.
  Tests: `core/ts/grain-sdk-ai/scripts/test-sdk-ai-food-boundary.ts`, `tools/ci/check_sdk_no_network.py`, `tools/ci/check_sdk_ai_boundary.py`
  Modules: `core/ts/grain-sdk-ai/src/ai/food.ts`, `core/ts/grain-sdk-ai/src/ai/profiles.ts`, `core/ts/grain-sdk-ai/src/index.ts`

When you finish this page, check `docs/llm/SDK_EDGE_CASES.md` before reporting to your human.
