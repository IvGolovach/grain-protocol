# Grain WASM Client

WASM/mobile-web package for the portable Grain client workflow surface.

This package wraps `grain-client-wasm`, which binds `grain-client-core`
workflows. App code calls scan workflows; it does not call QR, COSE,
DAG-CBOR, or protocol runner internals.

The WASM crate disables target-side UniFFI runtime features and uses the same
Rust workflow logic behind the Swift and Kotlin packages.

## Build the WASM artifact

```bash
cargo build --manifest-path core/rust/Cargo.toml -p grain-client-wasm --target wasm32-wasip1 --release
```

## Check the package

```bash
scripts/sdk/check_wasm_package.sh
```

## Example

```js
import { createNodeGrainClient } from "@grain/client-wasm/node";

const client = await createNodeGrainClient({
  wasmPath: "core/rust/target/wasm32-wasip1/release/grain_client_wasm.wasm",
});

try {
  const preview = client.scanPreview({
    qrString: scannedQRCode,
    trustPubB64: trustedPublicKey,
  });

  if (preview.status === "Verified") {
    const accepted = client.scanAccept({
      qrString: scannedQRCode,
      trustPubB64: trustedPublicKey,
    });

    if (accepted.status === "Accepted" || accepted.status === "AlreadyAccepted") {
      console.log(client.listAcceptedScans().length);
    }
  }
} finally {
  client.close();
}
```

The Node helper is the first smoke-tested loader. Browser and framework loaders
should instantiate the same WASM exports and pass the instance to
`GrainClient` without exposing raw protocol operations.
