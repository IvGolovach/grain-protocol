## What changed
Describe the change in one short paragraph.

## Why
Explain the reason in plain language. Link ADR(s) if required.

## Docs sync (required)
- [ ] I read `docs/llm/DOC_SYNC.md`
- [ ] I updated the matching `docs/llm/*` docs for any contract or behavior change
- [ ] I updated human docs if this affects onboarding, user flow, or maintainer workflow
- [ ] I updated the relevant process docs or this template if the process changed
- [ ] I did not leave code, tests, and docs describing different behavior

## Scope
- [ ] Protocol (NES / CDDL / profiles)
- [ ] Conformance (vectors / harness contract)
- [ ] Core
- [ ] SDK
- [ ] Docs (human / llm)
- [ ] CI / tooling

## Invariants touched (required)
List invariant IDs from `docs/llm/INVARIANTS.md` if this PR changes protocol behavior.
Write `none` for docs-only or process-only PRs.
- INV-... or `none`

## Conformance vectors affected (required)
- Added: POS-/NEG-... or `none`
- Modified: POS-/NEG-... or `none`
- Removed: POS-/NEG-... or `none`

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
- [ ] docs/llm updated as needed, including `DOC_SYNC` for contract changes
- [ ] Rationale documented (ADR or spec rationale)
