    # ADR-0010: Unknown critical => deterministic quarantine, with precedence

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
    Unknown t: store opaque + forward + ignore in reducers.
Unknown critical (crit): quarantine deterministically: store+forward, but exclude from semantics.
Quarantine is applied before authorization/conflict/manifest eligibility.

    ## Rationale
    Forward compatibility requires unknown payloads not to break sync.
Deterministic quarantine avoids divergence where one implementation rejects and another applies semantics.

    ## Alternatives considered
    See `docs/human/rationale/design-choices.md` and project discussion history.

    ## Consequences
    - Positive: safe forward compatibility.
- Negative: quarantined events are invisible to reducers until the critical schema becomes known.
