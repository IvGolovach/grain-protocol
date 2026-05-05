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
import {
  GrainStaticTrustProvider,
  createNodeGrainClient,
} from "@grain/client-wasm/node";

const client = await createNodeGrainClient({
  wasmPath: "core/rust/target/wasm32-wasip1/release/grain_client_wasm.wasm",
});

try {
  // Trust setup stays in app/platform code. This provider can resolve enrolled
  // publisher keys, device-management policy, or test fixtures by stable ID.
  const trustAnchorId = "publisher:primary";
  const trustProvider = new GrainStaticTrustProvider({
    [trustAnchorId]: "<trusted publisher public key base64>",
  });
  const scannedQRCode = "<GR1...>";

  if (client.clientLifecycle().status !== "Ready") {
    const identity = client.createRootIdentity({ label: "phone" });
    if (identity.status === "Created" || identity.status === "AlreadyExists") {
      const device = client.addDeviceKey({ label: "glasses" });
      if (device.deviceAk !== null) {
        client.setActiveDevice({ ak: device.deviceAk });
      }
    }
  }

  const preview = client.scanPreviewWithTrustProvider({
    qrString: scannedQRCode,
    trustAnchorId,
    trustProvider,
  });

  if (preview.status === "Verified") {
    const accepted = client.scanAcceptWithTrustProvider({
      qrString: scannedQRCode,
      trustAnchorId,
      trustProvider,
    });

    if (accepted.status === "Accepted" || accepted.status === "AlreadyAccepted") {
      const saved = client.listAcceptedScans();
      console.log(saved.length);

      // Portable evidence/state export for backup, handoff, or audit.
      const evidence = client.exportSyncBundle();
      if (evidence.status === "Exported" && evidence.bundleB64 !== null) {
        console.log(evidence.bundleB64);
      }
    }
  }
} finally {
  client.close();
}
```

The Node helper is the first smoke-tested loader. Browser and framework loaders
should instantiate the same WASM exports and pass the instance to
`GrainClient` without exposing raw protocol operations.

## Workflow notes

- `scanPreview` never writes local storage.
- `scanAccept` should use an explicit `trustAnchorId` plus `GrainTrustProvider`
  in production and persists at most one accepted record for the same verified
  scan.
- `listAcceptedScans` returns deterministic accepted records from the local
  store.
- `exportIdentityBundle` exports portable identity material for app-controlled
  backup or pairing setup.
- `exportSyncBundle` exports identity, accepted scans, and lifecycle events as a
  portable evidence/state bundle.
- Production browser apps should place the same workflow surface behind
  platform-backed persistence such as IndexedDB or an app-controlled secure
  store; the current package proves the generated SDK API shape and workflow
  conformance.
