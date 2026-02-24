# ADR 0003: Dependabot Automerge Strict Fail-Closed Lane

- Status: Accepted
- Date: 2026-02-24
- Related TOR: `TOR-DEPS-STRICT-FINAL`

## Context

The previous Dependabot lane allowed fallback token behavior and warning-only paths.
This created non-deterministic automation outcomes (`works sometimes`) and could leave PRs stuck in `BEHIND` or review-blocked states.

Dependabot-triggered PR workflows are constrained in secret/token behavior, so privileged operations must run in a trusted workflow context.

## Decision

Adopt a strict fail-closed automerge lane:

1. Trigger path:
- use trusted `workflow_run` (successful `ci` pull_request run), not `pull_request_target`.

2. Authentication:
- require repository secret `DEPENDABOT_AUTOMERGE_TOKEN` as canonical token.
- no fallback to `github.token`.

3. Failure mode:
- hard-fail with deterministic codes:
  - `DEPS_ERR_TOKEN_MISSING`
  - `DEPS_ERR_TOKEN_INSUFFICIENT_PERMS`
  - `DEPS_ERR_UPDATE_BRANCH_FAILED`
  - `DEPS_ERR_APPROVE_FAILED`
  - `DEPS_ERR_ENABLE_AUTOMERGE_FAILED`

4. Safety:
- no checkout of PR code,
- API-only operations,
- strict actor/repo/path policy checks.

## Consequences

- Pros:
  - deterministic behavior for dependency lane,
  - no ambiguous warning/fallback execution paths,
  - stronger governance posture with explicit failure causes.
- Cons:
  - lane depends on correct secret provisioning and permissions,
  - failures are hard and immediate (by design).

