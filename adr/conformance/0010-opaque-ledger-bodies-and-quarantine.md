# ADR 0010. Preserve opaque ledger bodies and exclude quarantined events before reduction

- Status: Accepted
- Date: 2026-11-23
- Owners: @IvGolovach
- Affects: Conformance, Core, SDK
- Invariants touched: INV-LED-003, INV-LED-007, SDK-INV-0035, SDK-INV-0036
- Conformance vectors impacted: POS-LED-006

## Context

The CDDL body of a LedgerEvent accepts any value. Rust ignored the contents of
unknown events in the normalized reducer input. TypeScript and the vector checker
required an object. The signed transfer verifier also passed events with
unimplemented critical extensions into authorization and conflict detection.

## Decision

An opaque body can be a scalar, null, an array or a map. The normalized
reducer retains its author, sequence and CID for conflict detection.
POS-LED-006 covers the scalar, null and array forms alongside an intake.

At the signed transfer boundary, apply NES §2.4 before §6.2–§6.5. Mark signed
events with unknown critical extensions as quarantined. Exclude their slots,
grants, revocations and nutrient values from interpretation. The generic
verifier still verifies their signatures and retains their payloads. The
restricted food transfer profile supports no critical extensions and returns
its existing unsupported-profile diagnostic on those inputs.

## Consequences

The wire encoding and the v0.1 reducer arithmetic stay the same. An ordinary
unknown event can still produce a sequence conflict. A quarantined event
cannot. A key whose only binding is a quarantined grant cannot establish
the trust required to accept a transfer containing its signatures.

## References

- NES §2.3–§2.4, §6.2–§6.6 and §6.9
- CDDL LedgerEvent
- SDK ADR-0014 and conformance ADR-0007
