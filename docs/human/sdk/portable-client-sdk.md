# Portable Client SDK

This page is for camera-first apps: iPhone, Android, glasses, robots, and future devices that scan Grain QR payloads and store accepted data.

The direction is Rust core plus generated platform SDKs.

## Shape

1. `core/rust/grain-core` owns protocol bytes, QR decode, COSE verification, and canonical diagnostics.
2. `core/rust/grain-client-core` owns developer-facing client workflows.
3. Generated Swift/Kotlin/WASM/device SDKs bind `grain-client-core`.
4. Apps call small workflow APIs instead of composing protocol internals.

## Current implemented slice

The first portable workflow is scan preview:

- valid scan with explicit valid trust -> `Verified`
- valid scan without trust -> `Untrusted`
- malformed scan, malformed trust, or failed verification -> `Rejected`

This lets a client show or stage a scan without pretending it is trusted.

## Client workflow conformance

Client workflow fixtures live under `sdk/workflows/**`. They are not protocol vectors. They define the app-facing workflow contract that generated SDKs must expose through public APIs.

The first fixture set covers `scan_preview`:

- valid scan plus valid trust -> `Verified`
- valid scan without trust -> `Untrusted`
- malformed scan -> `Rejected`
- valid scan plus malformed trust -> `Rejected`
- valid scan plus wrong trust key -> `Rejected`

Every scan-preview fixture expects no local storage mutation. Durable writes start with the later `scan_accept` workflow.

## Next additive slices

- `scan_accept`: verified scan plus atomic local persistence.
- Generated Swift package over the Rust client core.
- Generated Kotlin package over the same Rust client core.
- WASM/mobile-web binding over the same contract.
- Client scenario fixtures that every generated SDK must pass.

## Rule of thumb

Generated SDKs should expose product workflows: preview a scan, accept a scan, list saved objects, export evidence. They should not expose raw QR/COSE runner operations as the main app API.
