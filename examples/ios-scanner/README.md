# Grain iOS Scanner Shell

SwiftUI reference shell over the portable `sdk/swift` client package.

It accepts a pasted or camera-adapter-provided GR1/QR payload string plus an
explicit trust anchor ID, resolves trust through `GrainTrustProvider`, calls
provider-backed `GrainClient.scanPreview`, enables accept only after a verified
preview, then calls provider-backed `GrainClient.scanAccept`.

The shell also has a minimal `prepareLocalIdentity` hook that calls
`GrainClient.createRootIdentity`, `addDeviceKey`, and `clientLifecycle` through
the public SDK API. It does not parse or mutate identity bundles itself.

Durable state stays behind `GrainClientIOSAdapters`: the shell persists the
opaque `snapshotB64` returned by `exportStoreSnapshot` and restores it with
`restoreStoreSnapshot`. File-backed persistence keeps the smoke deterministic;
production apps can swap the same boundary for Keychain-backed persistence
without moving protocol semantics into UI code.

`CameraScanAdapter` is intentionally thin. The included deterministic adapter is
used by the smoke check, and `AVFoundationQRCodeMetadataAdapter` maps
AVFoundation QR metadata objects into the same GR1 string path. Session
management and iOS binary packaging stay outside this shell.

The smoke check proves preview, accept, duplicate accept, restore-after-restart,
and blank/unknown trust-anchor rejection without network trust discovery or
fallback issuer material.

## Check

```bash
cargo build --manifest-path core/rust/Cargo.toml -p grain-client-core
swift run --package-path examples/ios-scanner GrainIOSScannerSmoke
```
