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

- SDK-INV-0010: transport decode and verify MUST stay separate; verify requires explicit trust, and bundle import/export MUST be deterministic + schema-checked + strict-base64-validated on imported binary fields.
  Tests: `core/ts/grain-sdk/scripts/test-sdk-invariants.ts` (`SDK-INV-0010 transport bundle determinism`, `SDK-INV-0010 transport verify requires explicit trust`)
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

- SDK-INV-0018a: generated platform SDKs MUST persist client state through an opaque versioned store snapshot bridge rather than raw store mutation APIs; snapshot restore MUST reject malformed or unsupported payloads without mutating existing state.
  Tests: `core/rust/grain-client-core/tests/storage_contract.rs`, `scripts/sdk/check_swift_package.sh`, `scripts/sdk/check_kotlin_package.sh`, `scripts/sdk/check_wasm_package.sh`
  Modules: `core/rust/grain-client-core/src/memory_store.rs`, `core/rust/grain-client-core/src/types.rs`, `core/rust/grain-client-core/src/ffi_types.rs`, `core/rust/grain-client-core/src/binding_api.rs`, `core/rust/grain-client-core/src/grain_client_core.udl`, `core/rust/grain-client-wasm/src/lib.rs`, `sdk/swift/Sources/GrainClient/GrainClient.swift`, `sdk/kotlin/src/main/kotlin/dev/grain/GrainClient.kt`, `sdk/wasm/src/index.mjs`

- SDK-INV-0018b: generated platform SDKs MUST expose production trust-provider surfaces that take explicit trust anchor IDs, fail closed for missing/unknown anchors, and never perform hidden fallback trust or network trust lookup.
  Tests: `core/rust/grain-client-core/tests/trust_adapter_contract.rs`, `sdk/workflows/fixtures/scan-preview/SDK-WF-SCAN-PREVIEW-0006.json`, `sdk/workflows/fixtures/scan-preview/SDK-WF-SCAN-PREVIEW-0007.json`, `sdk/workflows/fixtures/scan-accept/SDK-WF-SCAN-ACCEPT-0004.json`, `sdk/workflows/fixtures/scan-accept/SDK-WF-SCAN-ACCEPT-0005.json`, `scripts/sdk/check_swift_package.sh`, `scripts/sdk/check_kotlin_package.sh`, `scripts/sdk/check_wasm_package.sh`, `tools/ci/check_sdk_trust_provider_boundary.py`
  Modules: `core/rust/grain-client-core/src/platform/trust.rs`, `sdk/swift/Sources/GrainClient/GrainClient.swift`, `sdk/kotlin/src/main/kotlin/dev/grain/GrainClient.kt`, `sdk/wasm/src/index.mjs`

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

- SDK-INV-0023: portable identity and device lifecycle workflows MUST create CSPRNG-backed identity material, reject malformed imported bundles before mutation, keep active/revoked device state synchronized with lifecycle events, and report client lifecycle counts through generated SDKs.
  Tests: `core/rust/grain-client-core/tests/identity_device_lifecycle.rs`, `core/rust/grain-client-core/tests/client_workflow_fixtures.rs`, `scripts/sdk/check_swift_package.sh`, `scripts/sdk/check_kotlin_package.sh`, `scripts/sdk/check_wasm_package.sh`
  Modules: `core/rust/grain-client-core/src/identity.rs`, `core/rust/grain-client-core/src/device.rs`, `core/rust/grain-client-core/src/store.rs`, `core/rust/grain-client-core/src/memory_store.rs`, `sdk/workflows/fixtures/device-lifecycle/*.json`

- SDK-INV-0024: pairing workflows MUST preview app-transferred envelopes without mutation, accept valid envelopes atomically into an uninitialized client, reject malformed or conflicting envelopes, and treat replay of the same envelope as idempotent.
  Tests: `core/rust/grain-client-core/tests/pairing_sync_bundle.rs`, `core/rust/grain-client-core/tests/client_workflow_fixtures.rs`, `scripts/sdk/check_swift_package.sh`, `scripts/sdk/check_kotlin_package.sh`, `scripts/sdk/check_wasm_package.sh`
  Modules: `core/rust/grain-client-core/src/pairing.rs`, `core/rust/grain-client-core/src/identity.rs`, `core/rust/grain-client-core/src/memory_store.rs`, `sdk/workflows/fixtures/pairing/*.json`

- SDK-INV-0025: sync bundle workflows MUST export identity, accepted scans, and lifecycle events together, import them atomically, reject identity root conflicts before partial writes, and treat repeated imports as idempotent.
  Tests: `core/rust/grain-client-core/tests/pairing_sync_bundle.rs`, `core/rust/grain-client-core/tests/client_workflow_fixtures.rs`, `scripts/sdk/check_swift_package.sh`, `scripts/sdk/check_kotlin_package.sh`, `scripts/sdk/check_wasm_package.sh`
  Modules: `core/rust/grain-client-core/src/sync.rs`, `core/rust/grain-client-core/src/store.rs`, `core/rust/grain-client-core/src/memory_store.rs`, `sdk/workflows/fixtures/sync-bundle/*.json`

- SDK-INV-0026: generated platform SDKs MUST expose the expanded workflow surface consistently across Swift, Kotlin, and WASM while keeping app APIs workflow-shaped and raw QR/COSE/DAG-CBOR/protocol-runner operations out of public wrappers.
  Tests: `scripts/sdk/check_generated_bindings.sh`, `scripts/sdk/check_swift_package.sh`, `scripts/sdk/check_kotlin_package.sh`, `scripts/sdk/check_wasm_package.sh`
  Modules: `core/rust/grain-client-core/src/binding_api.rs`, `core/rust/grain-client-core/src/grain_client_core.udl`, `sdk/swift/Sources/GrainClient/GrainClient.swift`, `sdk/kotlin/src/main/kotlin/dev/grain/GrainClient.kt`, `sdk/wasm/src/index.mjs`

- SDK-INV-0027: iOS adapter pack MUST keep app code workflow-shaped: scanner preview/accept use explicit `trustAnchorID` plus `GrainTrustProvider`, durable state is persisted only as opaque `snapshotB64` through `GrainClientIOSAdapters`, injected camera payloads become GR1 strings, and scanner code MUST NOT perform raw protocol operations, hidden trust lookup, network trust discovery, TOFU, or fallback trust.
  Tests: `scripts/sdk/check_swift_package.sh`, `scripts/sdk/check_scanner_examples.sh`, `examples/ios-scanner/Sources/GrainIOSScannerSmoke/main.swift`
  Modules: `sdk/swift/Sources/GrainClientIOSAdapters/GrainSnapshotPersistence.swift`, `sdk/swift/Sources/GrainClientIOSAdaptersSmoke/main.swift`, `examples/ios-scanner/Sources/GrainIOSScanner/ScannerShellModel.swift`, `examples/ios-scanner/Sources/GrainIOSScanner/CameraScanAdapter.swift`, `examples/ios-scanner/Sources/GrainIOSScannerSmoke/main.swift`

- SDK-AI-000: AI surface MUST stay opt-in and out of the default `GrainSdk` API.
  Tests: `core/ts/grain-sdk-ai/scripts/test-sdk-ai-boundary.ts` (`SDK-AI-000 sidecar stays optional`)
  Modules: `core/ts/grain-sdk/src/sdk.ts`, `core/ts/grain-sdk/src/ai-host.ts`

- SDK-AI-001: AI candidate MUST pass `accept()` before any apply side effect; opaque token only.
  Tests: `core/ts/grain-sdk-ai/scripts/test-sdk-ai-boundary.ts` (`SDK-AI-001 no public sdk.store`, `SDK-AI-001 apply accepted token`, `SDK-AI-001 forged token reject`)
  Modules: `core/ts/grain-sdk/src/sdk.ts`, `core/ts/grain-sdk-ai/src/ai/token_registry.ts`, `core/ts/grain-sdk-ai/src/ai/accept.ts`

- SDK-AI-002: AI acceptance/apply MUST be deterministic for same input class.
  Tests: `core/ts/grain-sdk-ai/scripts/test-sdk-ai-boundary.ts` (`SDK-AI-002 deterministic accept`, `SDK-AI-002 replay reject`, `SDK-AI-002 token expiry`, `SDK-AI-002 dagcbor accept path`)
  Modules: `core/ts/grain-sdk-ai/src/ai/accept.ts`, `core/ts/grain-sdk-ai/src/ai/token_registry.ts`

- SDK-AI-003: SDK core MUST have no outbound network calls (model/vendor agnostic boundary).
  Tests: `tools/ci/check_sdk_no_network.py` (`SDK no-network guard: OK (core + ai sidecar)`), `tools/ci/check_sdk_ai_boundary.py` (`SDK AI boundary guard: OK`)
  Modules: `core/ts/grain-sdk/src/**`, `core/ts/grain-sdk-ai/src/**`, `tools/ci/check_sdk_no_network.py`, `tools/ci/check_sdk_ai_boundary.py`

- SDK-AI-004: AI explain payload MUST be redacted by default.
  Tests: `core/ts/grain-sdk-ai/scripts/test-sdk-ai-boundary.ts` (`SDK-AI-004 redaction default`, `SDK-AI-004 sensitive mode bounded`)
  Modules: `core/ts/grain-sdk-ai/src/ai/diagnostics.ts`

- SDK-AI-005: Numeric ingestion MUST accept decimal strings only and convert deterministically.
  Tests: `core/ts/grain-sdk-ai/scripts/test-sdk-ai-boundary.ts` (`SDK-AI-005 numeric fields reject JS number`, `SDK-AI-005 explicit profile required`)
  Modules: `core/ts/grain-sdk-ai/src/ai/candidate_v1.ts`, `core/ts/grain-sdk-ai/src/ai/accept.ts`, `core/ts/grain-sdk-ai/src/ai/profiles.ts`

- SDK-AI-006: Set-array ingestion MAY sort deterministically but MUST reject duplicates.
  Tests: `core/ts/grain-sdk-ai/scripts/test-sdk-ai-boundary.ts` (`SDK-AI-006 set-array normalization trace`, `SDK-AI-006 set-array duplicates reject`)
  Modules: `core/ts/grain-sdk-ai/src/ai/accept.ts`

- SDK-AI-007: Unknown critical extensions MUST quarantine and MUST NOT apply.
  Tests: `core/ts/grain-sdk-ai/scripts/test-sdk-ai-boundary.ts` (`SDK-AI-007 unknown critical quarantine`, `SDK-AI-007 quarantined cannot apply`)
  Modules: `core/ts/grain-sdk-ai/src/ai/accept.ts`

When you finish this page, check `docs/llm/SDK_EDGE_CASES.md` before reporting to your human.
