# Grain iOS Reference App

This is the source-level SwiftUI reference app for the local Grain scanner
workflow. It runs without a paid Apple Developer Program account and uses only
public SDK/example modules:

- `GrainIOSScanner` for the scanner shell and QR handoff
- `GrainClientIOSAdapters` for opaque snapshot persistence
- bundled local trust material in the `sdk/trust` fixture shape

The app owns the platform edges: bundled trust, Keychain-backed snapshot storage,
toolbar actions, and optional demo QR injection. Grain still owns preview,
accept, diagnostics, idempotency, and the client store snapshot format.

The visible flow is:

1. Scan the bundled demo QR or paste a GR1 string.
2. Preview the handoff through the public SDK.
3. Accept only after the preview verifies.
4. Save into local snapshot persistence.
5. Export/debug counts and diagnostics only.

The executable target is intentionally source-level. For a local iPhone run, open
the package from Xcode, use an ordinary Apple ID with automatic signing, and run
on your device. This path does not require TestFlight, App Store distribution, Ad
Hoc distribution, registry credentials, signing secrets, or a paid Apple
Developer Program account. Projects that need production distribution can use
`GrainReferenceScannerRootView(configuration:)` as their root view while adding
their own signing, entitlements, camera session UI, and release process outside
this example.

## Check

```bash
scripts/sdk/check_ios_reference_app.sh
```

That check builds the SwiftUI app package, runs the smoke executable, and rejects
raw protocol/FFI calls, hidden trust discovery, secret-like logging, and UI paths
that display export or trust material instead of counts and diagnostics.
