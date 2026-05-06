# Grain iOS Reference App

This is the minimal SwiftUI app entrypoint for the Grain scanner workflow. It
uses only public SDK/example modules:

- `GrainIOSScanner` for the scanner shell and QR handoff
- `GrainClientIOSAdapters` for opaque snapshot persistence
- bundled local trust material in the `sdk/trust` fixture shape

The app owns the platform edges: bundled trust, Keychain-backed snapshot storage,
toolbar actions, and optional demo QR injection. Grain still owns preview,
accept, diagnostics, idempotency, and the client store snapshot format.

The executable target is intentionally source-level. iPhone projects can use
`GrainReferenceScannerRootView(configuration:)` as their root view or keep this
package as a local SwiftPM reference while adding app signing, entitlements, and
camera session UI in Xcode.

## Check

```bash
scripts/sdk/check_ios_reference_app.sh
```

That check builds the SwiftUI app package, runs the smoke executable, and rejects
raw protocol/FFI calls, hidden trust discovery, and secret-like logging.
