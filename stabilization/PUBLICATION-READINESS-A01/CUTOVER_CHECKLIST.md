# PUBLICATION-READINESS-A01 Cutover Checklist

Use this checklist when confirming that the publication repository is ready for
the final visibility change.

## A. Decide publication model

1. Confirm the local review clone and `origin/main` are byte-identical.
2. Keep the archival source repository read-only after cutover.
3. Do not rewrite the publication repository history after external review begins.

## B. Create public repository shell

1. Keep `IvGolovach/grain-protocol` private until final review is complete.
2. Configure baseline files in first commit:
- `README.md`
- `LICENSE`
- `NOTICE`
- `CONTRIBUTING.md`
3. Confirm repository settings, labels, and branch defaults match the intended publication baseline.

## C. Import code

1. In the local review clone:
- checkout the release-ready commit/tag
- confirm `git rev-parse HEAD == git rev-parse origin/main`
- confirm `git rev-parse HEAD^{tree} == git rev-parse origin/main^{tree}`
2. Remove/replace live-surface references that are not suitable for external readers:
- environment-specific absolute paths
- internal run links in docs
- stale placeholder clone/publish commands
3. Validate remote configuration before the visibility change.

## D. Governance and CI setup

1. Apply the intended public branch-protection profile:
```bash
PROTECTION_PROFILE=reviewed bash tools/github/apply_branch_protection.sh <owner>/<public-repo>
```
2. Confirm:
- required checks strict and present
- linear history on
- PRs required for `main`
- approvals/review requirements match the launch model
3. Set required secrets for workflows.

## E. Evidence and releases

1. Run CI on `main` until green.
2. Re-cut release tags in public namespace.
3. Publish new release evidence artifacts in public repo.
4. Validate evidence hash consistency on public artifacts.

## F. Final go/no-go gates

1. Publication-hygiene checks pass.
2. No absolute local paths remain in tracked files.
3. No repository-internal instructions remain in live docs.
4. No tracked generated artifacts remain.
5. Publication branch protection drift check passes.
6. Required CI and verification lanes are green.
