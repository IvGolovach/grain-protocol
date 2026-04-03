# PUBLICATION-READINESS-A01 Report

Date: 2026-02-26  
Repository: publication candidate repository  
Audit anchor: repository-local publication readiness scan

## Objective

Run a full readiness audit for controlled publication through a clean repository surface
without leaking local or internal-only details and without changing frozen-core semantics.

## Audit Coverage

1. Local repository content and tracked files.
2. Full git history objects (`git rev-list --objects --all` + blob scan).
3. Commit/ref naming hygiene.
4. Repository metadata and governance:
   - branch protection
   - PR/issue/release state
   - labels
   - recent CI run status

## Commands Executed (high signal)

- `git status --short --branch`
- `git rev-parse HEAD && git rev-parse origin/main`
- `git rev-list --count --all`
- `git rev-list --objects --all` + blob scan for Cyrillic
- `git ls-files -z | xargs -0 rg -n ...` for:
  - Cyrillic
  - absolute local paths
  - repository slug hard-coding
  - secret-like patterns
- `gh repo view ...`
- `gh api repos/<owner>/<repo>/branches/main/protection`
- `gh pr list --state all ...`
- `gh issue list --state all ...`
- `gh api repos/<owner>/<repo>/releases?per_page=100`
- `gh run list --limit 10 ...`

## Findings

### Resolved in this patch set

1. Absolute local path leakage in docs/contracts.
- Replaced machine-local absolute paths with repo-relative paths in:
  - `conformance/contract/runner_v1.md`
  - `docs/human/porting-grain.md`
  - `docs/llm/DOMAIN_ADAPTERS.md`
  - `docs/llm/PORTING.md`

2. Repository-local slug hard-coding in docs/checklists/scripts.
- Removed hardcoded `<owner>/<repo>` and clone literals from:
  - `docs/human/repro-checklist.md`
  - `stabilization/RC-STAB-A01/REPRO_CHECKLIST.md`
- Replaced script defaults with environment/remote detection fallback:
  - `tools/ci/build_git_provenance.py`
  - `tools/stabilization/run_rc_stab.py`
- Updated test fixture slug:
  - `tools/stabilization/test_run_rc_stab.py`

3. Publication-facing wording cleanup.
- Neutralized repository-internal references in:
  - `README.md`
  - `docs/human/github-hardening.md`
  - `docs/human/release-process.md`

### Open migration blockers/risk items

1. Branch protection profile mismatch for public launch (`P0`).
- Current live protection on `main`:
  - required approvals: `0`
  - code owner reviews: `false`
- Public-reviewed target should be:
  - required approvals: `1`
  - code owner reviews: `true`
- Action at cutover: apply
  - `PROTECTION_PROFILE=reviewed bash tools/github/apply_branch_protection.sh <owner/repo>`

2. Publication repository object must stay clean (`P0`).
- Old PR/release metadata must not be carried into the publication repository object.
- Recommended path for clean launch: a new publication repository populated from the sanitized history.

3. Release metadata portability (`P1`).
- Existing release notes may reference repository-local URLs and PR numbers.
- Re-cut releases and evidence artifacts in the publication namespace.

4. Final pre-public verification (`P1`).
- Keep the publication repository private until a final end-to-end review confirms history, tags, docs, and CI guardrails are clean.

## Current State Summary

- Sanitized publication candidate repository prepared for internal review.
- Open PRs/issues/releases from prior internal repositories are intentionally excluded from the publication repository object.
- Required checks active: `python-tooling`, `rust-core`, `ts-c01`, `ts-full`, `evidence-bundle`
- Final visibility remains private pending manual review.

## No-Change Guarantees

- No frozen-core protocol semantics were changed.
- No conformance vectors/expected outputs were altered.
- Changes are publication-readiness hygiene only (docs/tooling defaults/governance wording).
