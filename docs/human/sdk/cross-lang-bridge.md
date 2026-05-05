# Cross-Language Bridge Plan (SDK ↔ Core)

Goal: keep SDK deterministic against core outputs and prevent drift between languages and generated platform bindings.

## Binding rules

1. SDK runner executes protocol vectors through SDK boundary.
2. SDK must preserve core diagnostics (`GRAIN_ERR_*`, `NONCE_PROFILE_MISMATCH`, etc.).
3. SDK-only guards use `SDK_ERR_*` and must not shadow core codes.
4. Generated platform SDKs bind client workflow DTOs, not raw QR/COSE runner internals.
5. Platform storage/trust adapters must pass Rust contract tests before being treated as conformant.

## Comparison surfaces

- verdict: PASS/REJECT
- `diag` codes
- operation outputs (`out`)
- deterministic helper outputs (for example evidence hash)
- client workflow fixture status/diagnostics/storage mutation
- storage adapter behavior: deterministic order, idempotent re-put, rollback boundary
- trust adapter behavior: no anchor, missing anchor, malformed anchor, valid anchor

## Required checks

- `core/ts/grain-sdk/scripts/run-protocol-suite.ts`
- `core/ts/grain-sdk/scripts/test-sdk-invariants.ts`
- `cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core`
- `cargo build --manifest-path core/rust/Cargo.toml -p uniffi-bindgen`
- `scripts/sdk/check_generated_bindings.sh`
- `python3 tools/ci/check_client_workflow_fixtures.py`
- CI `ts-full` context includes both checks.

## Drift response

If SDK output diverges from core vectors:

1. treat as SDK bug first,
2. add/adjust SDK invariant test if boundary behavior was missing,
3. only escalate to protocol/conformance change with ADR when vector contract is truly ambiguous.

If generated platform SDK output diverges from `grain-client-core` workflow fixtures or adapter contract tests, treat it as platform SDK drift first. Passing protocol vectors alone does not make Swift, Kotlin, WASM, or future device bindings client-workflow conformant.

If UniFFI generation or expected public symbols drift, treat that as a generated-binding harness failure first, not a protocol issue.
