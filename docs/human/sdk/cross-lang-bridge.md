# Cross-Language Bridge Plan (SDK ↔ Core)

Goal: keep SDK deterministic against core outputs and prevent drift between languages.

## Binding rules

1. SDK runner executes protocol vectors through SDK boundary.
2. SDK must preserve core diagnostics (`GRAIN_ERR_*`, `NONCE_PROFILE_MISMATCH`, etc.).
3. SDK-only guards use `SDK_ERR_*` and must not shadow core codes.

## Comparison surfaces

- verdict: PASS/REJECT
- `diag` codes
- operation outputs (`out`)
- deterministic helper outputs (for example evidence hash)

## Required checks

- `core/ts/grain-sdk/scripts/run-protocol-suite.ts`
- `core/ts/grain-sdk/scripts/test-sdk-invariants.ts`
- CI `ts-full` context includes both checks.

## Drift response

If SDK output diverges from core vectors:

1. treat as SDK bug first,
2. add/adjust SDK invariant test if boundary behavior was missing,
3. only escalate to protocol/conformance change with ADR when vector contract is truly ambiguous.
