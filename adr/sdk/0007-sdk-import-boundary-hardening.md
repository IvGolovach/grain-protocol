# ADR 0007: SDK Import Boundary Hardening

Status: Accepted

Date: 2026-06-01

## Context

The TypeScript SDK already performed strict base64 checks for imported identity
and transport material. Two additional import-boundary risks remained:

1. Identity bundles could carry internally inconsistent metadata, such as a
   `root_kid` that did not match `root_pub_b64`, device key IDs that did not
   match their public keys, or an active key that was not authorized by the
   bundle.
2. Raw CBOR-seq export from JSON rows accepted JavaScript floating-point
   numbers even though the Rust/core parser and the protocol integer domains
   are deterministic integer-only boundaries.

Both paths are SDK misuse hazards. They do not require a protocol core change;
the SDK can fail closed before mutation or export.

## Decision

1. Validate identity bundles before import mutation:
   - `root_pub_b64` must decode to a 32-byte public key.
   - `root_kid` must equal the SDK-derived key ID for `root_pub_b64`.
   - every device key `ak` must equal the SDK-derived key ID for `pub_b64`.
   - device key IDs must be unique.
   - `active_ak` must be present in the authorized device set.
   - imported bundles must not replace an already-initialized store with a
     different root.
   - sequence-state values must be unsigned 64-bit decimal strings.
2. Keep `identity.importBundle()` atomic: malformed or conflicting bundles
   reject before partial writes, or roll back on mutation failure.
3. Reject non-finite, fractional, or unsafe JavaScript numbers in raw CBOR-seq
   JSON export with an SDK diagnostic.
4. Cover the new reject paths in the TypeScript SDK invariant suite.

## Consequences

- Apps cannot silently import a forged identity root/device mapping into an
  initialized SDK store.
- App code cannot use raw CBOR-seq JSON export to produce bytes that the Rust
  side later rejects because of numeric-domain drift.
- The protocol frozen core remains unchanged.
- SDK import behavior is stricter and safer for app integrations.

## Invariants touched

- SDK-INV-0011
- SDK-INV-0013
- SDK-INV-0014
