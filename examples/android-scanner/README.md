# Grain Android Scanner Shell

Kotlin reference shell over the portable `sdk/kotlin` client package.

It is a paste-first scanner state model shaped for an Android `ViewModel` or
Compose screen. The shell calls `GrainClient.scanPreview`, enables accept only
after a verified preview, then calls `GrainClient.scanAccept`.

CameraX, QR decoding, Android Keystore-backed storage, and device tests are
intentionally outside this shell. Add them as adapters that produce a GR1
string and pass it into the same workflow.

## Check

```bash
cargo build --manifest-path core/rust/Cargo.toml -p grain-client-core
sdk/kotlin/gradlew -p examples/android-scanner check
```
