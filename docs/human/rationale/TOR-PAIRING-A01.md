# TOR-PAIRING-A01

Portable Pairing, Device Lifecycle, And Sync

Status: active, additive to TOR-SDK-A04

## Scope

This rationale covers the first portable lifecycle workflow slice for generated client SDKs.

Included:

- root identity creation and strict bundle import/export
- device key add, activate, revoke, and lifecycle reporting
- app-controlled pairing envelope preview/accept/replay
- sync bundle export/import/replay for identity, accepted scans, and lifecycle events
- shared workflow fixtures across Rust, Swift, Kotlin, and WASM

## Boundary

This is not a secure remote pairing protocol and not production platform key custody.

The current slice makes the SDK surface consistent and testable. Future platform adapters can put the same workflow boundary behind Keychain, Keystore, Secure Enclave, robot HSMs, or other device-specific storage without making app code own protocol parsing, bundle validation, rollback, or idempotency.

## Rules

- Rust client core owns bundle parsing, lifecycle mutation, pairing envelope validation, and sync import atomicity.
- Generated SDKs expose workflow APIs, not raw protocol runner operations.
- Pairing preview is pure.
- Pairing accept mutates only through the client store atomic boundary.
- Sync import rejects identity conflicts before partial writes.
- Repeated pairing accept and sync import are idempotent.

## Evidence

Executable proof lives in:

- `core/rust/grain-client-core/tests/identity_device_lifecycle.rs`
- `core/rust/grain-client-core/tests/pairing_sync_bundle.rs`
- `core/rust/grain-client-core/tests/client_workflow_fixtures.rs`
- `sdk/workflows/fixtures/device-lifecycle/*.json`
- `sdk/workflows/fixtures/pairing/*.json`
- `sdk/workflows/fixtures/sync-bundle/*.json`
- `scripts/sdk/check_swift_package.sh`
- `scripts/sdk/check_kotlin_package.sh`
- `scripts/sdk/check_wasm_package.sh`

## Acceptance Criteria

PASS requires:

1. Rust client-core tests pass.
2. Swift, Kotlin, and WASM public wrappers expose the expanded workflow surface.
3. Shared lifecycle fixtures pass through public SDK APIs.
4. Generated binding checks confirm identity/device/pairing/sync symbols and reject raw protocol APIs.
5. Docs and LLM maps list the new invariants and reject paths.

FAIL if:

- platform wrappers drift from Rust lifecycle semantics;
- bundle import or sync import can leave partial state;
- pairing replay duplicates state;
- any public SDK wrapper exposes QR/COSE/DAG-CBOR/protocol-runner internals as the app workflow API.
