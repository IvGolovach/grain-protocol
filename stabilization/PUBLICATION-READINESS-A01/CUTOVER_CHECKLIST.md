# PUBLICATION-READINESS-A01 Cutover Checklist

Use this checklist when creating the new public repository from private canonical source.

## A. Decide publication model

1. Choose one:
- Snapshot launch (single initial public commit).
- Curated history launch (selected clean commits only).
2. Keep source repo as canonical provenance source.
3. Do not force-rewrite canonical private history.

## B. Create public repository shell

1. Create empty public repo `<owner>/<public-repo>`.
2. Configure baseline files in first commit:
- `README.md`
- `LICENSE`
- `NOTICE`
- `SECURITY.md`
- `CONTRIBUTING.md`
- `CODE_OF_CONDUCT.md`
3. Add statement:
- `Public history starts here; earlier development was private.`

## C. Import code

1. From canonical source repo:
- checkout release-ready commit/tag
- copy source tree (exclude `.git`)
2. Remove/replace source-repository-only references:
- owner/repo literals
- private clone URLs
- private run links in docs
3. Commit as initial public import.

## D. Governance and CI hardening

1. Apply public branch protection profile:
```bash
PROTECTION_PROFILE=reviewed bash tools/github/apply_branch_protection.sh <owner>/<public-repo>
```
2. Confirm:
- required checks strict and present
- linear history on
- approvals = 1
- codeowner reviews enabled
3. Set required secrets for workflows.

## E. Evidence and releases

1. Run CI on `main` until green.
2. Re-cut release tags in public namespace.
3. Publish new release evidence artifacts in public repo.
4. Validate evidence hash consistency on public artifacts.

## F. Final go/no-go gates

1. No Cyrillic in tracked files.
2. No absolute local paths in tracked files.
3. No hardcoded source slug in tracked files.
4. No tracked generated artifacts.
5. Public branch protection drift check passes.
6. Public README/docs have no source-repository-only instructions.
