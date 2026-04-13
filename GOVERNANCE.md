# Governance

Grain is open infrastructure.
The protocol is meant to outlive any single author or team.

## Project artifacts

- **Protocol (`spec/`)**: the rules
- **Conformance suite (`conformance/`)**: the release gate
- **Core (`core/`)**: the reference implementation
- **SDK (`core/ts/grain-sdk/`)**: the app-facing layer built on the same protocol rules

## Decision process

We use:

- Issues for problem statements and proposals
- Pull requests for concrete changes
- ADRs (Architecture Decision Records) for any change that affects protocol invariants or conformance behavior

### When an ADR is required

Any PR that touches these areas must include an ADR link:

- encoding or canonicalization rules
- CID blessed set or CID link encoding
- COSE profile or signing semantics
- ledger authorization, revoke, conflict rules, or reducer semantics
- E2E envelope, nonce lifecycle, or manifest eligibility and resolution
- conformance vectors or harness contract
- schemas (CDDL) or normative profiles

## Roles

- **Maintainers:** triage issues, review PRs, and keep releases moving
- **Protocol Stewards (optional):** a small group with final say on protocol changes

In v0.1, the default posture is still "no breaking changes."
Roles can be defined or updated through a PR to this file.

## Releases

- Protocol v0.1 keeps its core rules stable
- changes that alter those rules require a protocol major bump
- releases must pass CI gates, including conformance suite checks
- evidence is tied to commit SHA and produced in CI

### Repository settings baseline

The live repository settings should match the current `main protection` ruleset and the related runbook or script:

- `docs/human/repository-settings.md`
- `tools/github/apply_branch_protection.sh`
- `tools/ci/check_branch_protection_drift.py`

Current baseline on `main`:

- changes to `main` go through PRs
- direct pushes to `main` are disabled
- required checks:
  - `python-tooling`
  - `rust-core`
  - `evidence-bundle`
  - `capid-csprng-audit`
- required approving reviews: `0`
- dismiss stale reviews: `true`
- code owner reviews: `false`
- force pushes: disabled
- deletions: disabled
- conversation resolution: required
- allowed merge methods: `merge`, `squash`, `rebase`

Related repo-level settings:

- auto-merge: enabled
- delete branch on merge: enabled

If the repository intentionally changes its `main protection` ruleset baseline, update the runbook, apply script, and drift checker in the same change as this file.

### Tag policy

- protocol tags: `protocol-*`
- repository milestone tags: `repo-*`
- future public release tags must be signed
- historical imported milestone tags may remain annotated-only
