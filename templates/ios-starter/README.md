# Grain iOS Starter

Minimal SwiftPM starter for the public Grain scanner path:

1. Load an app-bundled trust anchor bundle.
2. Scan with a camera adapter or paste a GR1 string.
3. Preview through `GrainIOSScanner.ScannerShellModel`.
4. Accept only after the preview is verified.
5. Persist the opaque client snapshot through the iOS adapter boundary.
6. Restore the snapshot on launch.
7. List accepted scans from the public client state.
8. Export a sync bundle for app-owned sharing.

The starter is intentionally source-level. Add signing, entitlements, camera UI,
and app-specific storage policy in your application shell. Grain owns preview,
accept, list, export, diagnostics, idempotency, and the opaque snapshot format.

The package copies its `Resources` directory intact. `StarterResources` loads
the trust anchor JSON and sample QR from that subdirectory of `Bundle.module`,
so lookup works with both Swift Build (the default in Swift 6.4 / Xcode 27.1)
and the native SwiftPM build system. It does not search the source checkout or
fetch trust material from the network.

## Check

```bash
scripts/sdk/check_starter_templates.sh
```

The iOS smoke first checks the packaged sample QR and trust anchor, then verifies
preview, accept, persistence, restore, and duplicate-accept behavior. These checks
also run in `scripts/sdk/verify_all_sdks.sh --strict` and against extracted SDK
release packages.

On macOS, select full Xcode for this command when `xcode-select` points to the
standalone Command Line Tools:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  mise exec -- scripts/sdk/check_starter_templates.sh
```
