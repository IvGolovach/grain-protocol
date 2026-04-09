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
6. `docs/human/sdk/start-here.md`
   - Plain-language entry point for app builders.
7. `core/ts/grain-sdk/README.md`
   - Package-level overview with copyable commands.
8. `docs/human/sdk/impossible-misuse.md`
   - Human-readable reject-path summary.
9. `docs/human/sdk/errors.md`
   - Human-readable error contract.
10. `core/ts/grain-sdk/src/*`
   - Implementation modules.

## Source-of-truth hierarchy for SDK decisions

1. `spec/NES-v0.1.md`
2. `spec/profiles/*`
3. `conformance/vectors/*`
4. `core/ts/grain-ts-core/src/*` (shared TS protocol engine behavior)
5. `runner/typescript/src/*` (runner harness and compatibility surface)
6. `core/ts/grain-sdk/src/*` (orchestration only)
7. `docs/llm/*` (maintainer maps, sync rules, and indexes)
8. `docs/human/sdk/*` (explanatory, not normative)

If SDK behavior diverges from protocol vectors, treat it as a bug in SDK and update the matching docs and tests in the same change.
