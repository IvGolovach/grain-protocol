# Source SDK Handoff

Use this page when one Grain SDK SHA is ready for an app developer to consume.
It is the handoff checklist for source SDK artifacts, generated binding
snapshots, scanner examples, and the local issuer QR path.

This is not a registry or store release. It is a same-SHA source handoff that
lets a developer build against reviewed Swift, Kotlin, WASM, generated binding,
workflow, and trust-bundle inputs from one commit.

## Handoff Packet

Fill this packet before sending SDK artifacts to an app team:

```text
Grain commit or release tag:
GitHub release or artifact location:
Strict SDK proof:
SDK package check:
External app handoff check:
External consumer template check:
Public API check:
Compatibility matrix check:
Registry dry-run check:
External client certification:
Issuer QR path checked:
Known local prerequisites:
Residual gaps:
```

Attach or point to these same-SHA assets:

| Asset | Purpose |
| --- | --- |
| `manifest.json` | Records the source commit, package policy, component versions, verification mode, version-matrix hash, and artifact metadata. |
| `SHA256SUMS` | Lets the receiver verify every source archive and SBOM byte-for-byte. |
| `sbom.spdx.json` | Lists SDK source package artifacts and checksums for audit. |
| `grain-generated-bindings-<sha>.tar.gz` | Generated Swift/Kotlin binding snapshot for audit, reproduction, and future wrapper checks. |
| `grain-swift-client-<sha>.tar.gz` | Swift Package Manager source wrapper over the generated client workflow API. |
| `grain-kotlin-client-<sha>.tar.gz` | Kotlin/JVM source wrapper over the generated client workflow API. |
| `grain-wasm-client-<sha>.tar.gz` | WASM/mobile-web source wrapper and Rust WASM crate source. |
| `grain-sdk-workflow-contract-<sha>.tar.gz` | Client workflow fixtures, public API snapshot, safe diagnostic event schema, trust bundle schema, custody adapter contract, generated-lane docs, release-train docs, and version matrix. |
| `grain-starter-templates-<sha>.tar.gz` | iOS, Android, and Web/WASM starter templates, reusable scanner-shell examples they depend on, and the starter-template smoke command. |

The SHA in every archive name must match the commit in `manifest.json`. Do not
mix archives from different commits.

## Producer Check

From a clean repo checkout at the handoff SHA:

```bash
scripts/sdk/package_client_sdks.sh
python3 tools/ci/check_sdk_release_package.py \
  --out-dir artifacts/sdk-release/$(git rev-parse HEAD) \
  --expected-commit "$(git rev-parse HEAD)" \
  --require-strict \
  --require-clean
python3 tools/ci/check_external_sdk_handoff.py \
  --out-dir artifacts/sdk-release/$(git rev-parse HEAD) \
  --expected-commit "$(git rev-parse HEAD)" \
  --require-strict \
  --require-clean
python3 tools/ci/check_external_consumer_templates.py \
  --out-dir artifacts/sdk-release/$(git rev-parse HEAD) \
  --expected-commit "$(git rev-parse HEAD)"
python3 tools/ci/check_sdk_compatibility_matrix.py \
  --manifest artifacts/sdk-release/$(git rev-parse HEAD)/manifest.json
python3 tools/ci/check_public_sdk_api.py
scripts/sdk/check_registry_dry_runs.sh
scripts/sdk/check_starter_templates.sh
```

If the package was produced immediately after a required upstream `sdk-platform`
gate, the release owner may use the documented `--skip-verify --verified-by`
path in `scripts/sdk/package_client_sdks.sh`. The manifest must then record
`strict-upstream`, not plain skipped verification.

`check_sdk_release_package.py` proves the producer metadata, checksums, archive
contents, and SBOM. `check_external_sdk_handoff.py` adds the receiver view: it
extracts the same archives into a temporary outside-app `vendor/grain-sdk/<sha>`
layout, rejects monorepo-only paths, and confirms the current handoff is
source-only rather than an npm, Maven, Swift package-index, app-store, or
compiled-WASM channel. `check_external_consumer_templates.py` proves the same
packet also contains the public API snapshot, custody docs, safe diagnostic
schema, and starter-template inputs that an outside app team needs.

Before calling the packet ready, run:

```bash
scripts/sdk/doctor \
  --release-out-dir artifacts/sdk-release/$(git rev-parse HEAD) \
  --require-release-package
```

`sdk doctor: PASS` means the local machine has the lightweight readiness inputs
and package metadata. `sdk doctor: WARN` means policy checks passed, but the
listed toolchain or release-package issue still needs follow-up before strict
platform proof.

## Receiver Check

If the app team has a repo checkout, check out the exact commit or tag named in
the handoff packet:

```bash
git checkout <grain-sdk-sha-or-tag>
python3 tools/ci/check_sdk_release_package.py \
  --out-dir <path-to-downloaded-sdk-release-dir> \
  --expected-commit "$(git rev-parse HEAD)" \
  --require-strict \
  --require-clean
python3 tools/ci/check_external_sdk_handoff.py \
  --out-dir <path-to-downloaded-sdk-release-dir> \
  --expected-commit "$(git rev-parse HEAD)" \
  --require-strict \
  --require-clean
```

Then unpack only the platform lanes needed by the app. The Swift, Kotlin, WASM,
generated-binding, workflow, and trust artifacts still stay tied to the same
commit:

```bash
mkdir -p vendor/grain-sdk/<sha>
tar -xzf grain-swift-client-<sha>.tar.gz -C vendor/grain-sdk/<sha>
tar -xzf grain-kotlin-client-<sha>.tar.gz -C vendor/grain-sdk/<sha>
tar -xzf grain-wasm-client-<sha>.tar.gz -C vendor/grain-sdk/<sha>
tar -xzf grain-generated-bindings-<sha>.tar.gz -C vendor/grain-sdk/<sha>
tar -xzf grain-sdk-workflow-contract-<sha>.tar.gz -C vendor/grain-sdk/<sha>
tar -xzf grain-starter-templates-<sha>.tar.gz -C vendor/grain-sdk/<sha>
```

The generated binding snapshot is a proof and wrapper-development input. Normal
app code should start from the Swift, Kotlin, or WASM package wrapper, not from
raw generated FFI calls.

## Issuer QR Smoke

Use a repo checkout at the same SHA for the local scanner path. The source SDK
package is the app handoff; it does not include the reference issuer kit source.

```bash
cargo run --manifest-path core/rust/Cargo.toml -p grain-issuer-kit -- --pretty \
  > issuer-output.json
```

Create the local trust bundle:

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

Feed `qr-string.txt` through the app paste, camera, browser, glasses-frame, or
robot-sensor adapter. Load `local-trust-bundle.json` through the platform trust
provider and pass the stable anchor ID `publisher:primary` (`trustAnchorID` in
Swift, `trustAnchorId` in Kotlin and WASM).

The expected app path is:

1. scan or paste `GR1:`
2. resolve the local trust anchor
3. preview
4. accept
5. persist the returned `snapshotB64`
6. restore the snapshot on launch
7. export sync or evidence artifacts only through an encrypted/authenticated
   app channel

For platform-specific smoke commands, use [Scanner app quickstart](./scan-quickstart.md).
For minimal app shells, start from `templates/ios-starter`,
`templates/android-starter`, or `templates/web-wasm-starter`.

## What Is Published

This handoff can claim:

- same-SHA source archives for Swift, Kotlin, WASM, generated bindings,
  workflow contracts, trust schema, custody/API docs, and starter templates
- manifest, checksums, and SBOM metadata for those source archives
- strict local SDK proof or a recorded upstream strict SDK gate
- local issuer QR generation and app-owned trust bundle setup
- deterministic scanner example smokes when the local platform prerequisites
  are present
- registry dry-run metadata for SwiftPM, Maven local, and npm pack, without
  registry credentials or publication

## What Is Not Published

This handoff must not claim:

- npm, Maven, Swift Package Index, CocoaPods, App Store, Play Store, PWA, robot
  fleet, or hardware-device distribution
- compiled WASM binaries as part of the source SDK package
- production trust discovery, network trust lookup, TOFU, or platform CA
  fallback inside the SDK
- hardware custody certification for Keychain, Keystore, Secure Enclave, TPM,
  HSM, MDM, or browser storage policy
- production camera, barcode, glasses, robot sensor, analytics, crash-report,
  backup, pairing-transfer, or sync-transfer channel certification

Those layers belong to the consuming app and must be reviewed separately.
