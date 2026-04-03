# Dependencies Policy (TOR-DEPS-STRICT-FINAL)

This document defines zero-friction automation boundaries for Dependabot PRs.

ADR references:
- `adr/conformance/0003-dependabot-autonomous-safe-lane.md`
- `adr/conformance/0004-dependabot-strict-fail-closed.md`

## Goal

Dependabot safe-lane updates must auto-resolve stale/review/merge friction while preserving:
- branch protection,
- required checks,
- linear history,
- evidence workflows,
- frozen-core safeguards.

## Two-lane policy

1. Safe auto-merge lane (Dependabot only):
- author is Dependabot bot account,
- changed files are only in allowlist:
  - `.github/workflows/**`
  - `.github/dependabot.yml`
  - `.github/ISSUE_TEMPLATE/**`
  - `.github/actions/**`
- required checks remain enforced by branch protection.
- branch update is requested automatically when behind.

2. Manual review lane:
- any PR touching non-allowlisted paths,
- any PR touching frozen-critical zones (`spec/**`, `conformance/**`, `core/**`, `runner/**`, `docs/llm/**`, `tools/**`),
- semver-major workflow dependency bumps only if policy toggle `BLOCK_SEMVER_MAJOR_ACTIONS=true`.

## Automation workflow

- Workflow: `/.github/workflows/dependabot-automerge.yml`
- Trigger: trusted `workflow_run` for successful `ci` pull_request runs.
- Token strategy:
  - canonical and required: repository secret `DEPENDABOT_AUTOMERGE_TOKEN`.
  - no fallback: the lane fails closed when this secret is absent or insufficient.
- Recommended token permissions:
  - Fine-grained PAT (repo-scoped):
    - `Contents: Read & Write`
    - `Pull requests: Read & Write`
    - `Workflows: Read & Write`
    - `Metadata: Read`
  - Classic PAT:
    - `repo`
    - `workflow`

Provisioning path:
- GitHub repository -> `Settings` -> `Secrets and variables` -> `Actions` -> `New repository secret`.
- Secret name MUST be exactly `DEPENDABOT_AUTOMERGE_TOKEN`.
- Safety design:
  - does not checkout PR head,
  - uses GitHub API only,
  - validates changed files against allowlist + denylist,
  - updates branch when behind (`update-branch` + `@dependabot rebase` request),
  - auto-approves safe PR,
  - enables auto-merge (`--auto --rebase`),
  - posts deterministic audit-trail comments.

## Strict fail-closed diagnostics

The workflow emits deterministic hard-fail diagnostics:
- `DEPS_ERR_TOKEN_MISSING` when `DEPENDABOT_AUTOMERGE_TOKEN` is absent.
- `DEPS_ERR_TOKEN_INSUFFICIENT_PERMS` when token permission probe fails.

No warning-only path and no fallback are allowed.

Default major-bump behavior:
- semver-major workflow bumps are allowed by default if checks pass.
- set `BLOCK_SEMVER_MAJOR_ACTIONS=true` in workflow env to force manual lane for majors.

## Governance notes

- CODEOWNERS remains enforced for critical paths.
- Safe `.github` dependency path is policy-guarded by allowlist and required checks.
- No changes to protocol semantics are allowed through dependency automation.
