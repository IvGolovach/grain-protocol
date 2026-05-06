# ADR 0005: Reference Issuer Kit For Scanner Apps (TOR-SDK-A05)

Status: Accepted

Date: 2026-05-05

## Context

The generated platform SDKs can preview, verify, accept, persist, and restore
scanner records, but app teams still need a safe local way to create a real
signed `GR1:` payload for development. Without a reference issuer path, future
iOS, Android, glasses, or robot clients either depend on stale fixture strings
or reimplement QR and COSE signing details in application code.

## Decision

1. Add `core/rust/grain-issuer-kit` as a Rust reference issuer CLI/library.
2. Keep it tooling-shaped:
   - it emits signed scanner example payloads,
   - it prints public scanner material,
   - it does not expose app-facing QR/COSE internals through platform SDKs.
3. Generate ephemeral Ed25519 issuer keys by default and never print or persist
   private signing material.
4. Build the sample payload as canonical DAG-CBOR `ServingOffer` data with an
   `issuer_kid` derived from the issuer public key.
5. Sign under the existing narrow untagged COSE_Sign1 profile and encode the
   bytes into the existing `GR1:` QR transport.
6. Reject non-DAG-CBOR payloads, non-`ServingOffer` payloads, or payloads whose
   `issuer_kid` does not match the issuer public key before signing.
7. Prove generated QR strings verify through `grain-client-core` with the
   emitted `trust_pub_b64` and reject under wrong trust.

## Consequences

- App developers can create end-to-end scanner inputs without committing keys or
  copying protocol internals into app code.
- The issuer kit remains a reference development tool, not a production key
  management system, registry, trust discovery service, or publishing channel.
- Future trust-anchor bundle and real app slices can consume issuer output as a
  product-level fixture while keeping protocol semantics in `grain-core`.

## Invariants touched

- `SDK-INV-0015` (portable client scan preview contract)
- `SDK-INV-0016` (portable client scan accept preparation)
- `SDK-INV-0030` (reference issuer kit emits signed GR1 QR examples safely)
