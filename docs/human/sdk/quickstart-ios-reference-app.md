# iOS Reference App Quickstart

This path lets a developer run the Grain iOS reference app locally without a
paid Apple Developer Program.

It proves source-level app integration: local trust bundle loading, demo or
paste scan input, preview, accept, saved list restore, and export/debug status.
It does not prove TestFlight, App Store, Ad Hoc distribution, registry
publication, production camera automation, or production key custody.

## What You Need

- macOS with Xcode installed
- an ordinary Apple ID signed in to Xcode
- this repo checkout
- Rust toolchain for `grain-client-core`
- Swift from Xcode or the selected command line tools

No Apple Developer Program membership is required for the local path.

## Command Line Smoke

From the repo root:

```bash
scripts/sdk/check_ios_reference_app.sh
```

That command builds `grain-client-core`, builds the Swift package, runs
`GrainIOSReferenceAppSmoke`, and rejects raw protocol/FFI calls, hidden trust
lookup, and secret-like logging in the reference app.

For the full SDK platform gate on a prepared machine:

```bash
scripts/sdk/verify_all_sdks.sh --strict --out-dir artifacts/sdk-verify-local-reference
```

## Run In Local Xcode

For a physical iPhone or simulator, keep the app wrapper local and source-level:

1. Open Xcode and sign in with an ordinary Apple ID.
2. Use a local iOS App target and add `examples/ios-reference-app` as a local
   Swift package dependency.
3. In Signing and Capabilities, select your Personal Team and automatic
   signing.
4. Use `GrainReferenceScannerRootView` as the app root view.

Example local app entrypoint:

```swift
import SwiftUI
import GrainIOSReferenceAppCore

@main
struct LocalGrainReferenceApp: App {
    private let configuration = Result {
        try GrainReferenceAppResources.bundled()
    }

    var body: some Scene {
        WindowGroup {
            switch configuration {
            case let .success(configuration):
                GrainReferenceScannerRootView(configuration: configuration)
            case .failure:
                Text("SDK_ERR_IOS_REFERENCE_CONFIG")
            }
        }
    }
}
```

This is local development signing. It is not TestFlight, App Store, Ad Hoc, or
enterprise distribution.

## Happy Path

1. Launch the local app.
2. Tap Demo QR or paste a `GR1:` string.
3. Preview the scan.
4. Accept only after the preview is verified.
5. Restore the saved list after relaunch.
6. Use export/debug only for status, counts, scan IDs, and diagnostics.

Do not print or display `snapshotB64`, identity bundles, pairing envelopes, sync
bundles, COSE payloads, or trust key material.

## Where To Customize

The app layer owns:

- camera or paste input that returns a `GR1:` string
- app-packaged local trust bundle selection
- Keychain-backed or file-backed snapshot persistence
- UI state and user decisions
- export/share channels

Grain owns parsing, trust verification, diagnostics, accept/idempotency, restore
semantics, snapshot format, pairing, and sync workflow behavior.
