# Android Reference App Quickstart

This path lets a developer run the Grain Android reference app logic locally
with Gradle and the JVM. It does not require Play Console, Android signing, a
store track, or release credentials.

It proves source-level app integration: local trust loading, demo or manual scan
input, preview, accept, saved list restore, and export/debug status through the
public Kotlin SDK/example modules.

## What You Need

- JDK 17
- Rust toolchain for `grain-client-core`
- the repo checkout
- the checked-in Gradle wrapper under `sdk/kotlin`

No Play Console account, upload key, Android signing certificate, or device farm
is required for the local Gradle/JVM smoke.

## Command Line Smoke

From the repo root:

```bash
scripts/sdk/check_android_reference_app.sh
```

That command builds `grain-client-core`, runs the Android reference app Gradle
check, runs the smoke executable, and rejects raw protocol/FFI calls, hidden
trust lookup, and secret-like logging.

For the full SDK platform gate on a prepared machine:

```bash
scripts/sdk/verify_all_sdks.sh --strict --out-dir artifacts/sdk-verify-local-reference
```

## Happy Path

The local smoke exercises the same app states a real Android shell should keep:

1. start the reference session
2. load the bundled demo QR or pass a manual `GR1:` string
3. preview through the public scanner controller
4. accept only after a verified preview exists
5. persist and restore opaque snapshot state
6. list accepted scan IDs
7. export only status, counts, and diagnostics

The reference app is intentionally JVM-first so it can run without Android
Studio or an emulator. A production Android app can place
`GrainReferenceScannerSession` behind a `ViewModel`, wire CameraX as the scan
input adapter, and use Android Keystore-backed storage for snapshot bytes.

## Where To Customize

The Android app layer owns:

- CameraX, manual paste, NFC, robot, or other input that returns a `GR1:` string
- app-packaged or device-managed local trust bundle selection
- encrypted byte storage for opaque `snapshotB64`
- lifecycle and UI state
- export/share channels

Grain owns parsing, trust verification, diagnostics, accept/idempotency, restore
semantics, snapshot format, pairing, and sync workflow behavior.

## Boundary

This quickstart is not Play Store readiness. It does not create an APK/AAB,
upload to Play Console, prove signing-key custody, certify CameraX automation,
or publish Maven artifacts.
