# Dependencies Policy (TOR-GH-DEPS-A02)

This document defines zero-friction automation boundaries for Dependabot PRs.

ADR reference: `adr/conformance/0003-dependabot-autonomous-safe-lane.md`.

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
- Trigger: `pull_request_target` for Dependabot PRs only.
- Token strategy:
  - preferred: repo secret `DEPENDABOT_AUTOMERGE_TOKEN`,
  - if using Fine-grained PAT:
    - repository access: only this repository,
    - permissions:
      - Contents: Read and Write
      - Pull requests: Read and Write
      - Workflows: Read and Write
      - Metadata: Read
  - if using Classic PAT:
    - scopes: `repo`, `workflow`,
  - fallback: `${{ github.token }}` for environments where it is sufficient.
- Safety design:
  - does not checkout PR head,
  - uses GitHub API only,
  - validates changed files against allowlist + denylist,
  - updates branch when behind (`update-branch` + `@dependabot rebase` fallback),
  - auto-approves safe PR,
  - enables auto-merge (`--auto --rebase`),
  - posts deterministic audit-trail comments.
  - fails fast with explicit diagnostics when workflow scope is insufficient.

Default major-bump behavior:
- semver-major workflow bumps are allowed by default if checks pass.
- set `BLOCK_SEMVER_MAJOR_ACTIONS=true` in workflow env to force manual lane for majors.

## Governance notes

- CODEOWNERS remains enforced for critical paths.
- Safe `.github` dependency path is policy-guarded by allowlist and required checks.
- No changes to protocol semantics are allowed through dependency automation.
