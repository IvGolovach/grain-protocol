# GitHub Hardening Runbook

This runbook defines the minimum governance baseline after bundle-to-git migration.

## 1) Required checks on `main`

Branch protection must require:
- `python-tooling`
- `rust-core`
- `ts-c01`
- `ts-full`
- `evidence-bundle`

CI push-to-main drift assertion validates that branch protection required checks stay aligned with policy.
`GOVERNANCE.md` must describe the same live baseline.

Autonomous baseline profile:
- pull requests required
- required approving reviews: `0`
- dismiss stale reviews: `true`
- code owner review requirement: `false`
- enforce admins: `true`
- linear history: `true`
- force pushes: disabled
- deletions: disabled
- conversation resolution: required

## 2) Apply branch protection

```bash
PROTECTION_PROFILE=autonomous bash tools/github/apply_branch_protection.sh <owner/repo>
```

When explicitly switching to public reviewed mode:

```bash
PROTECTION_PROFILE=reviewed bash tools/github/apply_branch_protection.sh <owner/repo>
```

## 3) Tag policy

Namespaces:
- protocol tags: `protocol-*`
- repo tags: `repo-*`
- protocol RC tags: `protocol-rc-*`
- repo RC tags: `repo-rc-*`

Migration milestone tags:
- `protocol-v0.1.1`
- `repo-v0.2.0`
- `repo-v0.3.0`

All release tags must be signed.

## 4) CI evidence policy

- Never commit `.local-architect-reports/**`.
- CI must generate `evidence-<commit_sha>.zip` on:
  - merges to `main`
  - pushes of `protocol-*` / `repo-*` / `protocol-rc-*` / `repo-rc-*` tags
- Evidence bundle must include:
  - suite summaries
  - vector manifests + hashes
  - lock/toolchain hashes
  - Rust↔TS divergence summaries for C01 and full
  - interop certification summaries (`interop-evidence.json`, `evidence.sha256`)

## 5) Line ending and tracked-noise policy

- `.gitattributes` is authoritative for text LF policy (`eol=lf`).
- Tracked files MUST NOT include:
  - `.DS_Store`
  - `__pycache__/`
  - `*.pyc`
  - `node_modules/`
  - `target/`
  - `*.log`, `*.tmp`, `*.swp`
- CI enforces:
  - `tools/ci/check_gitattributes_policy.py`
  - `tools/ci/check_forbidden_tracked.py`
  - `tools/ci/check_crlf_tracked.py`
  - `tools/ci/check_codeowners_coverage.py`

## 6) Interop certification workflow

- Workflow: `/.github/workflows/interop-certify.yml`
- Trigger: manual dispatch (and optional tag path)
- Output: `interop-evidence-<commit_sha>.zip`

## 7) Filemode and filters

- `core.filemode` policy on Linux CI runners is expected to be stable (`true`).
- Repository must not rely on clean/smudge filters for correctness; policy is LF via `.gitattributes`, not custom filters.

## 8) Dependabot automation lane

- Workflow: `/.github/workflows/dependabot-automerge.yml`
- Policy: `docs/human/dependencies-policy.md`
- Trigger: trusted `workflow_run` for successful `ci` pull_request runs
- Required automation secret: `DEPENDABOT_AUTOMERGE_TOKEN` (no fallback path)
- Safe lane:
  - Dependabot author only
  - allowlisted `.github` paths only
  - auto-approve + auto-merge after required checks
  - branch update/rebase requested automatically when behind
  - semver-major workflow bumps allowed by default (toggle can force manual)
- Strict failure mode:
  - missing secret -> `DEPS_ERR_TOKEN_MISSING`
  - insufficient permissions -> `DEPS_ERR_TOKEN_INSUFFICIENT_PERMS`
- Manual lane:
  - any non-allowlisted or critical path changes
  - semver-major workflow bumps only when the block toggle is enabled

## 9) Dependency and intake hygiene

- Dependabot is enabled for:
  - GitHub Actions
  - Rust (`core/rust`)
  - TS runner (`runner/typescript`)
- Zero-friction safe lane for Dependabot workflow PRs:
  - `/.github/workflows/dependabot-automerge.yml`
  - policy: `/docs/human/dependencies-policy.md`
  - required token secret: `DEPENDABOT_AUTOMERGE_TOKEN` (repo + workflow scopes)
- Issue templates are required:
  - spec bug
  - conformance vector request
  - implementation bug
