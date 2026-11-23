# ADR 0008: Exact-boundary vectors for structural limits

- Status: Accepted
- Date: 2026-11-23
- Owners: @IvGolovach
- Affects: Conformance | Docs
- Invariants touched: INV-LIM-001
- Conformance vectors impacted: POS-LIM-001, POS-LIM-002, NEG-LIM-002, POS-LIM-003, NEG-LIM-003, POS-LIM-004, NEG-LIM-004 (new)

## Context
NES §9.1 says implementations MUST support at least the baseline limits and
reject anything over them in Strict Conformance Mode. The suite only had
over-limit vectors (`NEG-LIM-001`, `NEG-OBJ-080` through `NEG-OBJ-086`). No vector
proved that a value exactly at a limit is accepted. Nesting depth, map pairs and
array length had no vectors at all.

"Nesting depth 32" was also undefined. Both cores count the top-level item as
depth 0 and reject an item at depth 33. A third implementation counting from 1
would disagree at the boundary, and the suite would not notice.

## Decision
- Define depth in `spec/profiles/cbor-profile.md` §7: the top-level item has
  depth 0; each array element, map key, map value or tag content has its
  parent's depth plus one; an item deeper than 32 rejects.
- Add accept-at-limit and reject-one-over vectors for tstr bytes (1024),
  nesting depth (32/33), map pairs (4096/4097) and array length (4096/4097).

## Rationale
"MUST support at least N" can only be checked with an accept vector at N.
The depth definition records what both cores already do.

## Alternatives considered
- Over-limit vectors only. Rejected: a decoder rejecting at N-1 would pass.

## Consequences
### Positive
- Off-by-one errors in new implementations fail the suite.

### Negative / trade-offs
- About 70 KB of extra vector data.

### Security / privacy impact
- Threats addressed: limit off-by-one parser differentials.
- New risks introduced: none.

### Interop / determinism impact
- Byte-level compatibility: unchanged; both cores passed these vectors before
  any code change.

## Compatibility
- Is this breaking? No.

## References
- NES sections: §9.1, §9.2
- Profile: `spec/profiles/cbor-profile.md` §7
- Vector IDs: POS-LIM-001 through POS-LIM-004, NEG-LIM-002 through NEG-LIM-004
