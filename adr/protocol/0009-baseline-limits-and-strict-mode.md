    # ADR-0009: Baseline limits + Strict Conformance Mode

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
    v0.1 defines baseline limits (CBL) that implementations MUST support at minimum.
Implementations MUST implement Strict Conformance Mode enforcing CBL exactly with deterministic limit errors.
Implementations MAY support higher limits outside strict mode, but behavior must be deterministic and documented.

    ## Rationale
    Fixed numbers are needed for conformance determinism, but operational deployments may require higher limits.
This split avoids forced-major changes driven purely by practice while keeping interop testing strict.

    ## Alternatives considered
    See `docs/human/rationale/design-choices.md` and project discussion history.

    ## Consequences
    - Positive: stable conformance; operational flexibility.
- Negative: deployers must choose/communicate limit profiles explicitly.
