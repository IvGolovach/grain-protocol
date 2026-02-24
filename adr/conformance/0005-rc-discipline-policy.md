# ADR 0004: RC Discipline and Claim Signoff Policy

- Status: Accepted
- Date: 2026-02-24
- Related TOR: `TOR-RC-DISCIPLINE-A01`

## Context

Engineering maturity is high (frozen core, strict conformance, dual implementation checks), but release-candidate handling lacked a single normative policy for:
- RC namespaces,
- stabilization window,
- no-regression revocation criteria,
- signoff authority and evidence anchoring.

Without explicit policy, release claims can drift and reproducibility guarantees weaken.

## Decision

Introduce RC governance as first-class spec policy:

1. Add `spec/RC-POLICY.md`:
- RC namespace rules,
- stabilization window,
- no-regressions criteria,
- revocation requirements,
- signoff requirements.

2. Add `spec/INTEROP-CLAIM.md`:
- bounded claim wording template,
- mandatory evidence citations.

3. Add `spec/rc/` records:
- `SIGNOFFS/template.json`
- `REVOCATIONS/template.md`

4. Extend release/cert workflows to include RC tag namespaces:
- `protocol-rc-*`
- `repo-rc-*`

## Consequences

- Pros:
  - formal, auditable RC lifecycle,
  - claim language bound to evidence artifacts,
  - rollback path without history rewrite.
- Cons:
  - additional release process overhead,
  - explicit signoff operations required per RC cycle.

