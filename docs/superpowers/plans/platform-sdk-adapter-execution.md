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
| 1 | Wire strict generated platform SDK verification into CI and document toolchain boundaries. | In progress | `codex/sdk-platform-ci` | Pending PR |
| 2 | Add a storage snapshot bridge so Swift, Kotlin, and WASM wrappers can persist durable SDK state without exposing raw store mutation APIs. | Planned | TBD | TBD |
| 3 | Add production trust-provider surfaces across SDKs with explicit anchor IDs and no fallback trust. | Planned | TBD | TBD |
| 4 | Add iOS adapter pack: Keychain/file or SQLite persistence boundary, trust provider, injected scanner flow, and scanner smoke hardening. | Planned | TBD | TBD |
| 5 | Add Android adapter pack: Keystore-backed persistence boundary, trust provider, injected CameraX-style analyzer flow, and scanner smoke hardening. | Planned | TBD | TBD |
| 6 | Add WASM/mobile-web adapter pack: IndexedDB persistence, browser scanner persistence wiring, and npm package smoke proof. | Planned | TBD | TBD |
| 7 | Harden release packaging: version matrix, SDK artifacts, checksums, SBOM/manifest consistency, and final certification. | Planned | TBD | TBD |

## Current Step 1 Definition

Step 1 is complete when:

- CI has a stable `sdk-platform` job for generated Swift, Kotlin, WASM, and
  scanner-example SDK proof.
- `scripts/sdk/verify_all_sdks.sh --strict` works on clean CI runners without
  relying on pre-warmed Gradle caches.
- WASM target readiness checks verify the active `rustc`, not only `rustup`
  metadata.
- Local docs explain when `SDK_KOTLIN_GRADLE_OFFLINE=1` is appropriate.
- PR CI and required review gates pass on the final SHA before merge.
