# Governance

Grain is an open infrastructure project. The protocol is designed to outlive any single author or team.

## Project artifacts

- **Protocol (spec/):** the constitution (normative MUST/SHOULD/MAY rules)
- **Conformance suite (conformance/):** the court (executable truth; release gate)
- **Core (core/):** reference implementation of the protocol
- **SDK (sdk/):** adoption layer; must still pass conformance

## Decision process

We use:
- Issues for problem statements and proposals
- Pull Requests for concrete changes
- ADRs (Architecture Decision Records) for any change that affects protocol invariants or conformance behavior

### When ADR is required (MUST)

Any PR that touches:
- encoding / canonicalization rules
- CID blessed set or CID link encoding
- COSE profile or signing semantics
- ledger authorization, revoke, conflict rules, reducer semantics
- E2E envelope / nonce lifecycle / manifest eligibility+resolution
- conformance vectors/harness contract
- schemas (CDDL) or normative profiles
MUST include an ADR link.

## Roles

- **Maintainers:** triage issues, review PRs, keep releases moving.
- **Protocol Stewards (optional):** a small group with final say on protocol changes. In v0.1 frozen core, the default posture is “no breaking changes”.

Roles can be defined/updated via PR to this file.

## Releases

- Protocol v0.1 is **frozen core**. Changes that alter frozen invariants require a protocol major bump.
- Releases must pass CI gates, including conformance suite checks.
- Provenance is commit-based and CI-anchored. Evidence artifacts are produced from commit SHA.

### Branch protection baseline

The live repository baseline MUST match the `autonomous` profile in:
- `docs/human/github-hardening.md`
- `tools/github/apply_branch_protection.sh`
- `tools/ci/check_branch_protection_drift.py`

Current baseline on `main`:
- `main` is protected.
- Direct pushes to `main` are disabled.
- Required checks:
  - `python-tooling`
  - `rust-core`
  - `ts-c01`
  - `ts-full`
  - `evidence-bundle`
- Required approving reviews: `0`
- Dismiss stale reviews: `true`
- Code owner reviews: `false`
- Enforce admins: `true`
- Linear history: `true`
- Force pushes: disabled
- Deletions: disabled
- Conversation resolution: required

If the repository intentionally changes branch-protection mode, update the
runbook, apply script, and drift checker in the same change as this file.

### Tag policy

- Protocol tags: `protocol-*`
- Repository milestone tags: `repo-*`
- Release tags must be signed.

## Code of Conduct

See `CODE_OF_CONDUCT.md`.
