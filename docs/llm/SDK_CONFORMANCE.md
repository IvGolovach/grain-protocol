# SDK_CONFORMANCE

Hi teammate LLM. This file links SDK behavior to executable checks.

## Protocol suite through SDK

SDK runner path:
- `core/ts/grain-sdk/src/cli.ts`

Runner contract:
```bash
npm --prefix core/ts/grain-sdk run run:vector -- <vector.json>
```

Full protocol suite execution through SDK runner:
```bash
npm --prefix core/ts/grain-sdk run run:protocol-suite
```

## SDK-specific invariants suite

```bash
npm --prefix core/ts/grain-sdk run test:invariants
npm --prefix core/ts/grain-sdk-ai run test:boundary
```

Expected contract:
- pass when all SDK-INV checks succeed
- deterministic JSON summary with `total`, `failed`, and per-check status
- SDK invariants currently cover `SDK-INV-0001` through `SDK-INV-0020` and `SDK-AI-000` through `SDK-AI-007`

## Portable client core

Rust client workflow checks:

```bash
cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core
```

Expected contract:
- scan preview preserves explicit trust boundaries
- malformed scan/trust/signature paths reject deterministically
- valid scan without trust remains `Untrusted`, not `Verified`
- scan accept preparation requires explicit verified trust
- accepted scan preparation returns a deterministic `scan-sha256:<hex>` ID derived from verified COSE bytes
- scan accept preparation is pure and performs no storage mutation
- scan accept persists verified records inside an atomic store boundary
- rejected scan accept writes no records
- duplicate scan accept is idempotent
- failed or nested store mutations reject or roll back deterministically

## Client workflow fixtures

Workflow fixtures:
- `sdk/workflows/contract/client_workflow_v1.md`
- `sdk/workflows/contract/client_workflow_v1.schema.json`
- `sdk/workflows/fixtures/scan-accept/*.json`
- `sdk/workflows/fixtures/scan-preview/*.json`

Fixture validation:

```bash
python3 tools/ci/check_client_workflow_fixtures.py
cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core
```

Expected contract:
- `sdk/workflows/**` is client workflow conformance, not protocol conformance
- workflow fixtures may reference protocol vectors, but must not be consumed by the protocol runner
- generated Swift, Kotlin, WASM, and future device SDKs are client-workflow conformant only after they pass these fixtures through their public workflow APIs
- `scan_preview` fixtures currently cover verified, untrusted, malformed QR, malformed trust, and wrong trust-key paths
- every `scan_preview` fixture expects `store_mutation: "none"`
- `scan_accept` fixtures currently cover accepted persistence, duplicate-scan idempotency, and rejected no-write behavior
- every `scan_accept` fixture asserts `store_mutation` and `accepted_record_count`
- platform adapter contract tests cover deterministic storage listing, idempotent re-put, rollback at the repository boundary, no anchor, missing anchor, malformed anchor, and valid anchor
- FFI DTO contract tests keep binding-facing values owned and flat: strings, vectors, optional strings, no borrowed Rust lifetimes

Rust fixture execution must load these fixtures and compare them against the public `grain_client_core::scan_preview()` and `grain_client_core::scan_accept()` APIs.

## Generated binding harness

Generation check:

```bash
scripts/sdk/check_generated_bindings.sh
```

Expected contract:
- `grain-client-core` builds UniFFI scaffolding from `core/rust/grain-client-core/src/grain_client_core.udl`
- `core/rust/uniffi-bindgen` is the repo-local binding generator entrypoint
- Swift and Kotlin bindings can be generated into ignored or temporary output directories
- generated output contains the expected workflow symbols: preview, accept preparation, accept, listing, and binding-safe request DTOs
- generated output and UDL do not expose raw QR/COSE/DAG-CBOR/protocol-runner operations as app APIs
- the check leaves git status unchanged except for pre-existing unrelated local work

## Swift client package

Swift package check:

```bash
scripts/sdk/check_swift_package.sh
```

Expected contract:
- `scripts/sdk/sync_swift_bindings.sh` regenerates Swift binding sources from the checked-in UniFFI harness and updates only the tracked Swift binding files
- `cargo build --manifest-path core/rust/Cargo.toml -p grain-client-core` builds the native library linked by SwiftPM
- `swift build --package-path sdk/swift` builds the `GrainClient` package
- `swift run --package-path sdk/swift GrainClientFixtureRunner` executes scan-preview and scan-accept fixtures through the public Swift `GrainClient` API
- the package exposes workflow methods and typed Swift statuses, not raw QR/COSE/DAG-CBOR/protocol-runner APIs
- fixture references are constrained to `conformance/vectors/**`
- the check leaves git status unchanged except for pre-existing unrelated local work

Local note: some environments do not ship `XCTest` or Swift Testing modules. This repository uses an executable fixture runner for the Swift package lane so the same deterministic workflow proof works in that toolchain shape.

## Diagnostics contract

- Core diagnostics are preserved and not renamed.
- SDK-only diagnostics use `SDK_ERR_*` namespace.
- SDK import/transport boundaries reject malformed non-standard base64 deterministically.
- Portable generated SDKs bind workflow APIs and keep raw protocol operations out of the main app surface.
- AI boundary explain payload is deterministic and redacted by default.
- structured_v1 field typing must be explicit (profile table or explicit pointer maps).

## SDK no-network policy

```bash
python3 tools/ci/check_sdk_no_network.py
```

This is a hard gate. SDK core and the AI sidecar must stay vendor/network agnostic.

If this mapping drifts, report a blocking issue before proposing any semantic change.
