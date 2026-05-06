# Grain iOS Scanner Shell

SwiftUI reference shell over the portable `sdk/swift` client package.

It accepts a pasted or camera-adapter-provided GR1/QR payload string plus an
explicit trust anchor ID, resolves trust through `GrainTrustProvider`, calls
provider-backed `GrainClient.scanPreview`, enables accept only after a verified
preview, then calls provider-backed `GrainClient.scanAccept`.

Trust anchors are loaded from the same versioned local bundle shape used by the
SDK workflow fixtures. Production apps pass their app-managed bundle JSON into
`ScannerShellModel`; the shell never discovers trust over the network and never
falls back to implicit issuer material.
The URL-based initializer accepts only local file URLs and rejects non-file
schemes before parsing.

The shell also has a minimal `prepareLocalIdentity` hook that calls
`GrainClient.createRootIdentity`, `addDeviceKey`, and `clientLifecycle` through
the public SDK API. It does not parse or mutate identity bundles itself.

Durable state stays behind `GrainClientIOSAdapters`: the shell persists the
opaque `snapshotB64` returned by `exportStoreSnapshot` and restores it with
`restoreStoreSnapshot`. File-backed persistence keeps the smoke deterministic;
production apps can use the built-in Keychain-backed initializer without moving
protocol semantics into UI code:

```swift
let model = try ScannerShellModel(
    keychainBackedTrustAnchorBundleURL: localTrustAnchorBundleURL,
    initialTrustAnchorID: "publisher:primary"
)
```

The view exposes the app flow as preview, accept, list, export, and restore.
Export returns the SDK sync bundle to the app/share layer while UI state keeps
only statuses and counts, not bundle or snapshot payloads.

`CameraScanAdapter` is intentionally thin. The included deterministic adapter is
used by the smoke check, and `AVFoundationQRCodeMetadataAdapter` maps
AVFoundation QR metadata objects into the same GR1 string path. Session
management and iOS binary packaging stay outside this shell.

The smoke check proves local trust-bundle loading, preview, accept, accepted
scan listing, sync export, duplicate accept, restore-after-restart, and
blank/unknown trust-anchor rejection without network trust discovery or fallback
issuer material.

## Try A Generated Issuer QR

Use `docs/human/sdk/scan-quickstart.md` to generate `issuer-output.json`,
`qr-string.txt`, and `local-trust-bundle.json`. The production initializer takes
the local trust bundle URL and a stable trust anchor ID:

```swift
let model = try ScannerShellModel(
    keychainBackedTrustAnchorBundleURL: localTrustAnchorBundleURL,
    initialTrustAnchorID: "publisher:primary"
)
```

Pass the generated `qr_string` through the paste path or a `CameraScanAdapter`.
The shell should preview with `Verified`, enable accept, persist the opaque
snapshot, and restore accepted-scan state without exposing raw bundle payloads
in UI state.

## Check

```bash
cargo build --manifest-path core/rust/Cargo.toml -p grain-client-core
swift run --package-path examples/ios-scanner GrainIOSScannerSmoke
```
