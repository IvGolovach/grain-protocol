# Grain Android Reference App

This is the Kotlin/JVM reference app entrypoint for the Grain scanner workflow.
It is source-level on purpose: no Android Studio project, Gradle wrapper, Play
Console, Android signing, store packaging, or private monorepo wiring is needed
to run the local flow.

It uses only public SDK/example modules:

- `android-scanner` for QR handoff, scanner state, local trust loading, and
  accept/export actions
- `sdk/kotlin` for `GrainClient`
- `dev.grain.android` snapshot persistence adapters for opaque client snapshots
- bundled local trust material in the `sdk/trust` fixture shape

The reference app owns the platform edges: app-bundled trust, snapshot
persistence injection, demo QR injection, manual paste input, and
lifecycle-friendly session startup/shutdown. Grain still owns preview, accept,
diagnostics, idempotency, sync export, and the client store snapshot format.

Android projects can keep `GrainReferenceScannerSession` behind a `ViewModel`
or call the JVM facade directly while wiring CameraX, Compose, encrypted byte
storage, and Android Keystore keys in the real app shell.

The local reference flow is:

1. Start the session and prepare local identity.
2. Load either the bundled demo QR or a manually pasted GR1 string.
3. Preview through the public scanner workflow.
4. Enable accept only after a verified preview.
5. Accept and persist app-owned local state.
6. Restart and restore the saved accepted-scan state.
7. Export a summary with status, counts, and diagnostics only.

The app facade exposes `runDemo`, `runManual`, and `restore` helpers for the
same flow. Export summaries intentionally expose status and counts, not raw
snapshot, trust, or sync payload material.

## Check

```bash
scripts/sdk/check_android_reference_app.sh
```

That check builds the Kotlin package, runs the JVM smoke executable, and rejects
raw protocol/FFI calls, hidden trust discovery, raw export-payload exposure,
publication/signing wiring, and secret-like logging.
