# ADR-0003: Narrow COSE_Sign1 profile (Ed25519 only, deterministic bytes)

- Status: Accepted
- Date: 2026-02-20
- Owners: Grain Contributors
- Affects: Protocol, Conformance
- Invariants touched: (see docs/llm/INVARIANTS.md)
- Conformance vectors impacted: (see conformance/vectors)

## Context
Grain requires byte-level interoperability, offline verification, deterministic merge semantics, and privacy-by-default.
Any ambiguity becomes a forced-major risk.

## Decision
Grain v0.1 uses COSE_Sign1 untagged, Ed25519 (-19) only.
`-19` is the fully specified COSE Ed25519 algorithm identifier registered by RFC 9864 and the IANA COSE Algorithms registry.
The deprecated polymorphic EdDSA (-8) identifier is not an alias for this profile.
Protected headers MUST be exactly {1:-19, 4:kid}.
external_aad MUST be empty, unprotected MUST be {}.
COSE bytes MUST be deterministic; tag18 is forbidden.

## Rationale
COSE provides standardized signature framing. Narrowing the profile reduces interop complexity and eliminates header-policy ambiguity.
Deterministic encoding prevents signature malleability and enables reproducible attestation IDs if needed.

## Alternatives considered
See `docs/human/rationale/design-choices.md` and project discussion history.

## Consequences
- Positive: reproducible behavior across Rust/TS/Swift/Kotlin.
- Negative: no algorithm negotiation in v0.1; extensions must use new profiles/majors.

## References
- RFC 9864, Sections 2.2 and 4.2.1: fully specified Ed25519 COSE algorithm identifier `-19`.
  https://www.rfc-editor.org/rfc/rfc9864.html#section-2.2
  https://www.rfc-editor.org/rfc/rfc9864.html#section-4.2.1
- IANA COSE Algorithms registry: `Ed25519` value `-19` is Recommended; polymorphic `EdDSA` value `-8` is Deprecated.
  https://www.iana.org/assignments/cose/cose.xhtml#algorithms
