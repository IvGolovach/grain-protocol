# Scanner App Quickstart

This is the shortest real-app path for iOS, Android, browser, glasses, robots,
or any future device that scans Grain QR payloads.

Use this when your app needs to scan a signed `GR1:` payload, resolve local
trust, preview, accept, persist, restore, and export state through the portable
client SDK. If you only want the smallest TypeScript ledger demo, use
[Minimal app example](./minimal-app-example.md) instead.

## What This Proves

This path proves the app shape, not store distribution:

- SDKs and wrappers come from one repo SHA or release tag.
- The issuer kit creates a signed local `GR1:` scanner input.
- The app wraps public trust material in a local trust anchor bundle.
- The scanner flow uses an explicit trust anchor ID plus a trust provider
  (`trustAnchorID` in Swift, `trustAnchorId` in Kotlin and WASM).
- Accepted records persist through opaque `snapshotB64` storage.
- Portable identity, pairing, and sync artifacts stay out of UI/log output.

It does not publish npm, Maven, Swift Package Index, App Store, Play Store, PWA,
or robot-device packages. It also does not certify hardware key custody by
itself.

## 1. Start From One SDK SHA

Use one checkout, release tag, or SDK source package for all platforms. Do not
mix Swift, Kotlin, WASM, generated bindings, and `grain-client-core` from
different commits unless [the version matrix](./version-matrix.md) explicitly
allows it.

From a repo checkout:

```bash
git checkout <release-tag-or-commit>
scripts/sdk/doctor
```

If you are preparing artifacts for another developer instead of working from a
local checkout, follow [Source SDK handoff](./source-sdk-handoff.md) first. It
names the same-SHA source archives, manifest, checksums, SBOM, and publication
boundaries that must travel with the scanner path.

If the doctor prints `WARN`, the required policy checks passed but local
toolchain or package-readiness issues still need attention before strict platform
verification.

For release-grade source artifacts, package and verify the current SHA:

```bash
scripts/sdk/package_client_sdks.sh
python3 tools/ci/check_sdk_release_package.py \
  --out-dir artifacts/sdk-release/$(git rev-parse HEAD) \
  --expected-commit "$(git rev-parse HEAD)" \
  --require-strict \
  --require-clean
```

The package is a source handoff with manifest, checksums, SBOM, workflow
contract, trust schema, and SDK source archives. It is not a registry publish.

## 2. Generate A Local Issuer QR

Use the reference issuer kit for local scanner development. It prints a signed
`qr_string` and public `trust_pub_b64` material. It does not persist or print
private signing keys.

```bash
cargo run --manifest-path core/rust/Cargo.toml -p grain-issuer-kit -- --pretty \
  > issuer-output.json
```

## 3. Create A Trust Bundle

Scanner apps should pass stable trust anchor IDs, not raw trust text in UI.
Wrap the issuer public key in the local `sdk/trust` bundle shape:

```bash
python3 - <<'PY'
import json
from pathlib import Path

issued = json.loads(Path("issuer-output.json").read_text())
Path("qr-string.txt").write_text(issued["qr_string"] + "\n")
Path("local-trust-bundle.json").write_text(
    json.dumps(
        {
            "bundle_v": 1,
            "anchors": [
                {
                    "id": "publisher:primary",
                    "trust_pub_b64": issued["trust_pub_b64"],
                }
            ],
        },
        indent=2,
    )
    + "\n"
)
PY
```

Your app should load `local-trust-bundle.json`, then call the scanner workflow
with the stable anchor ID `"publisher:primary"` (`trustAnchorID` in Swift,
`trustAnchorId` in Kotlin and WASM).

## 4. Run A Reference Scanner

iOS/Swift:

```bash
cargo build --manifest-path core/rust/Cargo.toml -p grain-client-core
swift run --package-path examples/ios-scanner GrainIOSScannerSmoke
```

Android/Kotlin:

```bash
cargo build --manifest-path core/rust/Cargo.toml -p grain-client-core
sdk/kotlin/gradlew -p examples/android-scanner check
```

Browser/WASM:

```bash
npm --prefix examples/wasm-scanner run check
npm --prefix examples/wasm-scanner run test:smoke
```

Full SDK parity:

```bash
scripts/sdk/verify_all_sdks.sh
```

The commands above run deterministic fixture smokes. To try the QR and trust
files generated in steps 2-3, load `local-trust-bundle.json` through the
platform trust provider and feed `qr-string.txt` through the app paste, camera,
glasses-frame, or robot-sensor adapter; the platform example READMEs show that
handoff for iOS, Android, and browser shells.

Use `scripts/sdk/verify_all_sdks.sh --strict` on CI or release machines with
Swift, Java, Node/npm, Cargo, and the WASM target installed.

## 5. Implement The Thin App Layer

Your app owns only the platform edges:

- QR, camera, glasses frame, robot sensor, or paste adapter returns a `GR1:`
  string.
- Trust provider loads an app-distributed local trust bundle and resolves a
  stable anchor ID.
- Snapshot persistence restores `snapshotB64` on launch and saves a new
  snapshot after successful identity, device, accept, pairing, or sync-import
  mutations.
- Transfer/share channel moves identity bundles, pairing envelopes, and sync
  bundles only through encrypted/authenticated app channels.

The SDK owns protocol parsing, COSE verification, deterministic diagnostics,
preview/accept behavior, rollback/idempotency, pairing, sync, and store snapshot
import/export.

Keep UI, analytics, logs, crash reports, and support bundles limited to
statuses, counts, scan IDs, anchor IDs, and diagnostic codes. Do not log raw
snapshots, identity bundles, pairing envelopes, sync bundles, accepted-scan
COSE, or trust material.
