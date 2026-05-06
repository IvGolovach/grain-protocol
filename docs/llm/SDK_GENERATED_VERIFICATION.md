# SDK_GENERATED_VERIFICATION

Hi teammate LLM. Use this when changing generated platform SDKs, SDK release
packaging, or docs that claim Swift/Kotlin/WASM readiness.

## Source Of Truth

The generated SDK stack is:

1. `core/rust/grain-client-core`
   - owns workflow semantics, store atomicity, identity, pairing, and sync.
2. `core/rust/grain-client-core/src/grain_client_core.udl`
   - owns the UniFFI-safe generated binding surface.
3. `scripts/sdk/generate_client_bindings.sh`
   - generates Swift and Kotlin bindings into a caller-provided output dir.
4. `sdk/swift`, `sdk/kotlin`, and `sdk/wasm`
   - expose small app-facing wrapper APIs over the generated or WASM workflow
     surface.
   - `sdk/swift/Sources/GrainClientIOSAdapters` is the first native adapter
     pack; it persists opaque snapshots without changing workflow semantics.
   - `sdk/kotlin/src/main/kotlin/dev/grain/android` and
     `sdk/wasm/src/browser-storage.mjs` provide the Android and
     WASM/mobile-web adapter packs behind the same opaque snapshot contract.
5. `sdk/workflows/**`
   - executable client workflow contract for every generated SDK.
6. `sdk/trust/**`
   - local trust anchor bundle schema and fixtures packaged with the workflow
     contract archive.

Do not claim platform SDK conformance from protocol vectors alone. Protocol
vectors prove Grain bytes and diagnostics. Workflow fixtures prove the generated
SDK app surface.

## One-Command Check

Lightweight SDK readiness, no platform builds:

```bash
scripts/sdk/doctor
```

This is the developer front door for docs, workflow-fixture shape, trust/no
network policy, secret logging policy, and existing source package metadata. It
does not replace full platform verification.

```bash
scripts/sdk/verify_all_sdks.sh
```

Use strict mode for release or PR merge-readiness when every local prerequisite
is installed:

```bash
scripts/sdk/verify_all_sdks.sh --strict
```

The command writes an ignored summary under `artifacts/sdk-verify-all/` by
default and fails on dirty output from the underlying checks.

## Required Individual Checks

Generated binding harness:

```bash
scripts/sdk/check_generated_bindings.sh
```

Rust client workflows:

```bash
cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core
cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core --test pairing_sync_bundle
python3 tools/ci/check_client_workflow_fixtures.py
python3 tools/ci/check_sdk_secret_logging.py
```

Swift package:

```bash
scripts/sdk/check_swift_package.sh
```

Kotlin package:

```bash
SDK_KOTLIN_GRADLE_OFFLINE=1 scripts/sdk/check_kotlin_package.sh
```

WASM package:

```bash
scripts/sdk/check_wasm_package.sh
```

Scanner examples:

```bash
scripts/sdk/check_scanner_examples.sh
```

Release packaging:

```bash
scripts/sdk/package_client_sdks.sh
```

Release metadata check:

```bash
python3 tools/ci/check_sdk_release_package.py \
  --out-dir artifacts/sdk-release/$(git rev-parse HEAD) \
  --expected-commit "$(git rev-parse HEAD)" \
  --require-strict \
  --require-clean
```

## Compatibility Rules

- Keep Swift, Kotlin, WASM, generated bindings, and `grain-client-core` on the
  same repo SHA or release tag unless `docs/human/sdk/version-matrix.md`
  explicitly allows a cross-version pairing.
- Generated Swift/Kotlin sources must be updated only through the sync scripts.
- WASM app code must call the JavaScript `GrainClient` wrapper, not the raw
  pointer ABI.
- Platform wrappers may expose workflow names and typed statuses; they must not
  expose raw QR decode, COSE verify, DAG-CBOR validation, or protocol runner
  operations as app APIs.
- Trust remains explicit. Production wrappers expose `trustAnchorID` plus a
  platform trust provider; unknown anchors fail closed with
  `SDK_ERR_TRUST_ANCHOR_*`. SDK core does not perform hidden lookup, network
  discovery, or vendor fallback.
- Swift iOS adapters must keep storage app-owned and opaque. File persistence
  is allowed for deterministic smoke; Keychain persistence stays behind the same
  `GrainSnapshotPersistence` contract and must not parse or log snapshots.
- Kotlin Android adapters must keep storage app-owned and opaque. File
  persistence is allowed for deterministic smoke; Keystore-backed encryption
  stays behind the same `GrainSnapshotPersistence` contract through an injected
  cipher/store boundary. `GrainAesGcmSnapshotCipher` authenticates sealed
  snapshots with an app-supplied `SecretKey`, and adapters must not parse or log
  snapshots.
- WASM/mobile-web adapters must keep storage app-owned and opaque. IndexedDB
  persistence is allowed for deterministic browser/mobile-web smoke; adapters
  must not parse or log `snapshotB64`, sync bundles, pairing envelopes, or trust
  material.
- Generated wrapper readiness is not production custody readiness unless the
  consuming app also names its camera/sensor adapter, local trust provider,
  snapshot custody adapter, and encrypted/authenticated transfer/share channel.
  `GrainCustodyPolicies` is vocabulary for that boundary, not hidden key
  management.
- Public debug/toString/log helper paths must redact raw snapshots, identity
  bundles, pairing envelopes, sync bundles, accepted-scan COSE, and trust
  material. Keep `tools/ci/check_sdk_secret_logging.py` wired into SDK and
  Python policy checks when adding new platform wrappers or scanner examples.

## Packaging Rules

Release SDK artifacts belong under `artifacts/` during local packaging. Do not
commit package tarballs, generated temp directories, Gradle caches, Swift build
scratch space, WASM binaries, `node_modules`, or evidence bundles unless a
future release process explicitly names a tracked artifact.

`scripts/sdk/package_client_sdks.sh` creates:

- generated binding snapshot tarball
- Swift client source tarball
- Kotlin client source tarball
- WASM/mobile-web source tarball
- workflow contract/docs tarball, including `sdk/trust` bundle schema and
  fixtures
- manifest with commit SHA, same-SHA version-matrix hash, SDK component
  versions, artifact byte counts, and SHA-256 checksums
- SPDX 2.3 JSON SBOM with package checksums for every release artifact
- `SHA256SUMS` for the tarballs and SBOM

The default path refuses a dirty worktree and runs strict SDK verification before
packaging. Archives must not contain `node_modules`, `dist`, `build`, `.build`,
`.gradle`, `.kotlin`, `target`, `pkg`, or `.wasm` build output.

The package is a source-archive release candidate for the same repo SHA. It does
not publish npm/Maven/SPM registry entries, does not certify App Store, Play
Store, PWA, or future-device packaging, and does not include compiled WASM
binaries. Pair it with the matching built WASM artifact when a web app needs a
runtime binary.

`--skip-verify --verified-by <id>` is allowed only when a just-completed
upstream strict SDK gate, such as the CI `sdk-platform` job, is the verification
source for that package. The checker accepts that as `strict-upstream`; plain
`--skip-verify` remains visibly recorded as `skipped` and must not be presented
as release certification. Final release authority is clean same-SHA package
metadata plus strict SDK proof plus the repository release evidence required for
the tag or PR.
