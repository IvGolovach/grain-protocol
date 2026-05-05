# Grain WASM Scanner Shell

Browser/mobile-web reference shell over the portable `sdk/wasm` client package.

It accepts a pasted or camera-adapter-provided GR1/QR payload string and
explicit trust public key, calls `client.scanPreview`, enables accept only after
a verified preview, then calls `client.scanAccept`.

`createBrowserCameraAdapter` uses `getUserMedia` and an injected QR decoder. It
returns a GR1 string payload and passes that payload into the same scanner
workflow. IndexedDB persistence, service workers, and npm release packaging stay
outside this shell.

## Check

```bash
npm --prefix examples/wasm-scanner run check
npm --prefix examples/wasm-scanner run test:smoke
```
