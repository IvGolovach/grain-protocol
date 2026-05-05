# Grain iOS Scanner Shell

SwiftUI reference shell over the portable `sdk/swift` client package.

It accepts a pasted or camera-adapter-provided GR1/QR payload string and explicit
trust public key, calls `GrainClient.scanPreview`, enables accept only after a
verified preview, then calls `GrainClient.scanAccept`.

`CameraScanAdapter` is intentionally thin. The included deterministic adapter is
used by the smoke check, and `AVFoundationQRCodeMetadataAdapter` maps
AVFoundation QR metadata objects into the same GR1 string path. Session
management, Keychain-backed storage, and iOS binary packaging stay outside this
shell.

## Check

```bash
cargo build --manifest-path core/rust/Cargo.toml -p grain-client-core
swift run --package-path examples/ios-scanner GrainIOSScannerSmoke
```
