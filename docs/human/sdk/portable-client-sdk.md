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

The iOS adapter pack is now present in the Swift package:

- `GrainClientIOSAdapters` provides `GrainSnapshotPersistence`,
  `GrainSnapshotCoordinator`, deterministic file-backed persistence, and a
  Keychain-backed persistence implementation behind the same opaque
  `snapshotB64` contract
- `examples/ios-scanner` wires camera/injected GR1 payloads through
  `trustAnchorID` plus `GrainTrustProvider`, never raw trust input in the
  production preview/accept path
- the iOS smoke proves preview, accept, duplicate accept, restore-after-restart,
  and blank/unknown trust-anchor rejection through public SDK APIs

This is still an adapter pack and reference shell, not App Store packaging or
live AVFoundation session automation.

The Android adapter pack is now present in the Kotlin package:

- `sdk/kotlin` builds with Gradle/Kotlin JVM tooling
- `dev.grain.android` provides `GrainSnapshotPersistence`,
  `GrainSnapshotCoordinator`, deterministic file-backed persistence, and a
  Keystore-ready encrypted persistence boundary behind the same opaque
  `snapshotB64` contract
- `examples/android-scanner` wires camera/injected GR1 payloads through
  `trustAnchorId` plus `GrainTrustProvider`, never raw trust input in the
  production preview/accept path
- the Android smoke proves preview, accept, duplicate accept,
  restore-after-restart, and blank/unknown trust-anchor rejection through public
  SDK APIs
- `scripts/sdk/check_kotlin_package.sh` regenerates the Kotlin binding, rebuilds Rust client-core, runs the shared workflow fixtures through Kotlin, and fails if generated sources drift

This proves the Android-facing package shape. It is not a Play Store Android app
yet and it does not introduce a device-bound Keystore cipher, live CameraX
session automation, or platform trust lookup.

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

They were introduced as paste-first shells. Camera capture stays as a separate adapter layer so the scanner UI can remain thin and the SDK can keep owning validation.

The first camera adapter slice is now present:

- iOS has a deterministic camera payload adapter and an AVFoundation QR metadata adapter that feed the scanner shell
- Android/Kotlin has a CameraX-style frame adapter with an injected QR decoder that feeds the scanner shell
- WASM/browser has a `getUserMedia` camera adapter with an injected QR decoder that feeds the scanner shell

These adapters still do not own protocol semantics. They only turn platform camera output into a GR1 string and pass it to the same SDK workflow path. QR decoder package choice, platform-backed storage, production app packaging, and device/browser automation suites remain later hardening work.

The identity, device lifecycle, pairing, and sync slice is now present:

- `grain-client-core` can create/export/import a portable identity bundle
- device authorization keys can be added, activated, revoked, and reported through `client_lifecycle`
- pairing envelopes move an identity bundle through an app-controlled transfer channel and are idempotent on replay
- sync bundles carry identity, accepted scans, and lifecycle events across clients with atomic import semantics
- Swift, Kotlin, and WASM wrappers expose the same workflow methods through their public `GrainClient` APIs

This is still a portable SDK core, not final production key custody. iOS now has
the first native adapter boundary; Android, WASM, and future devices should get
the same shape in later slices.

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

The lifecycle fixture sets now also cover:

- `device_lifecycle`: root identity creation, device add/activate/revoke, and lifecycle counts
- `pairing`: create/preview/accept/replay of an app-transferred pairing envelope
- `sync_bundle`: export/import/replay of identity, accepted scans, and lifecycle events

## Rule of thumb

Generated SDKs should expose product workflows: preview a scan, accept a scan, manage device lifecycle, pair a client, sync local state, list saved objects, export evidence. They should not expose raw QR/COSE runner operations as the main app API.
