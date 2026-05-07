# SDK Version Matrix

This matrix is the compatibility source for the portable Grain client SDK
family. It keeps app developers from mixing generated bindings, wrapper code,
and Rust crates that were not reviewed together.

## Current Matrix

| Layer | Source | Current version | Compatibility rule |
| --- | --- | --- | --- |
| Frozen protocol contract | `spec/NES-v0.1.md`, `conformance/**` | v0.1 semantics | Protocol semantics remain frozen; SDK changes must preserve protocol verdicts and diagnostics. |
| Rust protocol core | `core/rust/grain-core` | `0.2.0` | Client workflows must consume this through `grain-client-core`, not through app wrappers. |
| Rust client workflow core | `core/rust/grain-client-core` | `0.1.0` | Swift, Kotlin, WASM, and future device SDKs must be generated/wrapped from the same repo SHA or release tag. |
| Client workflow contract | `sdk/workflows/contract/client_workflow_v1.md` | v1 | Platform SDKs are conformant only after their public APIs pass the v1 workflow fixtures. |
| UniFFI binding generator | `core/rust/uniffi-bindgen`, workspace `uniffi` | `0.31.1` | Regenerate Swift/Kotlin bindings with repo scripts; do not patch generated files by hand. |
| Swift client package | `sdk/swift` | repo-SHA versioned | Use with the matching `grain-client-core` native library and checked-in generated Swift sources. |
| Swift iOS adapter pack | `sdk/swift/Sources/GrainClientIOSAdapters`, `examples/ios-scanner`, `examples/ios-reference-app` | repo-SHA versioned | Use with the same commit's `GrainClient`; scanner and reference-app smokes prove local trust-bundle loading, Keychain-ready snapshot persistence, accepted-scan listing, sync export status, explicit trust-anchor wiring, and a thin SwiftUI app entrypoint, not App Store packaging. |
| Kotlin client package | `sdk/kotlin` | `0.1.0` | Use with the matching `grain-client-core` native library and checked-in generated Kotlin source. |
| Kotlin Android adapter pack | `sdk/kotlin/src/main/kotlin/dev/grain/android`, `examples/android-scanner` | repo-SHA versioned | Use with the same commit's `GrainClient`; adapter smoke proves local trust-bundle loading, opaque snapshot persistence, AES-GCM/Keystore-ready encryption boundaries, accepted-scan listing, sync export status, and explicit trust-anchor wiring, not Play Store packaging. |
| WASM client crate | `core/rust/grain-client-wasm` | `0.1.0` | Builds against `grain-client-core` with default features disabled for `wasm32-wasip1`. |
| WASM/mobile-web package | `sdk/wasm` | `0.1.0` | Use with the matching `grain-client-wasm.wasm` artifact and JavaScript wrapper. |
| WASM/mobile-web adapter pack | `sdk/wasm/src/browser-storage.mjs`, `examples/wasm-scanner` | repo-SHA versioned | Use with the same commit's `GrainClient`; adapter smoke proves opaque snapshot persistence, IndexedDB/browser storage boundaries, explicit trust-anchor wiring, and browser camera handoff, not production PWA packaging. |
| Public SDK API snapshot | `sdk/api/public-sdk-v0.1.json` | v0.1 | Stable app-facing methods, statuses, workflows, and compatibility matrix must stay present unless a future API snapshot intentionally replaces them. |
| Starter templates | `templates/ios-starter`, `templates/android-starter`, `templates/web-wasm-starter` | repo-SHA versioned | Use with the same commit's source SDK packet; templates prove thin app shells, not store or PWA publication. |

## Release Rule

Release SDK artifacts from one git commit. A release may contain source
packages, generated binding snapshots, WASM source/package glue, and workflow
fixtures, but it must not mix platform wrappers from one commit with Rust
client-core output from another commit.

Cross-version compatibility is unsupported unless a future matrix row names the
exact accepted pair. The safe app-developer instruction is:

```text
Use Swift, Kotlin, WASM, generated bindings, and grain-client-core from the same Grain SDK release tag.
```

The machine-readable v0.1 API snapshot also carries the current compatibility
matrix. Run:

```bash
python3 tools/ci/check_public_sdk_api.py
python3 tools/ci/check_sdk_compatibility_matrix.py \
  --manifest artifacts/sdk-release/$(git rev-parse HEAD)/manifest.json
```

## Verification Rule

Before publishing or handing SDK artifacts to app teams, run:

```bash
scripts/sdk/verify_all_sdks.sh --strict
scripts/sdk/package_client_sdks.sh
```

That command proves:

- generated Swift and Kotlin bindings can be reproduced from the checked-in UDL
- Rust client workflow tests pass
- `sdk/workflows/**` fixtures pass through Rust, Swift, Kotlin, and WASM public APIs when the local platform prerequisites are present
- scanner examples use public workflow SDK APIs instead of raw protocol internals
- the iOS reference app package builds and stays behind the public
  `GrainIOSScanner`/`GrainClientIOSAdapters` surface
- starter templates keep iOS, Android, and Web/WASM app shells thin and behind
  public SDK/example APIs
- the public SDK API snapshot and compatibility matrix match the packaged
  source artifacts
- registry dry-runs record no credentials and no publication
- SDK code stays network/vendor agnostic
- the SDK release package contains same-commit source artifacts, generated
  bindings, workflow contract/docs, `manifest.json`, `SHA256SUMS`, and
  `sbom.spdx.json`
- the release package checker verifies artifact checksums, archive cleanliness,
  SDK component versions, the version-matrix hash, and SBOM package checksums
- the release package is source-only: registry publication, compiled WASM
  binaries, PWA packaging, app-store packaging, and device custody policy stay
  outside this certificate

The `ci` workflow runs the same strict platform SDK gate in the `sdk-platform`
job on a Swift 6-capable macOS runner, packages the SDK release artifacts after
that strict gate, and re-checks the release manifest before final evidence
build. The `release-evidence` tag workflow runs the same strict SDK gate before
attaching SDK source package assets to the GitHub release, so tag consumers can
audit the SDK package, evidence bundle, and manifest against one commit. After
downloading release assets, use `tools/ci/check_release_evidence_assets.py` to
verify the evidence zip and SDK source handoff together for the same tag and
commit. Set
`SDK_KOTLIN_GRADLE_OFFLINE=1` only on machines with warmed Gradle caches when
you need the Kotlin package and Android scanner example checks to prove offline
dependency resolution.

For a full repository release proof, also run:

```bash
./scripts/verify --out-dir artifacts/dev-verify-portable-client-platform-final
```

Use mandatory GitHub CI evidence bundles as final proof when local machines do
not have every platform target installed.

## App Compatibility Guidance

- Treat `scanPreview`, `scanAccept`, `listAcceptedScans`, identity, pairing,
  sync, and store snapshot methods as the portable app contract.
- Treat QR decoding, COSE verification, DAG-CBOR details, protocol runner
  operations, and raw pointer/WASM ABI details as internal implementation
  details.
- Trust material is supplied by the app or platform trust adapter. Production
  callers should use the explicit `trustAnchorID` + trust-provider APIs so
  unknown anchors fail closed with `SDK_ERR_TRUST_ANCHOR_*`; the SDK does not
  discover trust over the network or use fallback trust.
- Local trust anchor bundles use the same repo SHA as the wrapper/parser that
  loads them. The v1 shape is documented under `sdk/trust`; unsupported
  versions, unknown fields, duplicate IDs, malformed trust material, and blank
  anchors fail closed.
- Platform persistence can move to Keychain, Keystore, IndexedDB, robot secure
  elements, or device-management storage. The iOS, Android, and
  WASM/mobile-web adapter packs now provide persistence boundaries: apps persist
  the opaque `snapshotB64` returned by `exportStoreSnapshot` and restore it with
  `restoreStoreSnapshot`, preserving the Rust-owned `ClientStore`
  atomic/idempotent semantics.
