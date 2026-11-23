# ADR 0007: Vectors for Events Without Reducer Semantics

- Status: Accepted
- Date: 2026-11-23
- Owners: @IvGolovach
- Affects: Protocol | Conformance | Docs
- Invariants touched: INV-LED-007, INV-LED-008 (new); INV-LED-003, INV-LED-004
- Conformance vectors impacted: POS-LED-003, NEG-LED-050, POS-LED-004 (new)

## Context

NES §2.3 requires unknown event types to be stored, forwarded and ignored by
reducers. No `ledger_reduce` vector contained such an event, so the rule was
not part of the release gate.

The CDDL comment on `CorrectionEvent` said the reducer "treats target as voided
and applies later events". NES defined no void or correction semantics, no
vector covered them, and both the Rust and TypeScript reducers ignore
`VoidEvent` and `CorrectionEvent`. Documentation and frozen behavior disagreed.

## Decision

1. Add NES §6.9. In v0.1 only authorized, non-conflicted `IntakeEvent` records
   affect totals. Every other valid event, including unknown `t`, `VoidEvent`
   and `CorrectionEvent`, is retained, still participates in `(ak, seq)` conflict
   detection, and MUST NOT change `sum_mean` or `sum_var`.
2. Correct the CDDL comment to match NES §6.9.
3. Add three strict `ledger_reduce` vectors:
   - `POS-LED-003`: an unknown-type event whose body carries kcal-shaped
     `mean`/`var` fields does not change totals;
   - `NEG-LED-050`: an unknown-type event and an `IntakeEvent` at the same
     `(ak, seq)` with different payload CIDs conflict and are both ignored;
   - `POS-LED-004`: `VoidEvent` and `CorrectionEvent` leave the target's
     contribution in place.

## Rationale

Both engines already produced these outputs before the change, so the vectors
lock existing frozen behavior rather than redefining it. Making the reducer
apply voids would change outputs for existing valid ledgers. FREEZE-CONFIRMATION
§2 classifies that as major-level, so it is out of scope for v0.1.

## Alternatives considered

- Make reducers apply `VoidEvent` and `CorrectionEvent`. Rejected for v0.1: it
  breaks reducer-output stability for already-valid inputs.
- Delete the CDDL comment only. Rejected: it leaves app builders guessing
  whether voids are normative.

## Consequences

### Positive
- NES §2.3 and §6.5 are enforced by the release gate for unknown types.
- Applications know that voids and corrections are presentation-level in v0.1.

### Negative / trade-offs
- An application that needs deletes or edits reflected in normative totals has
  no v0.1 mechanism. That needs a versioned reducer profile or protocol v2.

### Security / privacy impact
- Threats addressed: a crafted unknown-type event cannot inject totals by
  imitating `IntakeEvent` body fields.
- New risks introduced: none.

### Interop / determinism impact
- Byte-level compatibility: unchanged.
- Order-independence / merge semantics: unchanged; conflict detection stays
  type-independent.
- Forward compatibility: new event types stay additive under §2.3.

## Compatibility
- Is this breaking? No. Rust and TypeScript outputs were identical before and after.

## References
- NES sections: §2.3, §6.5, §6.7, §6.9
- CDDL types: `LedgerEvent`, `VoidEvent`, `CorrectionEvent`
- Vector IDs: POS-LED-003, NEG-LED-050, POS-LED-004
