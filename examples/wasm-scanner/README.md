# Grain WASM Scanner Shell

Browser/mobile-web reference shell over the portable `sdk/wasm` client package.

It accepts a pasted GR1/QR payload string and explicit trust public key, calls
`client.scanPreview`, enables accept only after a verified preview, then calls
`client.scanAccept`.

Camera capture, QR decoding, IndexedDB persistence, service workers, and npm
release packaging are intentionally outside this shell. Add them as adapters
that produce a GR1 string and pass it into the same workflow.

## Check

```bash
npm --prefix examples/wasm-scanner run check
npm --prefix examples/wasm-scanner run test:smoke
```
