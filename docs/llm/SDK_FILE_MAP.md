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
11. `core/rust/grain-client-core/src/*`
   - Portable Rust workflow layer for generated platform SDKs: `scan.rs` owns workflows, `types.rs` owns binding-friendly DTOs, `trust.rs` owns explicit trust decoding, and `diag.rs` owns SDK-only diagnostics.
12. `docs/human/sdk/impossible-misuse.md`
   - Human-readable reject-path summary.
13. `docs/human/sdk/errors.md`
   - Human-readable error contract.
14. `core/ts/grain-sdk/src/*`
   - Core SDK implementation modules.
15. `core/ts/grain-sdk-ai/src/*`
   - Optional AI sidecar implementation modules.

## Source-of-truth hierarchy for SDK decisions

1. `spec/NES-v0.1.md`
2. `spec/profiles/*`
3. `conformance/vectors/*`
4. `sdk/workflows/**` (client workflow conformance over protocol vectors)
5. `core/ts/grain-ts-core/src/*` (shared TS protocol engine behavior)
6. `runner/typescript/src/*` (runner harness and compatibility surface)
7. `core/rust/grain-client-core/src/*` (portable client workflows over Rust core)
8. `core/ts/grain-sdk/src/*` (orchestration only)
9. `core/ts/grain-sdk-ai/src/*` (optional sidecar only)
10. `docs/llm/*` (maintainer maps, sync rules, and indexes)
11. `docs/human/sdk/*` (explanatory, not normative)

If SDK behavior diverges from protocol vectors, treat it as a bug in SDK and update the matching docs and tests in the same change.
