## What changed
Describe the change in one paragraph.

## Why
Technical rationale. Link ADR(s) if required.

## Scope
- [ ] Protocol (NES / CDDL / profiles)
- [ ] Conformance (vectors / harness contract)
- [ ] Core
- [ ] SDK
- [ ] Docs (human / llm)
- [ ] CI / tooling

## Invariants touched (required)
List invariant IDs from `docs/llm/INVARIANTS.md`:
- INV-...

## Conformance vectors affected (required)
- Added: POS-/NEG-...
- Modified: POS-/NEG-...
- Removed: POS-/NEG-...

## Is this breaking?
- [ ] No
- [ ] Potentially (explain)
- [ ] Yes (requires protocol major bump)

## ADR
If this PR touches any of: encoding / CID / COSE / ledger / E2E / manifest / limits / conformance / schema
- [ ] ADR required
- ADR link: (required if checked)

## Checklist
- [ ] Conformance suite passes in Strict Conformance Mode
- [ ] NES and CDDL are consistent (no drift)
- [ ] docs/llm updated (FILE_MAP / INVARIANTS / EDGE_CASES / CONFORMANCE / CHANGE_POLICY)
- [ ] Rationale documented (ADR or spec rationale)
