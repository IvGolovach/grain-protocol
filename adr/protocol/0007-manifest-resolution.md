    # ADR-0007: Manifest resolution is deterministic and order-independent

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
    Manifest records inherit ledger conflict rules and quarantine precedence.
Resolution per CID:
- tombstone dominates (any eligible del -> unresolvable),
- exclude cap_id with chash conflicts,
- choose smallest cap_id by raw bytes among remaining puts.

    ## Rationale
    Manifest resolution must not depend on arrival order or wall-clock time.
A small set-based rule set yields deterministic results under concurrency and adversarial conditions.

    ## Alternatives considered
    See `docs/human/rationale/design-choices.md` and project discussion history.

    ## Consequences
    - Positive: interop-safe; easy to audit.
- Negative: tombstones are irreversible within v0.1 semantics; repair requires new plaintext CID.
