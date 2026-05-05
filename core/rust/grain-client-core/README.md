# Grain Client Core

`grain-client-core` is the portable Rust workflow layer for generated platform SDKs.

It sits above `grain-core` and below generated Swift, Kotlin, WASM, or future device bindings. Its job is to make camera-first client workflows hard to misuse without changing protocol semantics.

## Current surface

- `scan_preview(qr_string, trust_pub_b64)`
  - returns `Verified` for valid GR1 scans with explicit valid trust
  - returns `Untrusted` for valid GR1 scans without trust material
  - returns `Rejected` with deterministic diagnostics for malformed scans, malformed trust bytes, or verification failures
- `scan_accept(store, qr_string, trust_pub_b64)`
  - verifies explicit trust before persistence
  - persists accepted scans only through an atomic `ClientStore`
  - returns `AlreadyAccepted` for duplicate accepted scans without writing a duplicate record
- `platform::*`
  - defines storage and trust adapter contracts for generated SDKs
  - keeps Keychain, Keystore, SQLite, IndexedDB, and network trust lookup outside Rust core
- `ffi_types::*`
  - flattens workflow results into owned strings, vectors, and optional strings for generated bindings

## Boundary rules

- No hidden trust fallback.
- No network trust lookup in Rust core.
- No protocol rule rewrites.
- Core diagnostic codes are preserved.
- SDK-only diagnostics use the `SDK_ERR_*` namespace.
- Generated platform SDKs should expose workflows, not raw runner operations.

## Focused test

```bash
cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core
```
