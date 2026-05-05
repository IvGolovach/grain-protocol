# Grain WASM Scanner Shell

Browser/mobile-web reference shell over the portable `sdk/wasm` client package.

It accepts a pasted or camera-adapter-provided GR1/QR payload string and
explicit trust public key, calls `client.scanPreview`, enables accept only after
a verified preview, then calls `client.scanAccept`.
It also includes a minimal local identity preparation hook through public
`client.createRootIdentity`, `client.addDeviceKey`, and `client.clientLifecycle`
methods; bundle parsing and lifecycle mutation stay in the SDK.

`createBrowserCameraAdapter` uses `getUserMedia` and an injected QR decoder. It
returns a GR1 string payload and passes that payload into the same scanner
workflow. IndexedDB persistence, service workers, and npm release packaging stay
outside this shell.

## Check

```bash
npm --prefix examples/wasm-scanner run check
npm --prefix examples/wasm-scanner run test:smoke
```
