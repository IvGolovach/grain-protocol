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

## MealMark Food Graph

Apps that need ingredient-aware search, pairings, or similar-meal review can
import the optional local graph target:

```swift
import GrainFoodGraph

let graph = try LocalFoodGraph.loadBundledMealMarkGraph()
let matches = graph.resolveIngredients(["Greek yogurt", "walnuts", "honey"])
let pairings = graph.suggestPairings(
    ingredients: ["ramen noodle", "pork", "egg", "scallion", "miso", "garlic"]
)
```

`GrainFoodGraph` is bundled as local SwiftPM resources. It does not call
Hugging Face, open sockets, use camera APIs, or persist raw photos. Its output
is advisory only and must not change kcal, variance, record trust, nutrition
confidence, or the Food Wallet confirmation boundary.

## Example

```swift
import GrainClient
import GrainClientIOSAdapters

let client = GrainClient()
let snapshots = GrainLocalSnapshotStore(
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
let handoff = GrainScanHandoff(
    qrString: "<GR1...>",
    trustAnchorID: trustAnchorID,
    source: .camera
)

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
    handoff: handoff,
    trustProvider: trustProvider
)

if preview.status == .verified {
    let accepted = client.scanAccept(
        handoff: handoff,
        trustProvider: trustProvider
    )

    if accepted.status == .accepted || accepted.status == .alreadyAccepted {
        let saved = client.listAcceptedScans()
        print(saved.count)
        _ = try snapshots.save(from: client)
    }
}
```

## Workflow notes

- `GrainScanHandoff` is the portable input object for camera, paste,
  share-sheet, glasses, or robot-vision QR capture. Platform code owns the
  sensor; Grain owns preview, accept, diagnostics, and mutation.
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
- `GrainClientIOSAdapters` adds an opaque snapshot persistence boundary for iOS
  apps. `GrainLocalSnapshotStore` gives app code restore/save/clear operations
  over that boundary. File persistence is deterministic for tests and simulator
  smoke; the Keychain-backed implementation keeps `snapshotB64` isolated from
  protocol semantics.
- `examples/ios-scanner` composes local trust-bundle loading with the
  Keychain-backed persistence initializer for production app setup, while its
  smoke path keeps injected QR input and file persistence deterministic.
- `GrainCustodyPolicies` names the expected boundary: snapshots are device
  local and non-exportable, while identity bundles, pairing envelopes, and sync
  bundles are portable secret transfer artifacts.
- Choose Keychain accessibility deliberately for the app threat model. Large or
  frequently changing snapshots can be sealed into files with keys held by
  Keychain or Secure Enclave-backed policy instead of storing growing blobs
  directly in Keychain.
- Do not log `snapshotB64`, identity bundles, sync bundles, or trust material.
  Persist them through app-owned protected storage and expose only statuses,
  counts, or diagnostics to UI/logs.
