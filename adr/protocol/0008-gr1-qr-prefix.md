# ADR-0008: QR transport prefix fixed to GR1:

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
Embedded QR payloads MUST use prefix GR1: and pipeline GR1: + Base45(zlib(COSE_BYTES)).
Incompatible future formats MUST use new prefixes (GR2:, etc.).

## Rationale
Physical artifacts require stable identifiers.
Prefix versioning prevents silent incompatibility and supports long-lived scanning.

## Alternatives considered
See `docs/human/rationale/design-choices.md` and project discussion history.

## Consequences
- Positive: operational stability in the physical world.
- Negative: old artifacts cannot be upgraded; new formats must use new prefixes.
