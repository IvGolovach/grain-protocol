# Dependencies Policy

This page defines the safe automation boundary for Dependabot PRs.
The idea is simple: let boring updates stay boring, and force human review for risky ones.

ADR references:

- `adr/conformance/0003-dependabot-autonomous-safe-lane.md`
- `adr/conformance/0004-dependabot-strict-fail-closed.md`

## Goal

Dependabot safe-lane updates should remove stale review and merge friction while preserving:

- the `main protection` ruleset
- required checks
- linear history
- evidence workflows
- frozen-core safeguards

## Two-lane policy

### 1) Safe auto-merge lane (Dependabot only)

- author is the Dependabot bot account
- changed files are only in the allowlist:
  - `.github/workflows/**`
  - `.github/dependabot.yml`
  - `.github/ISSUE_TEMPLATE/**`
  - `.github/actions/**`
- required checks still run before merge
- branch update is requested automatically when behind

### 2) Manual review lane

- any PR touching non-allowlisted paths
- any PR touching frozen-critical zones (`spec/**`, `conformance/**`, `core/**`, `runner/**`, `docs/llm/**`, `tools/**`)
- semver-major workflow dependency bumps only if policy toggle `BLOCK_SEMVER_MAJOR_ACTIONS=true`

## Automation workflow

- Workflow: `/.github/workflows/dependabot-automerge.yml`
- Trigger: trusted `workflow_run` for successful `ci` pull_request runs
- Token strategy:
  - canonical and required: repository secret `DEPENDABOT_AUTOMERGE_TOKEN`
  - no fallback path

Recommended token permissions:

- Fine-grained PAT:
  - `Contents: Read & Write`
  - `Pull requests: Read & Write`
  - `Workflows: Read & Write`
  - `Metadata: Read`
- Classic PAT:
  - `repo`
  - `workflow`

Provisioning path:

- GitHub repository -> `Settings` -> `Secrets and variables` -> `Actions` -> `New repository secret`
- secret name must be exactly `DEPENDABOT_AUTOMERGE_TOKEN`

Safety design:

- does not check out PR head
- uses GitHub API only
- validates changed files against allowlist and denylist
- updates the branch when behind (`update-branch` plus `@dependabot rebase` request)
- auto-approves safe PRs
- enables auto-merge (`--auto --rebase`)
- posts deterministic audit-trail comments

## Explicit diagnostics

The workflow hard-fails with these diagnostics:

- `DEPS_ERR_TOKEN_MISSING` when `DEPENDABOT_AUTOMERGE_TOKEN` is absent
- `DEPS_ERR_TOKEN_INSUFFICIENT_PERMS` when token permission probe fails

There is no warning-only path and no fallback token.

Default major-bump behavior:

- semver-major workflow bumps are allowed by default if checks pass
- set `BLOCK_SEMVER_MAJOR_ACTIONS=true` in workflow env to force manual review for majors

## Governance notes

- CODEOWNERS documents ownership for core paths even though code owner review is not currently required on `main`
- the safe `.github` dependency path is policy-guarded by allowlist and required checks
- dependency automation must not change protocol semantics
