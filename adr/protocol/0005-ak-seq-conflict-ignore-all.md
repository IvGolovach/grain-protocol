# ADR-0005: (ak, seq) conflict rule = ignore all

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
For any (ak, seq), if >=2 different valid payload CIDs exist, mark conflicted and ignore all events at that (ak,seq).

## Rationale
“Winner selection” strategies embed hidden ordering assumptions and can diverge across implementations.
Ignore-all is deterministic and safer; it surfaces the anomaly explicitly.

## Alternatives considered
See `docs/human/rationale/design-choices.md` and project discussion history.

## Consequences
- Positive: deterministic merge; avoids adversarial tie-break games.
- Negative: conflicts reduce usable data; requires diagnostics/repair workflows.
