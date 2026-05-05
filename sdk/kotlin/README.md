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

GrainClient().use { client ->
    val preview = client.scanPreview(
        qrString = scannedQRCode,
        trustPubB64 = trustedPublicKey,
    )

    if (preview.status == GrainScanPreviewStatus.Verified) {
        val accepted = client.scanAccept(
            qrString = scannedQRCode,
            trustPubB64 = trustedPublicKey,
        )

        if (
            accepted.status == GrainScanAcceptStatus.Accepted ||
            accepted.status == GrainScanAcceptStatus.AlreadyAccepted
        ) {
            val saved = client.listAcceptedScans()
            println(saved.size)
        }
    }
}
```
