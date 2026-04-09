# Governance

Grain is an open infrastructure project. The protocol is meant to outlive any single author or team.

## Project artifacts

- **Protocol (`spec/`)**: the rules.
- **Conformance suite (`conformance/`)**: the release gate.
- **Core (`core/`)**: the reference implementation.
- **SDK (`core/ts/grain-sdk/`)**: the app-facing layer built on the same protocol rules.

## Decision process

We use:
- Issues for problem statements and proposals
- Pull Requests for concrete changes
- ADRs (Architecture Decision Records) for any change that affects protocol invariants or conformance behavior

### When an ADR is required

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
- **Protocol Stewards (optional):** a small group with final say on protocol changes. In v0.1, the default posture is still "no breaking changes."

Roles can be defined/updated via PR to this file.

## Releases

- Protocol v0.1 keeps its core rules stable. Changes that alter those rules require a protocol major bump.
- Releases must pass CI gates, including conformance suite checks.
- Evidence is tied to commit SHA and produced in CI.

### Repository settings baseline

The live repository settings should match the current `main protection` ruleset and the related runbook/script:
- `docs/human/repository-settings.md`
- `tools/github/apply_branch_protection.sh`
- `tools/ci/check_branch_protection_drift.py`

Current baseline on `main`:
- Changes to `main` go through PRs.
- Direct pushes to `main` are disabled.
- Required checks:
  - `python-tooling`
  - `rust-core`
  - `evidence-bundle`
  - `capid-csprng-audit`
- Required approving reviews: `0`
- Dismiss stale reviews: `true`
- Code owner reviews: `false`
- Force pushes: disabled
- Deletions: disabled
- Conversation resolution: required
- Allowed merge methods: `merge`, `squash`, `rebase`

Related repo-level setting:
- Auto-merge: enabled
- Delete branch on merge: enabled

If the repository intentionally changes its `main protection` ruleset baseline,
update the runbook, apply script, and drift checker in the same change as this file.

### Tag policy

- Protocol tags: `protocol-*`
- Repository milestone tags: `repo-*`
- Future public release tags must be signed.
- Historical imported milestone tags may remain annotated-only.
