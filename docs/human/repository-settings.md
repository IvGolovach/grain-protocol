# GitHub Repository Settings

This page records the GitHub settings the canonical repository should keep.
If you only want to contribute code, you can skip this page.
If you maintain the repo, this page saves you from guessing.

## 1) Current `main` ruleset and repo settings

`main` should require the single final check `CI gate`.

`CI gate` is fail-closed: it requires every automatic Linux job, and it also
requires the GitHub-hosted macOS SDK and evidence jobs when the PR scope needs
full verification. Individual job names remain visible for diagnosis but are
not separate branch-protection contracts.

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
- fork PR workflow approval: `all_external_contributors`
- environment `full-ci`: one required maintainer reviewer, self-review allowed,
  no branch restriction, no secrets, and no variables
- vulnerability alerts: enabled
- Dependabot security updates: enabled

`GOVERNANCE.md` should describe the same live baseline.

## 2) Apply or update the `main` ruleset

Use the script, not manual click memory:

```bash
PROTECTION_PROFILE=autonomous bash tools/github/apply_branch_protection.sh <owner/repo>
```

The script updates the repository ruleset `main protection` through the GitHub rulesets API.
It does not use the legacy branch-protection endpoint.

After changing the ruleset, run the drift checker with a token that can read
repository rules:

```bash
GH_TOKEN="$(gh auth token)" python3 tools/ci/check_branch_protection_drift.py --repo <owner/repo>
```

The `main` CI run performs the same ruleset check with the built-in
`github.token` and also verifies the reviewer and protection rules on the
protected `full-ci` environment. The built-in token cannot list environment
secret or variable metadata or the owner-only fork approval setting, so it does
not claim to verify those values.

Apply or repair the protected environment with the repository script:

```bash
bash tools/github/apply_full_ci_environment.sh <owner/repo> <reviewer-login>
```

The script keeps the environment unrestricted for fork PRs, requires the named
reviewer, permits self-review for a single-maintainer repository, and uses the
owner's authenticated GitHub CLI session to require approval for every external
fork contributor and fail if the environment contains any secrets or variables.
It does not delete unexpected data automatically.

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
- `repo-rc-v0.4.0-rc2`
- `repo-rc-v0.4.0-rc3`
- `repo-rc-v0.4.0-rc4`
- `repo-rc-v0.4.0-rc5`
- `repo-v0.4.0`
- `repo-v0.4.1`
- `repo-v0.4.2`
- `repo-v0.4.3`

Future public release tags should be signed.
Historical imported milestone tags have GitHub release pages now, but some older ones still rely on reconstructed notes or partial assets.

## 4) CI evidence policy

- Never commit `.local-architect-reports/**`.
- CI must generate `evidence-<commit_sha>.zip` on:
  - merges to `main`
  - pushes of `protocol-*`, `repo-*`, `protocol-rc-*`, and `repo-rc-*` tags
- A full-scope PR can also generate the same-commit evidence bundle after a
  maintainer approves the protected `full-ci` environment. Full scope includes
  code, executable automation, protocol, conformance, SDK, script, and unknown
  paths.
- Tag release evidence must also attach the same-commit SDK source release
  package assets, including the TypeScript source SDK packet, after the strict
  platform SDK gate passes.
- Evidence bundle must include:
  - suite summaries
  - vector manifests plus hashes
  - lock and toolchain hashes
  - Rust versus TS divergence summaries for `C01` and full
  - interop certification summaries (`interop-evidence.json`, `evidence.sha256`)
  - SDK strict-suite summary when SDK release packaging is part of the workflow

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

## 8) CI and dependency automation

- Policy doc: `docs/human/dependencies-policy.md`
- Routine dependency version updates: monthly and grouped per ecosystem
- Automatic rebases: disabled
- Open version-update limit: at most `2` per ecosystem
- Dependency merge: manual after `CI gate`
- Privileged Dependabot automerge workflow or PAT: none
- Pull-request runners: GitHub-hosted only

For a PR that requires full verification, the `Approve full CI` job appears
only after the automatic Linux jobs succeed and then waits before allocating
its runner. Open the workflow run, select `Review deployments`, select
`full-ci`, and choose `Approve and deploy` after reviewing the final commit. A
later commit cancels the old run and creates a new approval request, so a rebase
or bot update cannot silently start another macOS run or reuse old proof. The
environment has no secrets or variables. The approval job has no token, does
not check out repository code, and does not reference environment data; jobs
that execute PR code only depend on its result and do not bind the environment.
The CI-only approval uses `deployment: false`, so it does not create deployment
history entries while the required-reviewer rule still applies.

External fork PRs have an earlier, separate gate: after reviewing the diff, a
maintainer must choose `Approve workflows to run` before any Linux job starts.
This applies to every external contributor, not only first-time contributors.

## 9) Dependency and intake hygiene

- Dependabot is enabled for:
  - GitHub Actions
  - Rust (`core/rust`)
  - TS runner (`runner/typescript`)
- Vulnerability alerts and Dependabot security updates remain enabled so the
  monthly routine schedule does not delay security fixes.
- Issue forms live in `/.github/ISSUE_TEMPLATE/`
- Blank issues are acceptable if GitHub falls back instead of rendering forms
