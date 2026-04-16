# Repro Checklist (Clean Clone)

Use this page when you want the clean-clone answer, not the "it works on my laptop" answer.

## 1) Clean clone

```bash
git clone --no-single-branch --tags git@github.com:IvGolovach/grain-protocol.git grain-clean
cd grain-clean
git fetch --all --tags --prune
```

Prerequisites:

- Docker or Podman installed locally
- no host Rust, Node, or Python toolchain is required for `./scripts/certify`
- `./scripts/verify` uses the pinned local toolchain through `mise` when it is available
- if `mise` is not available, `./scripts/verify` fails fast unless ambient Rust, Node, and Python already match the repo pins
- `./scripts/bootstrap` is the blessed way to install those toolchains and package dependencies
- if you run host-side TS commands, developer verification, or RC stabilization manually, use the exact Node patch version pinned in `.nvmrc`

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

If this clone is not already on the pinned local toolchain, run `./scripts/bootstrap` first.

```bash
python3 tools/ci/check_gitattributes_policy.py
python3 tools/ci/check_forbidden_tracked.py
python3 tools/ci/check_crlf_tracked.py
python3 tools/check_spec_drift.py
python3 tools/check_llm_docs.py
python3 tools/validate_vectors.py
python3 tools/ci/check_node_runtime_pin.py
python3 tools/ci/check_toolchain_bootstrap.py
python3 tools/ci/check_sdk_no_network.py
python3 tools/ci/check_sdk_ai_boundary.py
npm --prefix core/ts/grain-sdk-ai run test:boundary
```

Expected:

- every command prints `OK` and exits `0`

## 4) Fast developer verification

```bash
./scripts/verify --out-dir artifacts/dev-verify-local
```

Expected:

- Rust strict suite PASS
- TS strict suite PASS
- SDK core suite PASS
- divergence `C01/full = 0`
- property tests failed = `0`
- AI sidecar boundary checks PASS
- summary artifacts produced under `artifacts/dev-verify-local`

## 5) Release-grade certification

```bash
./scripts/certify --out-dir artifacts/verify-local
```

Expected:

- containerized strict verification PASS
- `evidence_content.sha256` produced

## 6) Compare with CI artifact

Download the evidence artifact from the latest successful CI or release run and compare:

```bash
cat artifacts/verify-local/evidence/evidence_content.sha256
```

Confirm the first-line hash (`evidence_sha256 ...`) matches the reference run for the same commit.

## 7) RC stabilization smoke (only during an active RC window)

Use the current RC tag and baseline evidence hash from the matching stabilization record.
Do not reuse an old RC baseline for a new release window.

```bash
RC_TAG="repo-rc-vX.Y.Z-rcN"
RC_BASELINE_SHA="<evidence_sha256>"

python3 tools/stabilization/run_rc_stab.py \
  --mode smoke \
  --out-dir /tmp/rc-stab-smoke \
  --baseline-tag "${RC_TAG}" \
  --baseline-evidence-sha "${RC_BASELINE_SHA}"
```

Expected:

- `stabilization-evidence.json` verdict is `PASS`
- no fuzz crash or divergence findings
- attack matrix has no `FOUND_BUG`
- `reproducibility-report.md` shows `Observed node version` equal to the exact patch pinned in `.nvmrc`
