# ADR 0003: Dependabot Autonomous Safe Lane (TOR-GH-DEPS-A02)

- Status: Accepted
- Date: 2026-02-21
- Owners: Repository maintainers
- Related TOR: TOR-GH-DEPS-A02

## Context

Dependabot PRs that update GitHub Actions workflows were repeatedly blocked by:
- required code-owner review,
- stale branch (`BEHIND`) requiring manual update,
- missing token scopes for workflow-file branch updates/auto-merge.

This caused operational drag for safe infrastructure-only updates while branch protection remained strict.

## Decision

Adopt a strict safe-lane automation for Dependabot PRs:

1. Workflow: `/.github/workflows/dependabot-automerge.yml`
2. Trigger: `pull_request_target` with hard actor gate (`dependabot[bot]` / `app/dependabot`)
3. No PR-code checkout; GitHub API operations only
4. Allowlist-only file policy:
   - `.github/workflows/**`
   - `.github/dependabot.yml`
   - `.github/ISSUE_TEMPLATE/**`
   - `.github/actions/**`
5. Denylist blocks automation for critical paths:
   - `spec/**`, `conformance/**`, `core/**`, `runner/**`, `docs/llm/**`, `tools/**`
6. Authentication policy:
   - primary token: `DEPENDABOT_AUTOMERGE_TOKEN`
   - fallback token: `github.token`
7. Fail-fast diagnostics when workflow scope is insufficient.
8. Safe-lane gate requires auto-merge to be enabled at end of job.

## Consequences

Positive:
- safe Dependabot workflow PRs are handled without manual review/update-branch clicks,
- branch protection policy remains strict,
- deterministic diagnostics are emitted for missing token scope.

Trade-offs:
- repository needs `DEPENDABOT_AUTOMERGE_TOKEN` with sufficient permissions,
- automation must be continuously constrained by allowlist/denylist policy.

## Guardrails

- Policy/docs consistency is enforced by `tools/ci/check_dependabot_policy.py`
- Branch-protection drift check is enforced in CI push-to-main path.
