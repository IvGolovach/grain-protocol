# Grain iOS Scanner Shell

SwiftUI reference shell over the portable `sdk/swift` client package.

It accepts a pasted GR1/QR payload string and explicit trust public key, calls
`GrainClient.scanPreview`, enables accept only after a verified preview, then
calls `GrainClient.scanAccept`.

Camera capture, QR decoding, Keychain-backed storage, and iOS binary packaging
are intentionally outside this shell. Add them as adapters that produce a GR1
string and pass it into the same workflow.

## Check

```bash
cargo build --manifest-path core/rust/Cargo.toml -p grain-client-core
swift run --package-path examples/ios-scanner GrainIOSScannerSmoke
```
