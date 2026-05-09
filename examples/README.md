# Grain Examples

Reference examples show how applications should use the portable client SDKs
without owning protocol-critical QR, COSE, DAG-CBOR, trust, or persistence
semantics.

## Scanner Shells

- `ios-scanner`: SwiftUI shell over `sdk/swift`.
- `ios-reference-app`: minimal SwiftUI app entrypoint over `ios-scanner`,
  using bundled local trust and Keychain/file snapshot persistence.
- `android-scanner`: Kotlin shell over `sdk/kotlin`, shaped for Android app
  state and unit-testable outside a device.
- `android-reference-app`: minimal Kotlin app entrypoint over
  `android-scanner`, using bundled local trust and injected snapshot
  persistence without Android Studio or Play Store packaging.
- `wasm-scanner`: browser/mobile-web shell over `sdk/wasm`.

These shells start with paste/string input and now include thin camera adapter
boundaries. The adapter turns a camera frame into a GR1 string, then the same
SDK workflow validates, previews, accepts, and lists saved scans.

For a checkout-to-scan walkthrough, use
`scripts/sdk/run_local_scanner_flow.sh`, then
`docs/human/sdk/scan-quickstart.md` for the manual steps. The script generates a
signed local issuer QR, wraps the emitted public trust key in a local trust
anchor bundle, runs the scanner/reference app checks when platform prerequisites
are available, and writes a local report under ignored `artifacts/`.

For the no-paid-account reference app path, use
`docs/human/sdk/quickstart-ios-reference-app.md` for local Xcode plus an
ordinary Apple ID, or `docs/human/sdk/quickstart-android-reference-app.md` for
the local Gradle/JVM smoke. Those paths prove source-level reference apps. They
do not publish TestFlight, App Store, Play Console, npm, or Maven artifacts.

For source SDK artifacts handed to another developer, use
`docs/human/sdk/source-sdk-handoff.md` before running the scanner shells. It
keeps the Swift, Kotlin, WASM, generated binding snapshot, workflow contract,
and trust schema tied to one commit and states what is not published.

Production apps must still supply four app/device adapters around the shared
SDK workflow: camera or sensor input, local trust provider, protected snapshot
persistence, and encrypted/authenticated transfer or share channel for portable
identity, pairing, and sync artifacts.

## Check

```bash
scripts/sdk/run_local_scanner_flow.sh --strict
scripts/sdk/check_scanner_examples.sh
scripts/sdk/check_ios_reference_app.sh
scripts/sdk/check_android_reference_app.sh
```

The check builds the scanner shells with the platform SDK wrappers and rejects
raw protocol API exposure in example code.
