# Cross-Language Bridge Plan (SDK ↔ Core)

Goal: keep SDK deterministic against core outputs and prevent drift between languages and generated platform bindings.

## Binding rules

1. SDK runner executes protocol vectors through SDK boundary.
2. SDK must preserve core diagnostics (`GRAIN_ERR_*`, `NONCE_PROFILE_MISMATCH`, etc.).
3. SDK-only guards use `SDK_ERR_*` and must not shadow core codes.
4. Generated platform SDKs bind client workflow DTOs, not raw QR/COSE runner internals.
5. Platform storage/trust adapters must pass Rust contract tests before being treated as conformant.
6. Platform packages must pass `sdk/workflows` through their public wrapper APIs, not just through generated FFI symbols.

## Comparison surfaces

- verdict: PASS/REJECT
- `diag` codes
- operation outputs (`out`)
- deterministic helper outputs (for example evidence hash)
- client workflow fixture status/diagnostics/storage mutation
- storage adapter behavior: deterministic order, idempotent re-put, rollback boundary
- trust adapter behavior: no anchor, missing/blank anchor, unknown anchor,
  malformed anchor material, valid anchor, and no default/network fallback
- Swift package wrapper behavior: typed workflow statuses, no raw QR/COSE runner APIs, and public scan fixtures passing through `GrainClient`
- Kotlin package wrapper behavior: typed workflow statuses, no raw QR/COSE runner APIs, and public scan fixtures passing through `GrainClient`
- WASM/mobile-web wrapper behavior: typed workflow statuses, no raw QR/COSE runner APIs, and public scan fixtures passing through `GrainClient`

## Required checks

- `core/ts/grain-sdk/scripts/run-protocol-suite.ts`
- `core/ts/grain-sdk/scripts/test-sdk-invariants.ts`
- `cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core`
- `cargo build --manifest-path core/rust/Cargo.toml -p uniffi-bindgen`
- `scripts/sdk/check_generated_bindings.sh`
- `scripts/sdk/check_swift_package.sh`
- `scripts/sdk/check_kotlin_package.sh`
- `scripts/sdk/check_wasm_package.sh`
- `python3 tools/ci/check_sdk_trust_provider_boundary.py`
- `python3 tools/ci/check_client_workflow_fixtures.py`
- CI `ts-full` keeps the TypeScript SDK and client workflow checks wired into the required repository lane; platform package checks may be added as their own lane as the generated SDKs become release artifacts.

## Drift response

If SDK output diverges from core vectors:

1. treat as SDK bug first,
2. add/adjust SDK invariant test if boundary behavior was missing,
3. only escalate to protocol/conformance change with ADR when vector contract is truly ambiguous.

If generated platform SDK output diverges from `grain-client-core` workflow fixtures or adapter contract tests, treat it as platform SDK drift first. Passing protocol vectors alone does not make Swift, Kotlin, WASM, or future device bindings client-workflow conformant.

If UniFFI generation or expected public symbols drift, treat that as a generated-binding harness failure first, not a protocol issue.

If the Swift wrapper drifts from generated binding output, treat it as a Swift package failure first. Regenerate with `scripts/sdk/sync_swift_bindings.sh`, then run `scripts/sdk/check_swift_package.sh`; do not patch checked-in generated Swift by hand.

If the Kotlin wrapper drifts from generated binding output, treat it as a Kotlin package failure first. Regenerate with `scripts/sdk/sync_kotlin_bindings.sh`, then run `scripts/sdk/check_kotlin_package.sh`; do not patch checked-in generated Kotlin by hand.

If the WASM/mobile-web wrapper drifts from the client workflow ABI, treat it as a WASM package failure first. Run `scripts/sdk/check_wasm_package.sh`; do not patch browser-facing glue around a failing Rust workflow export.
