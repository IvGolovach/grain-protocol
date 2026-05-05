# Grain Swift Client

Swift package for the portable Grain client workflow surface.

This package wraps the generated UniFFI bindings with a small `GrainClient`
API. App code calls scan workflows; it does not call QR, COSE, DAG-CBOR, or
protocol runner internals.

## Regenerate bindings

```bash
scripts/sdk/sync_swift_bindings.sh
```

## Check the package

```bash
scripts/sdk/check_swift_package.sh
```

## Example

```swift
import GrainClient

let client = GrainClient()

// Trust setup stays in app/platform code. This provider can resolve enrolled
// publisher keys, device-management policy, or test fixtures by stable ID.
let trustAnchorID = "publisher:primary"
let trustProvider = GrainStaticTrustProvider(
    anchorID: trustAnchorID,
    trustPubB64: "<trusted publisher public key base64>"
)
let scannedQRCode = "<GR1...>"

if client.clientLifecycle().status != "Ready" {
    let identity = client.createRootIdentity(label: "phone")
    if identity.status == "Created" || identity.status == "AlreadyExists" {
        let device = client.addDeviceKey(label: "glasses")
        if let deviceAK = device.deviceAK {
            _ = client.setActiveDevice(ak: deviceAK)
        }
    }
}

let preview = client.scanPreview(
    qrString: scannedQRCode,
    trustAnchorID: trustAnchorID,
    trustProvider: trustProvider
)

if preview.status == .verified {
    let accepted = client.scanAccept(
        qrString: scannedQRCode,
        trustAnchorID: trustAnchorID,
        trustProvider: trustProvider
    )

    if accepted.status == .accepted || accepted.status == .alreadyAccepted {
        let saved = client.listAcceptedScans()
        print(saved.count)

        // Portable evidence/state export for backup, handoff, or audit.
        let evidence = client.exportSyncBundle()
        if evidence.status == "Exported", let bundleB64 = evidence.bundleB64 {
            print(bundleB64)
        }
    }
}
```

## Workflow notes

- `scanPreview` never writes local storage.
- `scanAccept` should use an explicit `trustAnchorID` plus `GrainTrustProvider`
  in production and persists at most one accepted record for the same verified
  scan.
- `listAcceptedScans` returns deterministic accepted records from the local
  store.
- `exportIdentityBundle` exports portable identity material for app-controlled
  backup or pairing setup.
- `exportSyncBundle` exports identity, accepted scans, and lifecycle events as a
  portable evidence/state bundle.
- Production apps should place the same workflow surface behind platform-backed
  storage such as Keychain; the current package proves the generated SDK API
  shape and workflow conformance.
