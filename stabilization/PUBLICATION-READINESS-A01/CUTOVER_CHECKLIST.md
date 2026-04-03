# PUBLICATION-READINESS-A01 Cutover Checklist

Use this checklist when preparing the publication repository from the vetted source history.

## A. Decide publication model

1. Choose one:
- Full sanitized history launch (preferred when the cleaned history is ready).
- Curated milestone history launch (only if a narrower public surface is intentionally desired).
2. Keep the archival source repository read-only after cutover.
3. Do not rewrite the publication repository history after external review begins.

## B. Create public repository shell

1. Create empty repository `<owner>/<public-repo>` and keep it private until final review is complete.
2. Configure baseline files in first commit:
- `README.md`
- `LICENSE`
- `NOTICE`
- `SECURITY.md`
- `CONTRIBUTING.md`
- `CODE_OF_CONDUCT.md`
3. Confirm repository settings, labels, and branch defaults match the intended publication baseline.

## C. Import code

1. From the vetted source repository:
- checkout release-ready commit/tag
- mirror the sanitized history or import the release-ready tree (exclude `.git` when doing a snapshot import)
2. Remove/replace repository-internal references:
- owner/repo literals
- environment-specific absolute paths
- internal run links in docs
3. Validate remote configuration before the first shared push.

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
3. No hardcoded repository-internal slug in tracked files.
4. No tracked generated artifacts.
5. Publication branch protection drift check passes.
6. README/docs have no repository-internal instructions.
