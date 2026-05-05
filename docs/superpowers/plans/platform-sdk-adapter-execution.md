# Platform SDK Adapter Execution Plan

**Goal:** turn the existing Rust Core plus generated SDK foundation into a
developer-friendly platform layer for iOS, Android, WASM/mobile web, and future
devices without moving protocol correctness out of Rust.

**Boundary:** Rust owns protocol semantics, workflow state, trust verification
contracts, and atomic/idempotent store behavior. Platform SDKs own durable
storage adapters, OS key stores, camera/session adapters, and app-friendly
wrappers over generated workflow APIs.

## Execution Rules

- Work one PR at a time from current `origin/main`.
- Return to this file after each PR merge before choosing the next slice.
- Keep each PR narrow enough that `main` can stay green after merge.
- Run the smallest meaningful local validation for the actual diff.
- Wait for required GitHub CI and actionable review feedback before merge.
- Do not expose QR, COSE, DAG-CBOR, raw ledger, or protocol-runner APIs through
  platform SDKs.
- Do not add hidden network trust lookup or bundled fallback trust keys.

## Seven Steps

| Step | Scope | Status | Branch / PR | Validation / Review |
| --- | --- | --- | --- | --- |
| 1 | Wire strict generated platform SDK verification into CI and document toolchain boundaries. | Merged | `codex/sdk-platform-ci` / [#41](https://github.com/IvGolovach/grain-protocol/pull/41) | Local targeted checks passed; GitHub CI passed on final SHA `ea8b242cab9244c509e43c166e231c0a39bb75ce`; merged as `6f7a57f5551cfb4765bf922a59c11952e753fcf3` |
| 2 | Add a storage snapshot bridge so Swift, Kotlin, and WASM wrappers can persist durable SDK state without exposing raw store mutation APIs. | Merged | `codex/sdk-storage-snapshot` / [#42](https://github.com/IvGolovach/grain-protocol/pull/42) | Local targeted checks passed; GitHub CI passed on final SHA `cd329fa082898adcd7e82de8148889d592dd7b34`; merged as `bd2e40af358d5441049f791550b98e3037809d7d` |
| 3 | Add production trust-provider surfaces across SDKs with explicit anchor IDs and no fallback trust. | Merged | `codex/sdk-trust-provider` / [#43](https://github.com/IvGolovach/grain-protocol/pull/43) | Local strict SDK proof passed; Greptile P1/P2 guard feedback fixed; GitHub CI passed on final SHA `100620882c7d0eeec445405c3739dbdfcc8647ae`; merged as `3d6b5265fc6091e68203a567eecd09be50509428` |
| 4 | Add iOS adapter pack: Keychain/file persistence boundary, trust provider, injected scanner flow, and scanner smoke hardening. | Merged | `codex/sdk-ios-adapter-pack` / [#44](https://github.com/IvGolovach/grain-protocol/pull/44) | Local strict SDK proof passed; Greptile feedback fixed; GitHub CI passed on final SHA `f8f9dcfaf2495378aa8337928bc40bde052e8eff`; merged as `dced9bc2eff3f7e76f068a096a06d66c9724aaa9` |
| 5 | Add Android adapter pack: Keystore-backed persistence boundary, trust provider, injected CameraX-style analyzer flow, and scanner smoke hardening. | Merged | `codex/sdk-android-adapter-pack` / [#45](https://github.com/IvGolovach/grain-protocol/pull/45) | Local strict SDK proof passed; GitHub CI passed on final SHA `c62efa6c3072b479cb016cfec321e85e679209dd`; merged as `fc16a305e6b6ad5869fcfc3e0a028ec42f8cbbf1` |
| 6 | Add WASM/mobile-web adapter pack: IndexedDB persistence, browser scanner persistence wiring, and npm package smoke proof. | Merged | `codex/sdk-wasm-adapter-pack` / [#46](https://github.com/IvGolovach/grain-protocol/pull/46) | Local strict SDK proof passed; GitHub CI passed on final SHA `743e6e40e77c103b85ea220108f1071c00d54049`; merged as `97fdaf9204494169677ad8ca0bdfbd8e086934f0` |
| 7 | Harden release packaging: version matrix, SDK artifacts, checksums, SBOM/manifest consistency, and final certification. | Merged | `codex/sdk-release-certification` / [#47](https://github.com/IvGolovach/grain-protocol/pull/47) | Local clean strict SDK package proof passed; GitHub CI passed on final SHA `2d40dbf891d46922bd8b2b1b69f4c3aa174b5e0c`; merged as `16645ca12e090624b377b71b7d3c543896e77ee3` |

## Roadmap Completion State

All seven roadmap steps are complete on `main`.

- `scripts/sdk/package_client_sdks.sh` emits release metadata that is
  independently checkable: `manifest.json`, `SHA256SUMS`, and SPDX JSON SBOM.
- The release manifest records the same-SHA version matrix, SDK component
  versions, workflow contract ID, artifact byte counts, and SHA-256 hashes.
- A repo-native checker rejects mismatched checksums, stale version-matrix
  hashes, unsafe archive entries, missing SBOM package checksums, dirty
  release metadata, and non-strict certification claims.
- The `ci` workflow proves SDK release packaging after the strict platform SDK
  lane and re-checks the package metadata before building final evidence.
- Human and LLM docs describe exactly what is certified and avoid claiming
  production App Store, Play Store, PWA, or future-device packaging.
- The strict SDK gate, package checker, ledger checks, required GitHub CI, and
  PR merge gates passed before merge.
