# SDK Architecture

This page defines boundaries. The SDK is a strict orchestration layer, not a new protocol semantics layer.

## Practical reading

- If you are building an app, start with `identity`, `events`, `manifest`, `e2e`, and `transport`.
- If you need byte validation or diagnostics explanation, use `codec`.
- If you are handling model output, use the optional sidecar in `core/ts/grain-sdk-ai`.

## Layer boundaries

1. Protocol (`spec/*`, `conformance/*`)
   - normative rules
   - frozen-core behavior
2. Core engines (`core/rust/grain-core`, `core/ts/grain-ts-core/src`)
   - deterministic rule execution
   - canonical diagnostics
3. Runner surface (`runner/typescript/src`)
   - CLI and conformance harness over the shared TS core
4. SDK (`core/ts/grain-sdk`)
   - typed primitives + safe builders
   - orchestration for identity/events/e2e/manifest/transport/evidence
   - no rule rewrites
5. Portable client core (`core/rust/grain-client-core`)
   - workflow-shaped Rust APIs for generated platform SDKs
   - scan preview/accept style APIs for camera-first clients
   - no rule rewrites
6. Generated platform packages (`sdk/swift`, `sdk/kotlin`, `sdk/wasm`)
   - small app-facing wrappers over generated client workflow bindings
   - shared fixture execution through public package APIs
   - no raw QR/COSE/DAG-CBOR/protocol-runner APIs as the app surface
7. Optional AI sidecar (`core/ts/grain-sdk-ai`)
   - deterministic AI ingestion firewall (`accept` -> `applyAccepted`)
   - explicit host bridge into SDK object storage only
   - no rule rewrites

## What the SDK is allowed to do

- strict by default
- stop on unsafe paths instead of guessing
- preserve core diagnostics (SDK-only codes stay in `SDK_ERR_*`)
- surface conflict/quarantine/unauthorized status explicitly
- require atomic store mutations for multi-step public SDK writes

## What the SDK is not allowed to do

- invent new protocol semantics
- add soft fallback modes
- silently "repair" non-canonical data
- hide conflict, quarantine, revoke, or unauthorized states

## Module map

- `src/identity.ts`: root/device lifecycle, bundle import/export
  - bundle import validates required binary fields before mutation
- `src/events.ts`: append/void/correct/merge/reduce orchestration
- `src/e2e.ts`: deterministic derive/encrypt/decrypt wrappers + manifest glue
- `src/manifest.ts`: deterministic resolution bridge
- `src/transport.ts`: GR1 helpers + deterministic bundle import/export
  - decode and verify stay separate
  - `verifyGR1()` requires explicit trust material and rejects malformed `trust.pub_b64`
  - bundle rows are schema-checked and binary-bearing fields are strict-base64-validated before export/import
- `core/rust/grain-client-core/src/*`: portable scan workflow core for generated platform SDKs
  - `scan.rs` keeps `scan_preview()` decode-only preview separate from verified preview
  - `scan_accept_prepare()` requires explicit verified trust and returns deterministic, persistence-ready records without writing storage
  - `scan_accept()` persists verified records through an atomic store boundary and leaves rejected scans unwritten
  - `store.rs` and `memory_store.rs` define the platform-neutral storage contract and reference rollback/idempotency behavior
  - `platform/storage.rs` and `platform/trust.rs` define adapter contracts without importing platform-specific storage or network trust APIs
  - `ffi_types.rs` flattens workflow values into owned binding-safe DTOs
  - `binding_api.rs`, `grain_client_core.udl`, and `build.rs` define the UniFFI-safe generated-binding facade
  - `core/rust/grain-client-wasm` exposes the same client workflow surface to WASM without using the protocol runner ABI or target-side UniFFI runtime
  - `core/rust/uniffi-bindgen` and `scripts/sdk/*generated_bindings.sh` generate/check Swift and Kotlin bindings without committing generated output
  - `types.rs`, `trust.rs`, and `diag.rs` keep DTOs, trust decoding, and SDK diagnostics separated for generated bindings
- `sdk/swift/*`: Swift Package Manager client package over generated workflow bindings
  - `Sources/GrainClient` is the public wrapper surface
  - `Sources/GrainClientFFI` and `Sources/grain_client_coreFFI` are synchronized generated binding sources
  - `Sources/GrainClientFixtureRunner` executes `sdk/workflows` fixtures through the public Swift API
  - `scripts/sdk/sync_swift_bindings.sh` and `scripts/sdk/check_swift_package.sh` keep generated sources reproducible
- `sdk/kotlin/*`: Kotlin/JVM client package over generated workflow bindings
  - `src/main/kotlin/dev/grain` is the public wrapper surface
  - `src/main/kotlin/uniffi/grain_client_core` is the synchronized generated binding source
  - `src/test/kotlin/dev/grain/fixture` executes `sdk/workflows` fixtures through the public Kotlin API
  - `scripts/sdk/sync_kotlin_bindings.sh` and `scripts/sdk/check_kotlin_package.sh` keep generated sources reproducible
- `sdk/wasm/*`: WASM/mobile-web client package over client workflow bindings
  - `src/index.mjs` is the browser-like public wrapper surface
  - `src/node.mjs` is the first smoke-tested Node/WASI loader
  - `tests/run-workflow-fixtures.mjs` executes `sdk/workflows` fixtures through the public web API
  - `scripts/sdk/check_wasm_package.sh` keeps the WASM package and fixture lane reproducible
- `src/codec.ts`: strict validation and diagnostics explanation
- `src/evidence.ts`: deterministic SDK evidence bundle
- `src/primitives.ts`: typed wrappers and set-array builder
- `src/ai-host.ts`: narrow bridge that the optional AI sidecar can use
- `core/ts/grain-sdk-ai/src/ai/*`: model-agnostic candidate ingestion, deterministic accept/apply, opaque token registry

## Non-goals (enforced)

- no domain semantics
- no alternative conflict or revoke semantics
- no vendor model clients or outbound network calls in SDK core or AI sidecar
- no partial commit semantics for public multi-step SDK writes

## Audit anchors

- ADR: `adr/sdk/0001-sdk-universal-primitives-layer.md`
- ADR: `adr/sdk/0003-ai-boundary-deterministic-ingestion.md`
- ADR: `adr/sdk/0004-portable-client-core-generated-platform-sdks.md`
- Invariants: `docs/llm/SDK_INVARIANTS.md`
- Reject paths: `docs/llm/SDK_EDGE_CASES.md`
- Conformance binding: `docs/llm/SDK_CONFORMANCE.md`
