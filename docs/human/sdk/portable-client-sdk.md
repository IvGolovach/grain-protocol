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

The next implemented workflow is scan accept preparation:

- valid scan with explicit valid trust -> prepared accepted record
- prepared record includes deterministic `scan-sha256:<hex>` ID over verified COSE bytes
- missing trust, malformed trust, malformed scan, or failed verification -> `Rejected`
- no local storage mutation occurs in preparation

The durable workflow is scan accept:

- valid scan with explicit valid trust -> `Accepted` and exactly one persisted accepted scan record
- repeated same scan -> `AlreadyAccepted` and no duplicate record
- rejected scans -> no persisted record
- failed store mutation -> rollback to the pre-call state

The platform contract slice is now defined:

- storage adapters implement the same atomic, idempotent, deterministic listing behavior as `ClientStore`
- trust adapters return explicit public-key material or no material; Rust core does not perform hidden fallback or network trust lookup
- generated bindings use owned DTO values: strings, vectors, optional strings, and no borrowed Rust lifetimes

The generated-binding harness is now present:

- `grain-client-core` has UniFFI scaffolding over the stable workflow facade
- repo-local scripts generate Swift and Kotlin bindings into ignored or temporary directories
- the generation check verifies expected workflow symbols and rejects raw protocol/runner API exposure

This proves the shared facade can be generated reproducibly. It is not yet the Swift, Kotlin, or WASM SDK package.

## Client workflow conformance

Client workflow fixtures live under `sdk/workflows/**`. They are not protocol vectors. They define the app-facing workflow contract that generated SDKs must expose through public APIs.

The first fixture set covers `scan_preview`:

- valid scan plus valid trust -> `Verified`
- valid scan without trust -> `Untrusted`
- malformed scan -> `Rejected`
- valid scan plus malformed trust -> `Rejected`
- valid scan plus wrong trust key -> `Rejected`

Every scan-preview fixture expects no local storage mutation. `scan_accept_prepare` also performs no local storage mutation; durable writes start with the later `scan_accept` workflow.

The second fixture set covers `scan_accept`:

- valid scan plus valid trust -> `Accepted`, `accepted_scan_inserted`, one accepted record
- repeated valid scan -> `AlreadyAccepted`, no duplicate accepted record
- malformed scan -> `Rejected`, no store mutation, zero accepted records

## Next additive slices

- Generated Swift package over the Rust client core.
- Generated Kotlin package over the same Rust client core.
- WASM/mobile-web binding over the same contract.
- Client scenario fixtures that every generated SDK must pass.

## Rule of thumb

Generated SDKs should expose product workflows: preview a scan, accept a scan, list saved objects, export evidence. They should not expose raw QR/COSE runner operations as the main app API.
