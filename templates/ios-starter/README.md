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

## Check

```bash
scripts/sdk/check_starter_templates.sh
```
