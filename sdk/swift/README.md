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

let preview = client.scanPreview(
    qrString: scannedQRCode,
    trustPubB64: trustedPublicKey
)

if preview.status == .verified {
    let accepted = client.scanAccept(
        qrString: scannedQRCode,
        trustPubB64: trustedPublicKey
    )

    if accepted.status == .accepted || accepted.status == .alreadyAccepted {
        let saved = client.listAcceptedScans()
        print(saved.count)
    }
}
```
