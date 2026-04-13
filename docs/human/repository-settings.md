# GitHub Repository Settings

This page records the GitHub settings the canonical repository should keep.
If you only want to contribute code, you can skip this page.
If you maintain the repo, this page saves you from guessing.

## 1) Current `main` ruleset and repo settings

`main` should require these checks:

- `python-tooling`
- `rust-core`
- `evidence-bundle`
- `capid-csprng-audit`

The live `main protection` ruleset should be:

- pull requests required
- required approving reviews: `0`
- dismiss stale reviews: `true`
- code owner review requirement: `false`
- force pushes: disabled
- deletions: disabled
- conversation resolution: required
- allowed merge methods: `merge`, `squash`, `rebase`

Related repo-level settings:

- delete branch on merge: enabled
- auto-merge: enabled

`GOVERNANCE.md` should describe the same live baseline.

## 2) Apply or update the `main` ruleset

Use the script, not manual click memory:

```bash
PROTECTION_PROFILE=autonomous bash tools/github/apply_branch_protection.sh <owner/repo>
```

The script updates the repository ruleset `main protection` through the GitHub rulesets API.
It does not use the legacy branch-protection endpoint.

If the maintainer team grows and you want review-required mode later:

```bash
PROTECTION_PROFILE=reviewed bash tools/github/apply_branch_protection.sh <owner/repo>
```

## 3) Tag policy

Namespaces:

- protocol tags: `protocol-*`
- repo tags: `repo-*`
- protocol RC tags: `protocol-rc-*`
- repo RC tags: `repo-rc-*`

Historical milestone tags currently present:

- `protocol-v0.1.1`
- `repo-v0.2.0`
- `repo-v0.3.0`
- `repo-v0.3.1`
- `repo-rc-v0.4.0-rc1`

Future public release tags should be signed.
Historical imported milestone tags have GitHub release pages now, but some older ones still rely on reconstructed notes or partial assets.

## 4) CI evidence policy

- Never commit `.local-architect-reports/**`.
- CI must generate `evidence-<commit_sha>.zip` on:
  - merges to `main`
  - pushes of `protocol-*`, `repo-*`, `protocol-rc-*`, and `repo-rc-*` tags
- Evidence bundle must include:
  - suite summaries
  - vector manifests plus hashes
  - lock and toolchain hashes
  - Rust versus TS divergence summaries for `C01` and full
  - interop certification summaries (`interop-evidence.json`, `evidence.sha256`)

## 5) Line ending and tracked-noise policy

`.gitattributes` is the source of truth for text LF policy (`eol=lf`).

Tracked files must not include:

- `.DS_Store`
- `__pycache__/`
- `*.pyc`
- `node_modules/`
- `target/`
- `*.log`
- `*.tmp`
- `*.swp`

CI enforces:

- `tools/ci/check_gitattributes_policy.py`
- `tools/ci/check_forbidden_tracked.py`
- `tools/ci/check_history_hygiene.py`
- `tools/ci/check_crlf_tracked.py`
- `tools/ci/check_codeowners_coverage.py`

## 6) Interop certification workflow

- Workflow: `/.github/workflows/interop-certify.yml`
- Trigger: manual dispatch and optional tag path
- Output: `interop-evidence-<commit_sha>.zip`

## 7) Filemode and filters

- `core.filemode` policy on Linux CI runners is expected to stay stable (`true`).
- The repository must not rely on clean or smudge filters for correctness.
- LF policy comes from `.gitattributes`, not custom filters.

## 8) Advanced automation details

- Workflow: `/.github/workflows/dependabot-automerge.yml`
- Policy doc: `docs/human/dependencies-policy.md`
- Trigger: trusted `workflow_run` for successful `ci` pull_request runs
- Required automation secret: `DEPENDABOT_AUTOMERGE_TOKEN`

Safe lane:

- Dependabot author only
- allowlisted `.github` paths only
- auto-approve plus auto-merge after required checks
- branch update or rebase requested automatically when behind
- semver-major workflow bumps allowed by default unless the block toggle says otherwise

Explicit failure mode:

- missing secret -> `DEPS_ERR_TOKEN_MISSING`
- insufficient permissions -> `DEPS_ERR_TOKEN_INSUFFICIENT_PERMS`

Manual lane:

- any non-allowlisted or critical path changes
- semver-major workflow bumps only when the block toggle is enabled

## 9) Dependency and intake hygiene

- Dependabot is enabled for:
  - GitHub Actions
  - Rust (`core/rust`)
  - TS runner (`runner/typescript`)
- Issue forms live in `/.github/ISSUE_TEMPLATE/`
- Blank issues are acceptable if GitHub falls back instead of rendering forms
