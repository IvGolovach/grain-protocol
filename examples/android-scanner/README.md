# Grain Android Scanner Shell

Kotlin reference shell over the portable `sdk/kotlin` client package.

It is a paste-first and camera-adapter-ready scanner state model shaped for an
Android `ViewModel` or Compose screen. The shell calls `GrainClient.scanPreview`,
using an explicit trust anchor ID plus `GrainTrustProvider`, enables accept only
after a verified preview, then calls provider-backed `GrainClient.scanAccept`.
It also includes a minimal local identity preparation hook through public
`GrainClient` lifecycle methods; bundle parsing and lifecycle mutation stay in
the SDK.

Durable state stays behind `dev.grain.android`: the shell persists the opaque
`snapshotB64` returned by `exportStoreSnapshot` and restores it with
`restoreStoreSnapshot`. File-backed persistence keeps the smoke deterministic;
production Android apps can swap the same boundary for Keystore-backed
encryption by providing a `GrainSnapshotCipher` and byte store.

`CameraScanAdapter` keeps CameraX and QR decoder choices outside protocol
semantics. `CameraXFrameScanAdapter` accepts an injected frame decoder, maps a
decoded QR string into the same scanner workflow, and is smoke-tested without a
device.

The smoke check proves preview, accept, duplicate accept, restore-after-restart,
and blank/unknown trust-anchor rejection without network trust discovery,
fallback issuer material, or accepted-record/snapshot writes before verified
accept.

## Check

```bash
cargo build --manifest-path core/rust/Cargo.toml -p grain-client-core
sdk/kotlin/gradlew -p examples/android-scanner check
```
