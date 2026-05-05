# Grain Android Scanner Shell

Kotlin reference shell over the portable `sdk/kotlin` client package.

It is a paste-first and camera-adapter-ready scanner state model shaped for an
Android `ViewModel` or Compose screen. The shell calls `GrainClient.scanPreview`,
enables accept only after a verified preview, then calls `GrainClient.scanAccept`.
It also includes a minimal local identity preparation hook through public
`GrainClient` lifecycle methods; bundle parsing and lifecycle mutation stay in
the SDK.

`CameraScanAdapter` keeps CameraX and QR decoder choices outside protocol
semantics. `CameraXFrameScanAdapter` accepts an injected frame decoder, maps a
decoded QR string into the same scanner workflow, and is smoke-tested without a
device. Android Keystore-backed storage and instrumented device tests stay
outside this shell.

## Check

```bash
cargo build --manifest-path core/rust/Cargo.toml -p grain-client-core
sdk/kotlin/gradlew -p examples/android-scanner check
```
