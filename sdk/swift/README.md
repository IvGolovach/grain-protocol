# Grain Swift Client

Swift package for the portable Grain client workflow surface.

This package wraps the generated UniFFI bindings with a small `GrainClient`
API plus iOS adapter helpers. App code calls scan workflows; it does not call
QR, COSE, DAG-CBOR, or protocol runner internals.

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
import GrainClientIOSAdapters

let client = GrainClient()
let snapshots = GrainSnapshotCoordinator(
    persistence: try GrainFileSnapshotPersistence.applicationSupport()
)
_ = try snapshots.restore(into: client)

// Trust setup stays in app/platform code. This provider can resolve enrolled
// publisher keys, device-management policy, or test fixtures by stable ID.
let trustAnchorID = "publisher:primary"
let trustProvider = GrainStaticTrustProvider(
    anchorID: trustAnchorID,
    trustPubB64: "<trusted publisher public key base64>"
)
// Or: let trustProvider = try GrainStaticTrustProvider(bundleJSON: localTrustAnchorBundleJSON)
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
        _ = try snapshots.persist(from: client)
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
- `GrainClientIOSAdapters` adds an opaque snapshot persistence seam for iOS
  apps. File persistence is deterministic for tests and simulator smoke; the
  Keychain-backed implementation keeps the same `snapshotB64` boundary isolated
  from protocol semantics.
- Do not log `snapshotB64`, identity bundles, sync bundles, or trust material.
  Persist them through app-owned protected storage and expose only statuses,
  counts, or diagnostics to UI/logs.
