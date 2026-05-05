# SDK_FILE_MAP

Hi teammate LLM. This is the shortest safe path through the SDK layer.

## Read order

1. `docs/llm/DOC_SYNC.md`
   - Use this before changing SDK behavior or the docs that describe it.
2. `docs/llm/SDK_INVARIANTS.md`
   - What the SDK must enforce and never hide.
3. `docs/llm/SDK_EDGE_CASES.md`
   - Mandatory negative outcomes at the SDK boundary.
4. `docs/llm/SDK_CONFORMANCE.md`
   - SDK runner and test bindings.
5. `docs/llm/SDK_AI_BOUNDARY.md`
   - Deterministic AI ingestion firewall and token boundary.
6. `sdk/workflows/**`
   - Client workflow conformance fixtures for generated platform SDKs.
7. `docs/human/sdk/start-here.md`
   - Plain-language entry point for app builders.
8. `core/ts/grain-sdk/README.md`
   - Package-level overview with copyable commands.
9. `core/ts/grain-sdk-ai/README.md`
   - Optional AI sidecar package map and commands.
10. `docs/human/sdk/portable-client-sdk.md`
   - Camera-first SDK direction for iOS, Android, glasses, robots, and generated bindings.
11. `docs/human/sdk/version-matrix.md`
   - Compatibility matrix for generated SDK releases and same-SHA binding/wrapper rules.
12. `docs/llm/SDK_GENERATED_VERIFICATION.md`
   - Verification and release-packaging map for generated platform SDKs.
13. `core/rust/grain-client-core/src/*`
   - Portable Rust workflow layer for generated platform SDKs: `scan.rs` owns scan workflows; `identity.rs`, `device.rs`, `pairing.rs`, and `sync.rs` own lifecycle workflows; `types.rs` owns Rust DTOs; `ffi_types.rs` owns binding-safe DTOs; `binding_api.rs` and `grain_client_core.udl` own the UniFFI-safe generated-binding facade; `platform/storage.rs` and `platform/trust.rs` own adapter contracts; `trust.rs` owns explicit trust decoding; `store.rs` owns the atomic storage contract; `memory_store.rs` owns the reference store plus opaque snapshot export/restore; and `diag.rs` owns SDK-only diagnostics.
14. `core/rust/uniffi-bindgen`, `scripts/sdk/*generated_bindings.sh`, and `sdk/generated/README.md`
   - Binding generation harness and docs. These are not published platform SDK packages.
15. `sdk/swift/**`
   - Swift Package Manager client package over generated workflow bindings. Public app API lives in `Sources/GrainClient`, generated binding sources live in `Sources/GrainClientFFI` and `Sources/grain_client_coreFFI`, the executable fixture runner lives in `Sources/GrainClientFixtureRunner`, and the iOS adapter pack lives in `Sources/GrainClientIOSAdapters` plus `Sources/GrainClientIOSAdaptersSmoke`. Store snapshot methods remain the Rust-owned persistence bridge; the iOS adapter pack persists only opaque snapshots.
16. `sdk/kotlin/**`
   - Kotlin/JVM client package over generated workflow bindings. Public app API lives in `src/main/kotlin/dev/grain`, generated binding source lives in `src/main/kotlin/uniffi/grain_client_core`, the executable fixture runner lives in `src/test/kotlin/dev/grain/fixture`, and the Android adapter pack lives in `src/main/kotlin/dev/grain/android` plus `src/test/kotlin/dev/grain/android`. Store snapshot methods remain the Rust-owned persistence bridge; the Android adapter pack persists only opaque snapshots.
17. `core/rust/grain-client-wasm/**`
   - WASM client workflow export over `grain-client-core`. This is distinct from `grain-core-wasm`, which remains the protocol/vector portability lane.
18. `sdk/wasm/**`
   - WASM/mobile-web client package over workflow bindings. Public app API lives in `src/index.mjs`, the Node/WASI smoke loader lives in `src/node.mjs`, and the fixture runner lives in `tests/run-workflow-fixtures.mjs`. Store snapshot methods are the persistence bridge for IndexedDB/browser adapters in later slices.
19. `docs/human/sdk/impossible-misuse.md`
   - Human-readable reject-path summary.
20. `docs/human/sdk/errors.md`
   - Human-readable error contract.
21. `core/ts/grain-sdk/src/*`
   - Core SDK implementation modules.
22. `core/ts/grain-sdk-ai/src/*`
   - Optional AI sidecar implementation modules.

## Source-of-truth hierarchy for SDK decisions

1. `spec/NES-v0.1.md`
2. `spec/profiles/*`
3. `conformance/vectors/*`
4. `sdk/workflows/**` (client workflow conformance over protocol vectors)
5. `core/ts/grain-ts-core/src/*` (shared TS protocol engine behavior)
6. `runner/typescript/src/*` (runner harness and compatibility surface)
7. `core/rust/grain-client-core/src/*` (portable client workflows over Rust core)
8. `sdk/swift/**` (generated Swift client package wrapper and fixture runner)
9. `sdk/kotlin/**` (generated Kotlin client package wrapper and fixture runner)
10. `core/rust/grain-client-wasm/**` (WASM workflow export over Rust client core)
11. `sdk/wasm/**` (generated WASM/mobile-web client package wrapper and fixture runner)
12. `core/ts/grain-sdk/src/*` (orchestration only)
13. `core/ts/grain-sdk-ai/src/*` (optional sidecar only)
14. `docs/llm/*` (maintainer maps, sync rules, and indexes)
15. `docs/human/sdk/*` (explanatory, not normative)

If SDK behavior diverges from protocol vectors, treat it as a bug in SDK and update the matching docs and tests in the same change.
