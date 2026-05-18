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
6. `sdk/food/**`
   - Food Wallet app contract, typed schema, and no-raw-photo/safe-summary guard for food-first clients.
7. `sdk/workflows/**`
   - Client workflow conformance fixtures for generated platform SDKs.
8. `sdk/trust/**`
   - Local trust anchor bundle schema and fixtures for app-owned trust providers; no network discovery or fallback trust belongs here.
9. `docs/human/sdk/start-here.md`
   - Plain-language entry point for app builders.
10. `docs/human/sdk/food-wallet.md`
   - Plain-language integration contract for the first useful food-tracking app shape.
11. `docs/human/sdk/scan-quickstart.md`
   - Cross-platform checkout-to-scan path for issuer QR generation, local trust bundles, preview, accept, snapshot persistence, and release/package boundaries.
12. `core/ts/grain-sdk/README.md`
   - Package-level overview with copyable commands.
13. `core/ts/grain-sdk-ai/README.md`
   - Optional AI sidecar package map and commands.
14. `docs/human/sdk/portable-client-sdk.md`
   - Camera-first SDK direction for iOS, Android, glasses, robots, and generated bindings.
15. `docs/human/sdk/version-matrix.md`
   - Compatibility matrix for generated SDK releases and same-SHA binding/wrapper rules.
16. `docs/llm/SDK_GENERATED_VERIFICATION.md`
   - Verification and release-packaging map for generated platform SDKs.
17. `scripts/sdk/doctor`, `scripts/sdk/package_client_sdks.sh`, `tools/ci/build_sdk_release_metadata.py`, and `tools/ci/check_sdk_release_package.py`
   - SDK release packaging, manifest/SHA256/SBOM generation, and package metadata certification.
18. `core/rust/grain-issuer-kit`
   - Reference issuer CLI/library for local scanner development. It emits signed `GR1:` examples and public trust material; it is not a platform SDK API or production key-management system.
19. `core/rust/grain-client-core/src/*`
   - Portable Rust workflow layer for generated platform SDKs: `scan.rs` owns scan workflows; `identity.rs`, `device.rs`, `pairing.rs`, and `sync.rs` own lifecycle workflows; `custody.rs` owns portable transfer metadata for pairing/sync payloads; `types.rs` owns Rust DTOs and redacted debug output; `ffi_types.rs` owns binding-safe DTOs and redacted debug output; `binding_api.rs` and `grain_client_core.udl` own the UniFFI-safe generated-binding facade; `platform/storage.rs` and `platform/trust.rs` own adapter contracts; `trust.rs` owns explicit trust decoding; `store.rs` owns the atomic storage contract; `memory_store.rs` owns the reference store plus opaque snapshot export/restore; and `diag.rs` owns SDK-only diagnostics.
20. `core/rust/uniffi-bindgen`, `scripts/sdk/*generated_bindings.sh`, and `sdk/generated/README.md`
   - Binding generation harness and docs. These are not published platform SDK packages.
21. `sdk/swift/**`
   - Swift Package Manager client package over generated workflow bindings. Public app API lives in `Sources/GrainClient`, generated binding sources live in `Sources/GrainClientFFI` and `Sources/grain_client_coreFFI`, the executable fixture runner lives in `Sources/GrainClientFixtureRunner`, the Food Wallet facade lives in `Sources/GrainFoodWallet`, and the iOS adapter pack lives in `Sources/GrainClientIOSAdapters` plus `Sources/GrainClientIOSAdaptersSmoke`. Store snapshot methods remain the Rust-owned persistence bridge; the iOS adapter pack persists only opaque snapshots.
22. `sdk/kotlin/**`
   - Kotlin/JVM client package over generated workflow bindings. Public app API lives in `src/main/kotlin/dev/grain`, generated binding source lives in `src/main/kotlin/uniffi/grain_client_core`, the executable fixture runner lives in `src/test/kotlin/dev/grain/fixture`, the Food Wallet facade lives in `src/main/kotlin/dev/grain/food`, and the Android adapter pack lives in `src/main/kotlin/dev/grain/android` plus `src/test/kotlin/dev/grain/android`. Store snapshot methods remain the Rust-owned persistence bridge; the Android adapter pack persists only opaque snapshots and exposes AES-GCM/Keystore-ready sealing through app-owned keys.
23. `core/rust/grain-client-wasm/**`
   - WASM client workflow export over `grain-client-core`. This is distinct from `grain-core-wasm`, which remains the protocol/vector portability lane.
24. `sdk/wasm/**`
   - WASM/mobile-web client package over workflow bindings. Public app API lives in `src/index.mjs`/`src/index.d.ts`, the browser/mobile-web adapter pack lives in `src/browser-storage.mjs`, the Node/WASI smoke loader lives in `src/node.mjs`, the fixture runner lives in `tests/run-workflow-fixtures.mjs`, and the browser adapter smoke lives in `tests/run-browser-adapters-smoke.mjs`. Store snapshot methods remain the Rust-owned persistence bridge; the WASM/mobile-web adapter pack persists only opaque snapshots. Custody policy helpers and `redactGrainClientLogValue` are SDK-DX helpers, not hidden key management.
25. `docs/human/sdk/impossible-misuse.md`
   - Human-readable reject-path summary.
26. `docs/human/sdk/errors.md`
   - Human-readable error contract.
27. `core/ts/grain-sdk/src/*`
   - Core SDK implementation modules.
28. `core/ts/grain-sdk-ai/src/*`
   - Optional AI sidecar implementation modules.

## Source-of-truth hierarchy for SDK decisions

1. `spec/NES-v0.1.md`
2. `spec/profiles/*`
3. `conformance/vectors/*`
4. `sdk/workflows/**` (client workflow conformance over protocol vectors)
5. `sdk/food/**` (Food Wallet app-facing domain contract over Food Profile)
6. `sdk/trust/**` (app-owned trust anchor bundle schema and fixture material)
7. `core/ts/grain-ts-core/src/*` (shared TS protocol engine behavior)
8. `runner/typescript/src/*` (runner harness and compatibility surface)
9. `core/rust/grain-issuer-kit` (reference issuer tooling over existing Rust core rules)
10. `core/rust/grain-client-core/src/*` (portable client workflows over Rust core)
11. `sdk/swift/**` (generated Swift client package wrapper and fixture runner)
12. `sdk/kotlin/**` (generated Kotlin client package wrapper and fixture runner)
13. `core/rust/grain-client-wasm/**` (WASM workflow export over Rust client core)
14. `sdk/wasm/**` (generated WASM/mobile-web client package wrapper and fixture runner)
15. `core/ts/grain-sdk/src/*` (orchestration only)
16. `core/ts/grain-sdk-ai/src/*` (optional sidecar only)
17. `docs/llm/*` (maintainer maps, sync rules, and indexes)
18. `docs/human/sdk/*` (explanatory, not normative)

If SDK behavior diverges from protocol vectors, treat it as a bug in SDK and update the matching docs and tests in the same change.
