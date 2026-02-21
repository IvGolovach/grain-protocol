# GitHub Hardening Runbook (Private)

This runbook defines the minimum governance baseline after bundle-to-git migration.

## 1) Required checks on `main`

Branch protection must require:
- `python-tooling`
- `rust-core`
- `ts-c01`
- `evidence-bundle`

## 2) Apply branch protection

```bash
bash tools/github/apply_branch_protection.sh <owner/repo>
```

## 3) Tag policy

Namespaces:
- protocol tags: `protocol-*`
- repo tags: `repo-*`

Migration milestone tags:
- `protocol-v0.1.1`
- `repo-v0.2.0`
- `repo-v0.3.0`

All release tags must be signed.

## 4) CI evidence policy

- Never commit `.local-architect-reports/**`.
- CI must generate `evidence-<commit_sha>.zip` on:
  - merges to `main`
  - pushes of `protocol-*` / `repo-*` tags
- Evidence bundle must include:
  - suite summaries
  - vector manifests + hashes
  - lock/toolchain hashes
  - Rust↔TS divergence summary for C01

## 5) Dependency and intake hygiene

- Dependabot is enabled for:
  - GitHub Actions
  - Rust (`core/rust`)
  - TS runner (`runner/typescript`)
- Issue templates are required:
  - spec bug
  - conformance vector request
  - implementation bug
