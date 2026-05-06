# Grain Examples

Reference examples show how applications should use the portable client SDKs
without owning protocol-critical QR, COSE, DAG-CBOR, trust, or persistence
semantics.

## Scanner Shells

- `ios-scanner`: SwiftUI shell over `sdk/swift`.
- `android-scanner`: Kotlin shell over `sdk/kotlin`, shaped for Android app
  state and unit-testable outside a device.
- `wasm-scanner`: browser/mobile-web shell over `sdk/wasm`.

These shells start with paste/string input and now include thin camera adapter
boundaries. The adapter turns a camera frame into a GR1 string, then the same
SDK workflow validates, previews, accepts, and lists saved scans.

For a checkout-to-scan walkthrough, use
`docs/human/sdk/scan-quickstart.md`. It shows how to generate a signed local
issuer QR, wrap the emitted public trust key in a local trust anchor bundle, and
feed a stable trust anchor ID into these shells.

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
scripts/sdk/check_scanner_examples.sh
```

The check builds the scanner shells with the platform SDK wrappers and rejects
raw protocol API exposure in example code.
