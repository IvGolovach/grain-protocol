# Grain WASM Scanner Shell

Browser/mobile-web reference shell over the portable `sdk/wasm` client package.

It accepts a pasted or camera-adapter-provided GR1/QR payload string and an
explicit trust anchor ID, resolves trust through an injected
`GrainTrustProvider`, calls `client.scanPreviewWithTrustProvider`, enables
accept only after a verified preview, then calls
`client.scanAcceptWithTrustProvider`.
It also includes a minimal local identity preparation hook through public
`client.createRootIdentity`, `client.addDeviceKey`, and `client.clientLifecycle`
methods; bundle parsing and lifecycle mutation stay in the SDK.

`createBrowserCameraAdapter` uses `getUserMedia` and an injected QR decoder. It
returns a GR1 string payload and passes that payload into the same scanner
workflow. `GrainIndexedDBSnapshotPersistence` can restore the opaque
`snapshotB64` on startup and persist it after device setup or accepted scans.
Service workers and production npm release packaging stay outside this shell.

## Try A Generated Issuer QR

Use `docs/human/sdk/scan-quickstart.md` to generate `issuer-output.json`,
`qr-string.txt`, and `local-trust-bundle.json`. Load that bundle into the
browser trust provider, pass `trustAnchorId = "publisher:primary"`, and feed the
generated `qr_string` through paste or `createBrowserCameraAdapter`.

IndexedDB persistence is an example storage boundary, not a hardware custody
claim. Production browser apps should add app-controlled sealing around stored
snapshots.

## Check

```bash
npm --prefix examples/wasm-scanner run check
npm --prefix examples/wasm-scanner run test:smoke
```
