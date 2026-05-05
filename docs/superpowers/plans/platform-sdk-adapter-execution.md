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
| 2 | Add a storage snapshot bridge so Swift, Kotlin, and WASM wrappers can persist durable SDK state without exposing raw store mutation APIs. | In progress | `codex/sdk-storage-snapshot` | Local implementation and tests in progress |
| 3 | Add production trust-provider surfaces across SDKs with explicit anchor IDs and no fallback trust. | Planned | TBD | TBD |
| 4 | Add iOS adapter pack: Keychain/file or SQLite persistence boundary, trust provider, injected scanner flow, and scanner smoke hardening. | Planned | TBD | TBD |
| 5 | Add Android adapter pack: Keystore-backed persistence boundary, trust provider, injected CameraX-style analyzer flow, and scanner smoke hardening. | Planned | TBD | TBD |
| 6 | Add WASM/mobile-web adapter pack: IndexedDB persistence, browser scanner persistence wiring, and npm package smoke proof. | Planned | TBD | TBD |
| 7 | Harden release packaging: version matrix, SDK artifacts, checksums, SBOM/manifest consistency, and final certification. | Planned | TBD | TBD |

## Current Step 2 Definition

Step 2 is complete when:

- Rust owns a versioned, opaque store snapshot format for the reference
  `MemoryClientStore`.
- Generated Swift and Kotlin bindings expose snapshot export/restore through
  workflow-shaped DTOs, not raw mutation methods.
- WASM exposes the same snapshot export/restore surface and validates response
  shape.
- Platform wrappers can persist one `snapshotB64` string and restore a fresh
  client store after app restart.
- Snapshot restore is all-or-nothing and rejects malformed/version-mismatched
  payloads without mutating existing store state.
- The strict SDK gate and targeted tests pass locally and in PR CI before merge.
