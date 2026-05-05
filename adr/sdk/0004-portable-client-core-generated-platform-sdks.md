# ADR 0004: Portable Client Core & Generated Platform SDKs (TOR-SDK-A04)

Status: Accepted

Date: 2026-05-04

## Context

Grain already has strict protocol cores and a TypeScript SDK. Camera-first clients add a different pressure: iOS, Android, glasses, robots, and future devices should not each reimplement QR decode, COSE verification, trust handling, and persistence workflow rules.

If every platform owns those details separately, the protocol stays correct in the repo but becomes easy to misuse in products.

## Decision

1. Add a portable Rust client-core crate at `core/rust/grain-client-core`.
2. Keep the crate workflow-shaped, not runner-shaped:
   - app developers call scan-oriented APIs,
   - generated platform SDKs bind those APIs,
   - low-level protocol primitives remain inside `grain-core`.
3. Start with `scan_preview(qr_string, trust_pub_b64)`:
   - valid scan + explicit valid trust -> `Verified`
   - valid scan + no trust -> `Untrusted`
   - malformed scan/trust/signature -> `Rejected` with deterministic diagnostics
4. Preserve existing protocol and SDK boundaries:
   - no frozen-core semantic change
   - no hidden trust fallback
   - no diagnostic renaming for core failures
   - SDK-only failures stay in the `SDK_ERR_*` namespace
5. Treat Swift, Kotlin, WASM, and future device SDKs as generated surfaces over this Rust client core. Those generated packages should expose workflow APIs such as scan preview and scan accept, not raw COSE/QR internals.
6. The Swift package starts as a thin generated-binding wrapper:
   - SwiftPM builds against the Rust client-core native library.
   - Public app code calls `GrainClient.scanPreview`, `scanAccept`, and `listAcceptedScans`.
   - Shared `sdk/workflows` fixtures run through the public Swift API.
   - Platform-specific camera, Keychain, sync, and trust-store adapters remain later slices.

## Consequences

- The first platform SDK slice can be tested once in Rust, generated through UniFFI, and checked again through the Swift package.
- Future iOS/Android SDK work has a stable place to bind from.
- `scan_accept` and persistent client storage use SDK atomic-mutation rules before platform packages expose saved scans.
- The protocol conformance vectors remain the trust anchor for bytes and diagnostics.

## Invariants touched

- `SDK-INV-0010` (transport decode/verify separation and explicit trust)
- `SDK-INV-0014` (strict base64 validation on trust material)
- `SDK-INV-0015` (portable client scan preview contract)
- `SDK-INV-0017` (portable client scan accept and atomic storage)
- `SDK-INV-0019` (generated binding harness)
- `SDK-INV-0020` (Swift client package fixture parity)
