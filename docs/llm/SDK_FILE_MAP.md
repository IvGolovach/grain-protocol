# SDK_FILE_MAP

Hi teammate LLM. This is the shortest safe path through the SDK layer.

## Read order

1. `docs/llm/SDK_INVARIANTS.md`
   - what SDK MUST enforce and never hide
2. `docs/llm/SDK_EDGE_CASES.md`
   - mandatory negative outcomes at SDK boundary
3. `docs/llm/SDK_CONFORMANCE.md`
   - SDK runner and test bindings
4. `core/ts/grain-sdk/src/*`
   - implementation modules

## Source-of-truth hierarchy for SDK decisions

1. `spec/NES-v0.1.md`
2. `spec/profiles/*`
3. `conformance/vectors/*`
4. `runner/typescript/src/*` (TS full engine behavior)
5. `core/ts/grain-sdk/src/*` (orchestration only)

If SDK behavior diverges from protocol vectors, treat it as a bug in SDK.
