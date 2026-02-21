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
