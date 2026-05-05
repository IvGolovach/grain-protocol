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

## Check

```bash
scripts/sdk/check_scanner_examples.sh
```

The check builds the scanner shells with the platform SDK wrappers and rejects
raw protocol API exposure in example code.
