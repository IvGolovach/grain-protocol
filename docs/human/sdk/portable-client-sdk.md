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

This proves the shared facade can be generated reproducibly. The package slices below wrap it for Swift, Kotlin, and mobile-web clients.

The first platform package slice is now the Swift client package:

- `sdk/swift` builds with Swift Package Manager
- `GrainClient` exposes `scanPreview`, `scanAccept`, and `listAcceptedScans`
- Swift app code sees typed workflow statuses instead of raw QR/COSE internals
- `scripts/sdk/check_swift_package.sh` regenerates the Swift bindings, rebuilds Rust client-core, builds the Swift package, runs the shared workflow fixtures through Swift, and fails if generated sources drift

This proves the iOS-facing package shape. It is not an iOS scanner app yet and it does not introduce Keychain storage, camera capture, or platform trust lookup.

The next platform package slice is the Kotlin/JVM client package:

- `sdk/kotlin` builds with Gradle/Kotlin JVM tooling
- `GrainClient` exposes `scanPreview`, `scanAccept`, and `listAcceptedScans`
- Kotlin app code sees typed workflow statuses instead of raw QR/COSE internals
- `scripts/sdk/check_kotlin_package.sh` regenerates the Kotlin binding, rebuilds Rust client-core, runs the shared workflow fixtures through Kotlin, and fails if generated sources drift

This proves the Android-facing package shape. It is not an Android scanner app yet and it does not introduce Keystore storage, CameraX capture, or platform trust lookup.

The mobile-web package slice is now the WASM client package:

- `core/rust/grain-client-wasm` exports scan workflow operations over `grain-client-core`
- `sdk/wasm` exposes a small `GrainClient` web API over the WASM exports
- mobile-web app code sees typed workflow statuses instead of raw QR/COSE internals
- `scripts/sdk/check_wasm_package.sh` builds the WASM binding, loads it in Node, runs the shared workflow fixtures through the public web API, and fails on raw protocol API exposure

This proves the mobile-web package shape. It is not a camera scanner app yet and it does not introduce browser camera capture, IndexedDB persistence, service workers, or production npm release packaging.

The reference scanner-shell slice is now present:

- `examples/ios-scanner` provides a SwiftUI paste-first scanner shell over `sdk/swift`
- `examples/android-scanner` provides a Kotlin paste-first scanner shell over `sdk/kotlin`, shaped for Android state management and unit testing
- `examples/wasm-scanner` provides a browser/mobile-web paste-first scanner shell over `sdk/wasm`
- `scripts/sdk/check_scanner_examples.sh` builds and tests the shell examples and rejects raw protocol API exposure in example code

These shells prove that app code can stay thin: a camera adapter, paste box, robot sensor, or glasses frame reader produces a GR1 string, then the SDK owns preview, diagnostics, accept, and accepted-scan listing.

They are not camera integrations yet. AVFoundation, CameraX, browser camera capture, QR decoder dependency choice, platform-backed storage, and production app packaging are intentionally kept as the next adapter slice.

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

- Camera adapters for the reference scanner shells: iOS capture, Android CameraX, and browser camera capture should produce GR1 strings and then call the same SDK workflows.
- Client scenario fixtures that every generated SDK must pass.

## Rule of thumb

Generated SDKs should expose product workflows: preview a scan, accept a scan, list saved objects, export evidence. They should not expose raw QR/COSE runner operations as the main app API.
