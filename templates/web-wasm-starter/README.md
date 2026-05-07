# Grain Web WASM Starter

Minimal browser starter for the public Grain scanner path:

1. Load a local trust anchor bundle.
2. Scan with an injected camera adapter or paste a GR1 string.
3. Preview through the public WASM client workflow.
4. Accept only after the preview is verified.
5. Persist the opaque client snapshot behind IndexedDB browser storage.
6. Restore the snapshot on page load.
7. List accepted scans from the public client state.
8. Export a sync bundle at the app boundary.

The starter leaves routing, styling, service workers, hosting, and storage
sealing to the application. IndexedDB is the default browser persistence
adapter here; stronger custody requires a native or hardware-backed adapter.
Grain owns preview, accept, list, export, diagnostics, idempotency, and the
opaque snapshot format.

## Check

```bash
scripts/sdk/check_starter_templates.sh
```
