# SDK_CONFORMANCE

Hi teammate LLM. This file links SDK behavior to executable checks.

## Protocol suite through SDK

SDK runner path:
- `core/ts/grain-sdk/src/cli.ts`

Runner contract:
```bash
npm --prefix core/ts/grain-sdk run run:vector -- <vector.json>
```

Full protocol suite execution through SDK runner:
```bash
npm --prefix core/ts/grain-sdk run run:protocol-suite
```

## SDK-specific invariants suite

```bash
npm --prefix core/ts/grain-sdk run test:invariants
npm --prefix core/ts/grain-sdk-ai run test:boundary
```

Expected contract:
- pass when all SDK-INV checks succeed
- deterministic JSON summary with `total`, `failed`, and per-check status
- SDK invariants currently cover `SDK-INV-0001` through `SDK-INV-0031` and `SDK-AI-000` through `SDK-AI-007`

## Portable client core

Rust client workflow checks:

```bash
cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core
```

Expected contract:
- scan preview preserves explicit trust boundaries
- malformed scan/trust/signature paths reject deterministically
- valid scan without trust remains `Untrusted`, not `Verified`
- scan accept preparation requires explicit verified trust
- accepted scan preparation returns a deterministic `scan-sha256:<hex>` ID derived from verified COSE bytes
- scan accept preparation is pure and performs no storage mutation
- scan accept persists verified records inside an atomic store boundary
- rejected scan accept writes no records
- duplicate scan accept is idempotent
- failed or nested store mutations reject or roll back deterministically
- identity/device lifecycle workflows create, import/export, activate, revoke, and report lifecycle counts deterministically
- pairing preview is pure, pairing accept is atomic, and repeated pairing accept is idempotent
- sync bundle export/import carries identity, accepted scans, and lifecycle events atomically
- pairing and sync transfer metadata rejects unsupported or falsely device-bound
  custody claims before mutation
- Rust and binding DTO debug output redacts snapshots, identity bundles, pairing
  envelopes, sync bundles, accepted-scan COSE, and trust material

## Client workflow fixtures

Workflow fixtures:
- `sdk/workflows/contract/client_workflow_v1.md`
- `sdk/workflows/contract/client_workflow_v1.schema.json`
- `sdk/workflows/fixtures/device-lifecycle/*.json`
- `sdk/workflows/fixtures/pairing/*.json`
- `sdk/workflows/fixtures/scan-accept/*.json`
- `sdk/workflows/fixtures/scan-preview/*.json`
- `sdk/workflows/fixtures/store-snapshot/*.json`
- `sdk/workflows/fixtures/sync-bundle/*.json`

Fixture validation:

```bash
python3 tools/ci/check_client_workflow_fixtures.py
cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core
```

Expected contract:
- `sdk/workflows/**` is client workflow conformance, not protocol conformance
- workflow fixtures may reference protocol vectors, but must not be consumed by the protocol runner
- generated Swift, Kotlin, WASM, and future device SDKs are client-workflow conformant only after they pass these fixtures through their public workflow APIs
- `scan_preview` fixtures currently cover verified, untrusted, malformed QR, malformed trust, and wrong trust-key paths
- provider-backed `scan_preview` fixtures cover explicit trust-anchor success and unknown-anchor fail-closed behavior
- trust bundle-backed `scan_preview` fixtures prove `sdk/trust` local bundle parsing through the same public static provider surface
- every `scan_preview` fixture expects `store_mutation: "none"`
- `scan_accept` fixtures currently cover accepted persistence, duplicate-scan idempotency, and rejected no-write behavior
- provider-backed `scan_accept` fixtures cover explicit trust-anchor success and unknown-anchor rejection with no storage mutation
- trust bundle-backed `scan_accept` fixtures prove accepted persistence and unknown-anchor rejection without direct trust material
- every `scan_accept` fixture asserts `store_mutation` and `accepted_record_count`
- `device_lifecycle` fixtures cover root creation, device add/activate/revoke, and lifecycle counters
- `pairing` fixtures cover create/preview/accept/replay behavior through public client APIs
- `sync_bundle` fixtures cover export/import/replay of identity, accepted scans, and lifecycle events
- `store_snapshot` fixtures cover opaque snapshot export/restore behavior through public client APIs
- platform adapter contract tests cover deterministic storage listing, idempotent re-put, rollback at the repository boundary, no anchor, missing anchor, malformed anchor, and valid anchor
- FFI DTO contract tests keep binding-facing values owned and flat: strings, vectors, optional strings, no borrowed Rust lifetimes
- `tools/ci/check_sdk_trust_provider_boundary.py` blocks hidden network trust lookup, TOFU/default issuer, and fallback trust patterns in generated platform SDK wrapper sources
- `tools/ci/check_sdk_secret_logging.py` blocks source-level log/print calls
  that include SDK secret-transfer field names in public SDK and example roots

Rust fixture execution must load these fixtures and compare them against public `grain_client_core` workflow APIs.

## Production custody and redaction

Custody/redaction guard:

```bash
python3 tools/ci/check_sdk_secret_logging.py
cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core --test pairing_sync_bundle
```

Expected contract:
- `snapshotB64` is device-local runtime state and must stay opaque to apps
- identity bundles, pairing envelopes, and sync bundles are portable secret
  transfer artifacts, not proof of device-bound custody
- pairing/sync imports reject transfer metadata that falsely claims
  device-bound custody or mismatched material
- generated Swift/Kotlin/WASM wrappers expose a shared custody vocabulary so
  future iOS, Android, browser, glasses, robot, TPM, HSM, or external-module
  adapters can describe custody without changing protocol workflows
- public debug/toString/log helper output redacts raw snapshots, bundles,
  envelopes, accepted-scan COSE, and trust material
- production readiness is not certified by SDK workflow parity alone; platform
  apps must name their camera/sensor adapter, trust provider, snapshot custody,
  and transfer/share channel

## Generated binding harness

Generation check:

```bash
scripts/sdk/check_generated_bindings.sh
```

Expected contract:
- `grain-client-core` builds UniFFI scaffolding from `core/rust/grain-client-core/src/grain_client_core.udl`
- `core/rust/uniffi-bindgen` is the repo-local binding generator entrypoint
- Swift and Kotlin bindings can be generated into ignored or temporary output directories
- generated output contains the expected workflow symbols: preview, accept preparation, accept, listing, identity, device lifecycle, pairing, sync, and binding-safe request DTOs
- generated output and UDL do not expose raw QR/COSE/DAG-CBOR/protocol-runner operations as app APIs
- the check leaves git status unchanged except for pre-existing unrelated local work

## Swift client package

Swift package check:

```bash
scripts/sdk/check_swift_package.sh
```

Expected contract:
- `scripts/sdk/sync_swift_bindings.sh` regenerates Swift binding sources from the checked-in UniFFI harness and updates only the tracked Swift binding files
- `cargo build --manifest-path core/rust/Cargo.toml -p grain-client-core` builds the native library linked by SwiftPM
- `swift build --package-path sdk/swift` builds the `GrainClient` package
- `swift run --package-path sdk/swift GrainClientIOSAdaptersSmoke` proves iOS adapter snapshot persistence without XCTest or device-only state
- `swift run --package-path sdk/swift GrainClientFixtureRunner` executes scan, lifecycle, pairing, and sync fixtures through the public Swift `GrainClient` API
- the package exposes workflow methods and typed Swift statuses, not raw QR/COSE/DAG-CBOR/protocol-runner APIs
- fixture references are constrained to `conformance/vectors/**`
- the check leaves git status unchanged except for pre-existing unrelated local work

Local note: some environments do not ship `XCTest` or Swift Testing modules. This repository uses an executable fixture runner for the Swift package lane so the same deterministic workflow proof works in that toolchain shape.

## Kotlin client package

Kotlin package check:

```bash
scripts/sdk/check_kotlin_package.sh
```

Expected contract:
- `scripts/sdk/sync_kotlin_bindings.sh` regenerates Kotlin binding source from the checked-in UniFFI harness and updates only the tracked Kotlin binding file
- `cargo build --manifest-path core/rust/Cargo.toml -p grain-client-core` builds the native library loaded by JNA
- Gradle/Kotlin compiles the public `GrainClient` wrapper and fixture runner
- the executable fixture runner executes scan, lifecycle, pairing, and sync fixtures through the public Kotlin `GrainClient` API
- `runAndroidAdaptersSmoke` proves Android adapter snapshot persistence, the
  coordinator invariant for missing exported snapshots, and the Keystore-ready
  encrypted persistence boundary without instrumented device state
- the package exposes workflow methods and typed Kotlin statuses, not raw QR/COSE/DAG-CBOR/protocol-runner APIs
- fixture references are constrained to `conformance/vectors/**`
- the check leaves git status unchanged except for pre-existing unrelated local work

Local note: Apple silicon environments must use a JVM with the same architecture as the Rust client-core dylib. Set `JAVA_HOME` to an arm64 JDK before running the Kotlin package check on arm64 macOS.

## WASM/mobile-web client package

WASM package check:

```bash
scripts/sdk/check_wasm_package.sh
```

Expected contract:
- `cargo build --manifest-path core/rust/Cargo.toml -p grain-client-wasm --target wasm32-wasip1 --release` builds the WASM client workflow export over `grain-client-core`
- `grain-client-wasm` depends on `grain-client-core` with default features disabled, so the target-side WASM dependency tree does not include the UniFFI runtime
- `sdk/wasm` loads that WASM export behind a small public `GrainClient` API
- `test:browser-adapters` proves browser/mobile-web snapshot persistence,
  coordinator behavior, IndexedDB persistence wiring, and missing exported
  snapshot rejection without parsing protocol state
- the Node fixture runner executes scan, lifecycle, pairing, and sync fixtures through the public web API
- the package exposes workflow methods and typed web statuses, not raw QR/COSE/DAG-CBOR/protocol-runner APIs
- fixture references are constrained to `conformance/vectors/**`
- the check leaves git status unchanged except for pre-existing unrelated local work

Local note: environments without a locally installed `wasm32-wasip1` Rust standard library cannot complete the full WASM build. Required CI `wasm-smoke` installs the target and runs this check on PR and main SHAs.

## Release Certification Composition

SDK release certification is composed from multiple proofs:

```bash
scripts/sdk/verify_all_sdks.sh --strict
scripts/sdk/package_client_sdks.sh
python3 tools/ci/check_sdk_release_package.py \
  --out-dir artifacts/sdk-release/$(git rev-parse HEAD) \
  --expected-commit "$(git rev-parse HEAD)" \
  --require-strict \
  --require-clean
```

`verify_all_sdks.sh --strict` proves platform SDK workflow behavior.
`package_client_sdks.sh` produces same-SHA source artifacts, manifest,
checksums, and SBOM. `check_sdk_release_package.py` proves the metadata matches
the files and version matrix. Repository release evidence still comes from
`./scripts/verify`, `./scripts/certify`, and mandatory GitHub CI; do not treat a
package smoke by itself as full release authority.

## Developer DX Doctor

Lightweight SDK readiness check:

```bash
scripts/sdk/doctor
```

Expected contract:
- reports the root repo doctor state and platform prerequisite availability
- runs docs, LLM docs, workflow fixture, no-network, trust-boundary,
  secret-logging, and AI-boundary guards
- checks current-HEAD SDK release package metadata when
  `artifacts/sdk-release/$(git rev-parse HEAD)/manifest.json` exists
- prints `WARN` instead of a final `PASS` when optional local readiness or SDK
  source package follow-up is still needed
- does not run platform builds, package SDK artifacts, publish registries, or
  claim App Store, Play Store, PWA, or future-device distribution readiness

Use `scripts/sdk/doctor --require-release-package` only when the source package
for the exact current commit is supposed to exist already.

## Diagnostics contract

- Core diagnostics are preserved and not renamed.
- SDK-only diagnostics use `SDK_ERR_*` namespace.
- SDK import/transport boundaries reject malformed non-standard base64 deterministically.
- Portable generated SDKs bind workflow APIs and keep raw protocol operations out of the main app surface.
- AI boundary explain payload is deterministic and redacted by default.
- structured_v1 field typing must be explicit (profile table or explicit pointer maps).

## SDK no-network policy

```bash
python3 tools/ci/check_sdk_no_network.py
```

This is a hard gate. SDK core and the AI sidecar must stay vendor/network agnostic.

## Scanner adapter examples

Scanner example check:

```bash
scripts/sdk/check_scanner_examples.sh
```

Expected iOS adapter contract:
- `examples/ios-scanner` accepts injected or AVFoundation-derived QR payloads as GR1 strings and sends them through public Swift workflow APIs
- `examples/ios-reference-app` wraps that shell in a minimal SwiftUI app
  entrypoint and is checked by `scripts/sdk/check_ios_reference_app.sh`
- production preview/accept paths use `trustAnchorID` plus `GrainTrustProvider`
- the production initializer loads app-managed trust bundle JSON and stores
  snapshots through `GrainKeychainSnapshotPersistence`
- the shell persists only opaque `snapshotB64` through `GrainClientIOSAdapters`
  and exposes accepted-scan list/export flow without displaying snapshot or
  bundle payload material
- blank or unknown trust anchors reject with `SDK_ERR_TRUST_ANCHOR_*`
- local trust anchor bundles load through `GrainStaticTrustProvider(bundleJSON:)`
  and invalid bundles fail closed before scan preview/accept
- URL-based scanner bundle loading accepts only local file URLs
- preview and rejected accept paths do not write accepted records
- static guards reject raw protocol API calls, hidden trust lookup, network trust discovery, TOFU, and fallback trust patterns

Expected Android adapter contract:
- `examples/android-scanner` accepts injected or CameraX-decoded QR payloads as
  GR1 strings and sends them through public Kotlin workflow APIs
- production preview/accept paths use `trustAnchorId` plus `GrainTrustProvider`
- the shell persists only opaque `snapshotB64` through `dev.grain.android`
  and exposes accepted-scan list/export flow without displaying snapshot or
  bundle payload material
- blank or unknown trust anchors reject with `SDK_ERR_TRUST_ANCHOR_*`
- local trust anchor bundles load through `GrainStaticTrustProvider.fromBundleJson`
  and invalid bundles fail closed before scan preview/accept
- `GrainAesGcmSnapshotCipher` accepts an app-supplied Android Keystore
  `SecretKey`-shaped key and authenticates sealed snapshots before restore
- preview and rejected accept paths do not write accepted records or snapshots
- static guards reject raw protocol API calls, hidden trust lookup, network
  trust discovery, TOFU, fallback trust, and secret snapshot/trust logging

Expected WASM/mobile-web adapter contract:
- `examples/wasm-scanner` accepts injected or browser-decoded QR payloads as
  GR1 strings and sends them through public WASM workflow APIs
- production preview/accept paths use `trustAnchorId` plus `GrainTrustProvider`
- the shell persists only opaque `snapshotB64` through `sdk/wasm` browser
  storage adapters
- blank or unknown trust anchors reject with `SDK_ERR_TRUST_ANCHOR_*`
- local trust anchor bundles load through `GrainStaticTrustProvider.fromBundleJson`
  and invalid bundles fail closed before scan preview/accept
- preview and rejected accept paths do not write accepted records or snapshots
- static guards reject raw protocol API calls, hidden trust lookup, network
  trust discovery, TOFU, fallback trust, and secret snapshot/trust logging

If this mapping drifts, report a blocking issue before proposing any semantic change.

## Reference issuer kit

Reference issuer proof:

```bash
cargo test --manifest-path core/rust/Cargo.toml -p grain-issuer-kit
cargo run --manifest-path core/rust/Cargo.toml -p grain-issuer-kit -- --pretty
```

Expected contract:
- generated sample payloads are strict DAG-CBOR `ServingOffer` maps
- QR strings use the existing `GR1:` transport and untagged COSE_Sign1 profile
- CLI output contains `qr_string`, `trust_pub_b64`, `issuer_kid_b64`, and
  `cose_b64`
- CLI output must not contain private signing key material
- generated QR strings verify through `grain-client-core` with emitted trust
  material and reject under wrong trust
