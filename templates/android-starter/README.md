# Grain Android Starter

Minimal Kotlin/JVM starter for the public Grain scanner path:

1. Load an app-bundled trust anchor bundle.
2. Scan with a camera adapter or paste a GR1 string.
3. Preview through `examples/android-scanner.ScannerController`.
4. Accept only after the preview is verified.
5. Persist the opaque client snapshot through an injected persistence boundary.
6. Restore the snapshot on startup.
7. List accepted scans from the public scanner state.
8. Export a sync bundle for app-owned sharing.

The starter keeps Android-specific choices outside Grain: UI framework, camera
library, sealed storage, lifecycle ownership, and share sheet wiring. Grain owns
preview, accept, list, export, diagnostics, idempotency, and the opaque snapshot
format.

## Check

```bash
scripts/sdk/check_starter_templates.sh
```
