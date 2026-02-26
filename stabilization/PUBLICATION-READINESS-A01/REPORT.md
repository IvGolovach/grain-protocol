# PUBLICATION-READINESS-A01 Report

Date: 2026-02-26  
Repository: `<owner>/<repo>` (canonical source repository)  
Audit commit anchor: `5281e81fc44f4e0c63bf1c04d74d813bc96635fe`

## Objective

Run a full migration-readiness audit for publishing via a new public repository
without leaking local/source-repository-only details and without changing frozen-core semantics.

## Audit Coverage

1. Local repository content and tracked files.
2. Full git history objects (`git rev-list --objects --all` + blob scan).
3. Commit/ref naming hygiene.
4. GitHub metadata and governance:
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
  - source repo slug hard-coding
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
- Replaced `...` with repo-relative paths in:
  - `conformance/contract/runner_v1.md`
  - `docs/human/porting-grain.md`
  - `docs/llm/DOMAIN_ADAPTERS.md`
  - `docs/llm/PORTING.md`

2. Private slug hard-coding in docs/checklists/scripts.
- Removed `<owner>/<repo>` and SSH clone literals from:
  - `docs/human/repro-checklist.md`
  - `stabilization/RC-STAB-A01/REPRO_CHECKLIST.md`
- Replaced script defaults with environment/remote detection fallback:
  - `tools/ci/build_git_provenance.py`
  - `tools/stabilization/run_rc_stab.py`
- Updated test fixture slug:
  - `tools/stabilization/test_run_rc_stab.py`

3. Public-facing wording cleanup.
- Neutralized source-repository-only heading references in:
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

2. Public history strategy decision (`P0`).
- If you publish this same repository, all existing PR/release metadata stays visible.
- Recommended path for clean launch: new publication (snapshot or curated history).

3. Release metadata portability (`P1`).
- Existing release notes reference source repository URLs and private PR numbers.
- For new public repo, re-cut releases and evidence artifacts in the new namespace.

## Current State Summary

- Local `main` == `origin/main` at `5281e81...`
- Open PRs: none
- Open issues: 1 (`#23`, nightly stabilization failure notice)
- Required checks active: `python-tooling`, `rust-core`, `ts-c01`, `ts-full`, `evidence-bundle`
- Recent `main` CI runs: successful

## No-Change Guarantees

- No frozen-core protocol semantics were changed.
- No conformance vectors/expected outputs were altered.
- Changes are migration hygiene only (docs/tooling defaults/governance wording).
