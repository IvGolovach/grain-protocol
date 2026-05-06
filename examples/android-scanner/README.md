# Grain Android Scanner Shell

Kotlin reference shell over the portable `sdk/kotlin` client package.

It is a paste-first and camera-adapter-ready scanner state model shaped for an
Android `ViewModel` or Compose screen. The shell calls `GrainClient.scanPreview`,
using an explicit trust anchor ID plus `GrainTrustProvider`, enables accept only
after a verified preview, then calls provider-backed `GrainClient.scanAccept`.
Local trust bundle helpers load app-managed JSON from a `Path`; the shell does
not perform URL, platform CA, or network trust discovery. It also includes a
minimal local identity preparation hook through public `GrainClient` lifecycle
methods; bundle parsing and lifecycle mutation stay in the SDK.

Durable state stays behind `dev.grain.android`: the shell persists the opaque
`snapshotB64` returned by `exportStoreSnapshot` and restores it with
`restoreStoreSnapshot`. File-backed persistence keeps the smoke deterministic;
production Android apps can swap the same boundary for Keystore-backed
encryption by providing an Android Keystore `SecretKey` to
`GrainAesGcmSnapshotCipher` and a byte store.

`CameraScanAdapter` keeps CameraX and QR decoder choices outside protocol
semantics. `CameraXFrameScanAdapter` accepts an injected frame decoder, maps a
decoded QR string into the same scanner workflow, and is smoke-tested without a
device.

The smoke check proves local trust bundle loading, preview, accept,
accepted-scan listing, sync export status, duplicate accept,
restore-after-restart, and blank/unknown trust-anchor rejection without network
trust discovery, fallback issuer material, or accepted-record/snapshot writes
before verified accept. The controller returns sync export payloads to app code
but keeps UI state to statuses, counts, diagnostics, and scan IDs.

## Try A Generated Issuer QR

Use `docs/human/sdk/scan-quickstart.md` to generate `issuer-output.json`,
`qr-string.txt`, and `local-trust-bundle.json`. Load the trust bundle through
the scanner helper, keep `trustAnchorId = "publisher:primary"`, and feed the
generated `qr_string` through the paste path or `CameraScanAdapter`.

The expected app flow is preview `Verified`, accept, persist opaque
`snapshotB64`, restore accepted-scan state after restart, and keep raw bundle
payloads out of UI state and logs.

## Check

```bash
cargo build --manifest-path core/rust/Cargo.toml -p grain-client-core
sdk/kotlin/gradlew -p examples/android-scanner runAndroidParitySmoke
sdk/kotlin/gradlew -p examples/android-scanner check
```
