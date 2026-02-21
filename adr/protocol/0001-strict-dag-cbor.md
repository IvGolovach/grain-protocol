    # ADR-0001: Strict DAG-CBOR and reject non-canonical encodings

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
    Protocol objects MUST be encoded as strict DAG-CBOR.
Decoders MUST reject non-canonical encodings and MUST reject duplicate map keys at any nesting level.
Tags are forbidden except tag 42 for CID links.

    ## Rationale
    Canonical bytes are required for stable content IDs and byte-level interop.
Accepting non-canonical encodings introduces malleability and divergent CIDs across implementations.
Duplicate map keys are a known source of parsing ambiguity; rejecting them removes an entire class of parser differentials.

    ## Alternatives considered
    See `docs/human/rationale/design-choices.md` and project discussion history.

    ## Consequences
    - Positive: deterministic object bytes; stable CIDs; fewer security footguns.
- Negative: some permissive CBOR libraries must be configured or wrapped to enforce strictness.
