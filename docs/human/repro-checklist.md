# Repro Checklist (Clean Clone)

Use this checklist to verify reproducibility from a fresh clone.

## 1) Clean clone

```bash
git clone --no-single-branch --tags git@github.com:<owner>/<repo>.git grain-clean
cd grain-clean
git fetch --all --tags --prune
```

## 2) Git parity checks

```bash
git rev-parse HEAD
git rev-parse origin/main
git rev-parse HEAD^{tree}
git rev-parse origin/main^{tree}
git rev-list --left-right --count origin/main...HEAD
git status --porcelain=v1
```

Expected:
- `HEAD == origin/main`
- `HEAD^{tree} == origin/main^{tree}`
- `ahead/behind = 0 0`
- empty `git status --porcelain`

## 3) Repository hygiene checks

```bash
python3 tools/ci/check_gitattributes_policy.py
python3 tools/ci/check_forbidden_tracked.py
python3 tools/ci/check_crlf_tracked.py
python3 tools/check_spec_drift.py
python3 tools/check_llm_docs.py
python3 tools/validate_vectors.py
```

Expected:
- all commands print `OK` and exit `0`.

## 4) Certification run

```bash
tools/interop_certify.sh --out-dir /tmp/interop-cert --commit-sha "$(git rev-parse HEAD)"
```

Expected:
- Rust strict suite PASS
- TS strict suite PASS
- divergence C01/full = 0
- property tests failed = 0
- invariants audit PASS
- `evidence.sha256` produced.

## 5) Compare with CI artifact

Download evidence artifact from latest successful CI/release run and compare:

```bash
sha256sum /tmp/interop-cert/evidence.sha256
```

Confirm the first line hash (`evidence_sha256 ...`) matches the reference run for the same commit.
