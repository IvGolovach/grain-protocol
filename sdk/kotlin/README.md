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
    val scannedQRCode = "<GR1...>"

    if (client.clientLifecycle().status != "Ready") {
        val identity = client.createRootIdentity(label = "phone")
        if (identity.status == "Created" || identity.status == "AlreadyExists") {
            val device = client.addDeviceKey(label = "glasses")
            device.deviceAk?.let { client.setActiveDevice(ak = it) }
        }
    }

    val preview = client.scanPreview(
        qrString = scannedQRCode,
        trustAnchorId = trustAnchorId,
        trustProvider = trustProvider,
    )

    if (preview.status == GrainScanPreviewStatus.Verified) {
        val accepted = client.scanAccept(
            qrString = scannedQRCode,
            trustAnchorId = trustAnchorId,
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
- Production Android apps should place the same workflow surface behind
  platform-backed storage such as Keystore; the current package proves the
  generated SDK API shape and workflow conformance.
