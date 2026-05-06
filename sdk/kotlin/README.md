# Grain Kotlin Client

Kotlin/JVM package for the portable Grain client workflow surface.

This package wraps generated UniFFI bindings with a small `GrainClient` API. App
code calls scan workflows; it does not call QR, COSE, DAG-CBOR, or protocol
runner internals.

## Regenerate bindings

```bash
scripts/sdk/sync_kotlin_bindings.sh
```

## Check the package

```bash
scripts/sdk/check_kotlin_package.sh
```

On Apple silicon, use an arm64 JDK so the JVM can load the Rust client-core
dynamic library built for the host.

## Example

```kotlin
import dev.grain.GrainClient
import dev.grain.GrainScanAcceptStatus
import dev.grain.GrainScanHandoff
import dev.grain.GrainScanHandoffSource
import dev.grain.GrainScanPreviewStatus
import dev.grain.GrainStaticTrustProvider

GrainClient().use { client ->
    // Trust setup stays in app/platform code. This provider can resolve enrolled
    // publisher keys, device-management policy, or test fixtures by stable ID.
    val trustAnchorId = "publisher:primary"
    val trustProvider = GrainStaticTrustProvider(
        anchorId = trustAnchorId,
        trustPubB64 = "<trusted publisher public key base64>",
    )
    // Or: val trustProvider = GrainStaticTrustProvider.fromBundleJson(localTrustAnchorBundleJson)
    val handoff = GrainScanHandoff(
        qrString = "<GR1...>",
        trustAnchorId = trustAnchorId,
        source = GrainScanHandoffSource.Camera,
    )

    if (client.clientLifecycle().status != "Ready") {
        val identity = client.createRootIdentity(label = "phone")
        if (identity.status == "Created" || identity.status == "AlreadyExists") {
            val device = client.addDeviceKey(label = "glasses")
            device.deviceAk?.let { client.setActiveDevice(ak = it) }
        }
    }

    val preview = client.scanPreview(
        handoff = handoff,
        trustProvider = trustProvider,
    )

    if (preview.status == GrainScanPreviewStatus.Verified) {
        val accepted = client.scanAccept(
            handoff = handoff,
            trustProvider = trustProvider,
        )

        if (
            accepted.status == GrainScanAcceptStatus.Accepted ||
            accepted.status == GrainScanAcceptStatus.AlreadyAccepted
        ) {
            val saved = client.listAcceptedScans()
            println(saved.size)

            // Portable evidence/state export for backup, handoff, or audit.
            val evidence = client.exportSyncBundle()
            if (evidence.status == "Exported") {
                println("sync bundle exported")
                // Store or transmit evidence.bundleB64 only through encrypted
                // storage or an authenticated secure channel. Do not log it.
            }
        }
    }
}
```

## Workflow notes

- `GrainScanHandoff` is the portable input object for camera, paste,
  share-sheet, glasses, or robot-vision QR capture. Platform code owns the
  sensor; Grain owns preview, accept, diagnostics, and mutation.
- `scanPreview` never writes local storage.
- `scanAccept` should use an explicit `trustAnchorId` plus `GrainTrustProvider`
  in production and persists at most one accepted record for the same verified
  scan.
- `listAcceptedScans` returns deterministic accepted records from the local
  store.
- `exportIdentityBundle` exports portable identity material for app-controlled
  backup or pairing setup.
- `exportSyncBundle` exports identity, accepted scans, and lifecycle events as a
  portable evidence/state bundle. Treat `bundleB64` as secret portable state and
  never log the raw value.
- `dev.grain.android` adds an Android adapter persistence boundary for opaque
  `snapshotB64` state. `GrainLocalSnapshotStore` gives app code
  restore/save/clear operations over that boundary. File persistence is
  deterministic for JVM smoke tests; `GrainKeystoreSnapshotPersistence` keeps
  Android Keystore encryption behind an injected cipher/store boundary, and
  `GrainAesGcmSnapshotCipher` can seal the snapshot with an Android
  Keystore-backed `SecretKey` without parsing protocol state.
- `GrainCustodyPolicies` names the expected boundary: snapshots are device
  local and non-exportable, while identity bundles, pairing envelopes, and sync
  bundles are portable secret transfer artifacts.
- Android apps own `SecretKey` creation, rotation policy, authentication
  requirements, and backup rules. The SDK accepts the key/cipher boundary; it
  does not create a hidden platform key or silently fall back to plaintext.
- Do not log `snapshotB64`, identity bundles, sync bundles, or trust material.
  Persist them through app-owned protected storage and expose only statuses,
  counts, or diagnostics to UI/logs.
