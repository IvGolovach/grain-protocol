# PUBLICATION-READINESS-A01 Report

Date: 2026-04-04
Repository: `IvGolovach/grain-protocol`
Audit anchor: final publication-readiness review

## Objective

Run a final readiness audit for the repository object intended for publication
without changing frozen-core semantics or leaving publication-hygiene regressions.

## Audit Coverage

1. Tracked files and live-surface docs.
2. Full git history objects and tag annotations.
3. Commit/ref/message hygiene.
4. Repository metadata and governance:
   - branch protection
   - PR/issue/release state
   - labels
   - recent CI run status

## Commands Executed (high signal)

- `git status --short --branch`
- `git rev-parse HEAD && git rev-parse origin/main`
- `git rev-list --count --all`
- `python3 tools/ci/check_history_hygiene.py`
- `git ls-files -z | xargs -0 rg -n ...` for:
  - absolute local paths
  - repository-internal identifiers
  - placeholder publication commands
- `gh repo view ...`
- `gh api repos/<owner>/<repo>/branches/main/protection`
- `gh pr list --state all ...`
- `gh issue list --state all ...`
- `gh api repos/<owner>/<repo>/releases?per_page=100`
- `gh run list --limit 10 ...`

## Findings

### Current publication-hygiene state

1. Repository history, tracked files, and tag annotations pass publication-hygiene scanning.
- `python3 tools/ci/check_history_hygiene.py` reports `OK`.
- No personal email, machine-local paths, workstation fingerprints, or predecessor-repository slugs were detected at the audit anchor.

2. Live-surface docs and reporting endpoints use publication-safe wording.
- Security reporting points to GitHub Security Advisories.
- Clone and image-publish examples use the publication repository and explicit registry guidance.
- Contributor docs now describe local hygiene hooks for future commits.

3. Local guardrails exist in both CI and clone-local workflows.
- `tools/ci/check_history_hygiene.py` is enforced in repository verification.
- `.githooks/pre-commit` scans staged content.
- `.githooks/commit-msg` scans proposed commit messages.
- `scripts/setup_local_hygiene.sh` installs the repo-managed hooks per clone.

### Remaining release gate

1. Manual visibility change after final human review (`P0`).
- Keep the repository private until the final reviewer explicitly approves the visibility toggle.

## Current State Summary

- Publication candidate repository prepared for final review.
- Required checks active: `python-tooling`, `rust-core`, `ts-c01`, `ts-full`, `evidence-bundle`
- Final visibility remains private pending manual review.

## No-Change Guarantees

- No frozen-core protocol semantics were changed.
- No conformance vectors/expected outputs were altered.
- Changes are publication-readiness hygiene only (docs/tooling defaults/governance wording).
