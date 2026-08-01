# ADR 0006: CI Economy and Trusted Runner Boundary

- Status: Accepted
- Date: 2026-08-01
- Decision ID: `GRAIN-CI-ECONOMY-A01`
- Supersedes: `adr/conformance/0004-dependabot-strict-fail-closed.md`
- Affects: CI, repository governance, dependency maintenance, and evidence timing
- Protocol invariants touched: none
- Conformance vectors impacted: none

## Context

Every pull request previously started the full CI graph, including a macOS SDK
job and evidence packaging. Dependabot opened routine PRs weekly and rebased
them automatically, so bot activity could create repeated full runs without a
maintainer action. The privileged Dependabot automerge workflow also failed in
practice because its write-capable token was intentionally absent.

Grain is public. A persistent self-hosted runner attached directly to a public
repository would allow pull-request code to reach a long-lived machine. The
project therefore needs an explicit trust boundary as well as a quieter CI
policy.

## Decision

1. Keep pull-request execution on GitHub-hosted runners. Do not attach a
   persistent self-hosted runner to the public repository. Require maintainer
   approval before any workflow from every external fork contributor starts.
2. Run all Linux verification jobs automatically for every PR.
3. Classify docs and approved metadata paths as lightweight. Treat every code,
   executable automation, protocol, conformance, SDK, script, and unknown path
   as requiring full CI.
4. Put a lightweight `full-ci-approval` job behind the protected `full-ci`
   GitHub environment. For a full-scope PR, request approval only after the
   automatic Linux graph succeeds, then wait for a maintainer to approve that
   environment before starting the GitHub-hosted macOS SDK gate and evidence
   bundle. A later commit cancels the old run and requires approval again. Run
   the full graph, including the additional smoke jobs, automatically on every
   push to `main` and on manual dispatch. Give every non-PR run a unique
   concurrency group so no `main` SHA is discarded while another run is queued.
   Keep the approval job tokenless, without checkout or references to
   environment secrets and variables; downstream code jobs do not bind the
   environment. Disable deployment-object creation for this CI-only approval.
5. Use one fail-closed branch-protection context, `CI gate`, which verifies the
   required job results instead of accepting skipped work.
6. Cancel obsolete PR runs, bound CI artifact retention, and leave tag release
   evidence workflows strict and unchanged.
7. Group routine version updates monthly, disable Dependabot rebases, limit the
   open queue, keep security updates immediate, and require manual merge.
8. Remove the privileged Dependabot automerge workflow and its PAT dependency.
9. If self-hosted capacity is added later, use a separate private executor
   repository, an isolated non-admin identity, and an ephemeral environment.

## Consequences

### Positive

- Routine bot activity cannot silently start another macOS run.
- A single stable context prevents branch-protection drift between internal job
  names and the actual release gate.
- Full platform and evidence proof remains mandatory for code changes and every
  commit merged to `main`.
- No standing write-capable automerge token is required.

### Negative / trade-offs

- A maintainer must explicitly approve the protected environment after the
  final code commit.
- Routine dependency updates arrive less often, although security updates stay
  immediate.
- A future private executor requires separate infrastructure and isolation.

## Compatibility

This changes repository process only. It does not change protocol bytes,
conformance behavior, SDK APIs, package versions, or release tag semantics.
