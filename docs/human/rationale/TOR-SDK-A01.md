# TOR-SDK-A01

Grain SDK — Strict App-Facing Surface

Status: active and RC-discipline compatible

## Scope

The SDK layer provides strict orchestration on top of frozen protocol/core semantics.

Included modules:

- event lifecycle helpers
- identity/key lifecycle
- E2E + manifest primitives
- transport toolkit (GR1 + deterministic bundle import/export)
- canonicalization toolkit + explain contract
- evidence bundle builder

## Hard boundaries

- no protocol semantic changes
- no soft default mode
- no hidden auto-repair
- no diagnostics translation of core errors

## Safety by construction

- typed wrappers in `core/ts/grain-sdk/src/primitives.ts`
- fail-closed guards (`SDK_ERR_*`)
- deterministic error metadata (`code/category/nes_ref/vector_refs`)
- strict suite executed through SDK runner

## Evidence and gates

CI includes:

- SDK protocol suite via SDK runner
- SDK invariant suite
- portability and evidence bundle checks

SDK evidence summary is included in CI evidence artifacts.

## Deliverables in tree

- `core/ts/grain-sdk/`
- `docs/human/sdk/start-here.md`
- `docs/human/sdk/overview.md`
- `docs/human/sdk/architecture.md`
- `docs/human/sdk/errors.md`
- `docs/human/sdk/impossible-misuse.md`
- `docs/llm/SDK_FILE_MAP.md`
- `docs/llm/SDK_INVARIANTS.md`
- `docs/llm/SDK_EDGE_CASES.md`
- `docs/llm/SDK_CONFORMANCE.md`
- `adr/sdk/0001-sdk-universal-primitives-layer.md`

## Acceptance criteria

PASS requires all:

1. SDK strict protocol suite pass (full vectors through SDK runner)
2. SDK invariants pass (misuse checks deterministic)
3. SDK preserves core diagnostics and adds only `SDK_ERR_*` for SDK guards
4. docs and LLM mappings are in sync with executable checks

FAIL if any:

- soft mode enabled by default
- hidden semantic rewrite
- non-deterministic error code behavior
- SDK boundary diverges from protocol suite expectations
