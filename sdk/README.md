# Grain SDK

The production TypeScript SDK code lives in `core/ts/grain-sdk`.
The optional TypeScript AI sidecar lives in `core/ts/grain-sdk-ai`.
This top-level `sdk/` path also holds cross-platform client workflow contracts,
generated-binding lane documentation, and platform package wrappers.

SDK is an adoption layer:
- developer-friendly API
- safe defaults
- still MUST pass conformance suite for protocol-critical behavior

Primary implementation:
- `core/ts/grain-sdk`
- `core/ts/grain-sdk-ai`

Portable client SDK lanes:
- `sdk/api`: public SDK API snapshot and compatibility matrix
- `sdk/custody`: app-owned secure storage adapter contract
- `sdk/workflows`: app-facing scan workflow contracts and fixtures
- `sdk/trust`: local app-owned trust anchor bundle schema and fixtures
- `sdk/generated`: documentation for generated Swift/Kotlin binding output and the WASM workflow export boundary
- `sdk/swift`: Swift Package Manager wrapper over generated client workflow bindings
- `sdk/kotlin`: Kotlin/JVM wrapper over generated client workflow bindings
- `sdk/wasm`: WASM/mobile-web wrapper over generated client workflow bindings

Reference scanner shells live under `examples/`. They show paste-first iOS,
Android/Kotlin, and browser/mobile-web clients that call the public workflow
SDKs and keep camera or sensor adapters outside protocol-critical logic.
Starter app shells live under `templates/`. They are source templates for
outside app teams that need the same trust -> scan/paste -> preview -> accept
-> persist/restore/list/export path without copying protocol internals.
The iOS shell now has a Keychain-backed production initializer, local trust
bundle loading, accepted-scan listing, sync export status, and deterministic
injected-camera smoke coverage.
The Android shell now has local trust bundle loading, accepted-scan listing,
sync export status, and an AES-GCM snapshot cipher boundary for Android
Keystore-backed `SecretKey` storage.
For local issuer-side scanner inputs, `core/rust/grain-issuer-kit` emits a
signed `GR1:` QR string plus public `trust_pub_b64` material without persisting
or printing private signing keys.
For app-side trust setup, `sdk/trust` defines the local JSON bundle shape that
static trust providers can load without network discovery or fallback trust.

## One scanner path

For the fastest end-to-end scanner bring-up, use
`scripts/sdk/run_local_scanner_flow.sh`:

```bash
scripts/sdk/run_local_scanner_flow.sh
```

It runs SDK doctor, creates a local issuer QR and trust bundle under ignored
`artifacts/`, runs the scanner/reference app smokes when platform prerequisites
are available, and writes a machine-readable report. Use
`docs/human/sdk/scan-quickstart.md` for the same path broken into manual steps
and troubleshooting detail.

For a release owner or app team handoff, use
`docs/human/sdk/source-sdk-handoff.md`. It names the same-SHA source archives,
generated binding snapshot, manifest, checksums, SBOM, issuer QR path, and the
boundaries that are not published.

The short path is:

1. Use one repo SHA or release tag for Swift, Kotlin, WASM, generated bindings,
   and `grain-client-core`.
2. Run `scripts/sdk/doctor` for a lightweight SDK readiness check.
3. Generate a local signed scanner input with
   `cargo run --manifest-path core/rust/Cargo.toml -p grain-issuer-kit -- --pretty`.
4. Wrap the emitted `trust_pub_b64` in a local `sdk/trust` bundle and pass a
   stable trust anchor ID to the scanner shell (`trustAnchorID` in Swift,
   `trustAnchorId` in Kotlin and WASM).
5. Wrap each camera, paste, glasses, or robot-vision QR capture in a
   `GrainScanHandoff`, preview, accept, persist the opaque `snapshotB64`,
   restore on launch, and export sync artifacts only through the app's
   encrypted/authenticated transfer channel.

This path uses source SDK packages and examples. It does not claim registry
publication, store distribution, production PWA packaging, or hardware custody
certification.

## Compatibility

Use the matrix in `docs/human/sdk/version-matrix.md` before mixing generated
bindings, wrappers, and Rust crates from different commits or release tags.
The short rule is: ship Swift, Kotlin, WASM, and `grain-client-core` from the
same repo SHA unless the matrix explicitly says a cross-version pairing is
compatible.

Generated SDKs are client-workflow conformant only after they pass
`sdk/workflows/**` through their public wrapper APIs. Passing protocol vectors
alone is not enough.

## Verify all SDK lanes

```bash
scripts/sdk/verify_all_sdks.sh
```

For release-grade local proof, require every platform prerequisite:

```bash
scripts/sdk/verify_all_sdks.sh --strict
```

The strict path expects Swift 6, Java/Kotlin tooling, Node/npm, Cargo, and the
`wasm32-wasip1` Rust target to be available. GitHub CI installs the WASM target
for the required `wasm-smoke` and `sdk-platform` lanes.

Set `SDK_KOTLIN_GRADLE_OFFLINE=1` only after warming Gradle caches when you need
the Kotlin and scanner-example checks to prove offline dependency resolution.

## Package SDK artifacts

```bash
scripts/sdk/package_client_sdks.sh
```

Artifacts are written under `artifacts/sdk-release/<commit>/`, which is ignored
by git. The script packages source SDKs, generated binding snapshots, workflow
fixtures, a manifest, `SHA256SUMS`, and an SPDX JSON SBOM. Build caches and
local package-manager directories are excluded from the archives. By default it
refuses a dirty working tree and runs strict SDK verification before packaging.
This is source-artifact certification for the same repo SHA. It does not publish
to npm, Maven, Swift Package indexes, app stores, or PWA distribution channels,
and it does not include compiled WASM binaries.

Check the package metadata independently:

```bash
python3 tools/ci/check_sdk_release_package.py \
  --out-dir artifacts/sdk-release/$(git rev-parse HEAD) \
  --expected-commit "$(git rev-parse HEAD)" \
  --require-strict \
  --require-clean
```

Check the outside-app consumer boundary independently:

```bash
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
```

That receiver-side check extracts the source archives into a temporary
`vendor/grain-sdk/<sha>` layout, validates the public Swift, Kotlin, WASM,
generated-binding, workflow, and trust inputs, and rejects registry/store or
monorepo-internal claims. The external consumer template check also validates
the public API snapshot, custody docs, safe diagnostic schema, and starter
template archive.

Check starter templates and registry dry-run metadata:

```bash
scripts/sdk/check_starter_templates.sh
scripts/sdk/check_registry_dry_runs.sh
```

These commands prove template shape and dry-run package metadata only. They do
not publish to Swift Package Index, Maven Central, npm, app stores, PWA
channels, robot fleets, or hardware vendor programs.

CI may use `--skip-verify --verified-by sdk-platform` only after the strict
platform SDK gate has just passed on the same checkout. That package is marked
as `strict-upstream`; plain skipped verification is not a release certificate.
Release tags run the same strict SDK gate in `release-evidence` before
attaching the source SDK package assets to the GitHub release. The published
assets remain source-only and same-SHA: `manifest.json`, `SHA256SUMS`,
`sbom.spdx.json`, and the SDK source archives are the release handoff, not a
registry, app-store, or compiled-WASM publication.

Lightweight SDK readiness, without platform builds:

```bash
scripts/sdk/doctor
```

If it prints `WARN`, required policy checks passed but local SDK readiness still
needs the listed toolchain or package follow-up before strict platform proof.

## Workflow shape

Every platform wrapper exposes the same product-level operations:

- prepare local identity and device lifecycle with `createRootIdentity`,
  `addDeviceKey`, `setActiveDevice`, `revokeDeviceKey`, and `clientLifecycle`
- preview a scan with explicit app-supplied trust material using `scanPreview`
- accept and save verified scans using `scanAccept`
- preview or accept through explicit trust anchor IDs using the platform
  trust-provider overloads
- pass QR input through `GrainScanHandoff` so camera, paste, glasses, robot, and
  sensor adapters use one public SDK entrypoint
- list saved accepted scans using `listAcceptedScans`
- export portable evidence/state with `exportSyncBundle`
- pair/sync clients with `createPairingEnvelope`, `acceptPairingEnvelope`, and
  `importSyncBundle`
- persist client runtime state with `exportStoreSnapshot` and
  `restoreStoreSnapshot`

Production app checklist:

- restore the last `snapshotB64` through a platform persistence adapter on
  launch before showing scanner state
- load app-owned local trust anchors and resolve scans through
  an explicit trust anchor ID plus `TrustProvider` (`trustAnchorID` in Swift,
  `trustAnchorId` in Kotlin and WASM)
- scan -> preview -> accept only through the public workflow API
- persist a fresh snapshot after successful identity, device, accept, pairing,
  or sync-import mutations
- keep UI, logs, analytics, crash reports, and support bundles limited to
  statuses, counts, IDs, and diagnostic codes
- never log raw snapshots, identity bundles, pairing envelopes, sync bundles,
  accepted-scan COSE payloads, or trust material

Trust setup is intentionally outside the protocol core. Production apps should
pass a stable trust anchor ID plus a platform `TrustProvider`; the wrapper
resolves that anchor to `trustPubB64` and fails closed with `SDK_ERR_TRUST_ANCHOR_*`
when the anchor is missing. Rust core and generated wrappers do not perform
hidden trust lookup, network discovery, or fallback trust. Raw `trustPubB64`
methods remain available for fixtures and already-resolved trust material.

Store snapshots are opaque SDK state, not a raw mutation API. Apps should save
the returned `snapshotB64` string in their platform storage layer and restore it
into a fresh client on launch. Snapshot payloads can include identity material,
so production adapters should place them behind the platform security boundary
appropriate for the device.

Custody vocabulary is intentionally small:

- `snapshotB64` is device-local runtime state. Store it through Keychain,
  Keystore, IndexedDB plus app sealing, TPM/HSM-backed storage, or equivalent
  protected local storage. It is not a user-visible export format.
- identity bundles, pairing envelopes, and sync bundles are portable secret
  transfer artifacts. Move them only through encrypted/authenticated backup,
  handoff, or pairing channels.
- trust bundles are app-distributed verification policy. Treat them as
  integrity-sensitive local inputs: no network lookup, TOFU, platform CA
  fallback, or default issuer belongs inside the SDK.
