# Grain Android Reference App

This is the minimal Kotlin/JVM reference app entrypoint for the Grain scanner
workflow. It is source-level on purpose: no Android Studio project, Gradle
wrapper, Play Store packaging, signing, or private monorepo wiring.

It uses only public SDK/example modules:

- `android-scanner` for QR handoff, scanner state, local trust loading, and
  accept/export actions
- `sdk/kotlin` for `GrainClient`
- `dev.grain.android` snapshot persistence adapters for opaque client snapshots
- bundled local trust material in the `sdk/trust` fixture shape

The reference app owns the platform edges: app-bundled trust, snapshot
persistence injection, demo QR injection, and lifecycle-friendly session
startup/shutdown. Grain still owns preview, accept, diagnostics, idempotency,
sync export, and the client store snapshot format.

Android projects can keep `GrainReferenceScannerSession` behind a `ViewModel`
or call `GrainAndroidReferenceApp.runDemo(configuration)` while wiring CameraX,
Compose, encrypted byte storage, and Android Keystore keys in the real app
shell.

## Check

```bash
scripts/sdk/check_android_reference_app.sh
```

That check builds the Kotlin package, runs the smoke executable, and rejects
raw protocol/FFI calls, hidden trust discovery, and secret-like logging.
