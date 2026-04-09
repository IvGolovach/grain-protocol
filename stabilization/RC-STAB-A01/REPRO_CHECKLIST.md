# Historical RC Stabilization Repro Checklist

Goal: reproduce the imported `repo-rc-v0.4.0-rc1` stabilization outputs from a clean clone.

## 1) Clean clone and checkout RC tag
```bash
git clone --no-single-branch --tags git@github.com:IvGolovach/grain-protocol.git grain-rc-repro
cd grain-rc-repro
git checkout repo-rc-v0.4.0-rc1
```

## 2) Run interop certification bundle
```bash
tools/interop_certify.sh --out-dir artifacts/interop-repro --commit-sha "$(git rev-parse HEAD)"
```

## 3) Verify SDK strict suite lane (if SDK is part of required checks)
Run the required CI-equivalent SDK lane locally:

```bash
npm --prefix core/ts/grain-sdk run run:protocol-suite
npm --prefix core/ts/grain-sdk run test:invariants
```

Expected:
- protocol vectors pass through SDK boundary
- SDK invariant checks pass without soft-mode behavior

## 4) Compare evidence hash with RC baseline
Expected baseline:
- `evidence_sha256 35475fd1767ec873a4bfa46c51ffffd23843831e21df5c17db0e5d2162b3a1bd`

Command:
```bash
cat artifacts/interop-repro/evidence.sha256
```

## 5) Run stabilization smoke (same commit)
```bash
python3 tools/stabilization/run_rc_stab.py \
  --mode smoke \
  --out-dir artifacts/rc-stab-smoke \
  --baseline-tag repo-rc-v0.4.0-rc1 \
  --baseline-evidence-sha 35475fd1767ec873a4bfa46c51ffffd23843831e21df5c17db0e5d2162b3a1bd
```

Expected:
- `stabilization-evidence.json` verdict `PASS`
- `stabilization-evidence.json.protocol_verdict` is authoritative
- cleanup failures (if any) are warning-only (`STAB_CLEANUP_WARN`) and do not flip verdict (`INV-STAB-001`)
- no crash findings
- deterministic attack-matrix pass

## 6) Deep mode (manual; scheduled nightly currently disabled)
```bash
python3 tools/stabilization/run_rc_stab.py \
  --mode deep \
  --out-dir artifacts/rc-stab-deep \
  --baseline-tag repo-rc-v0.4.0-rc1 \
  --baseline-evidence-sha 35475fd1767ec873a4bfa46c51ffffd23843831e21df5c17db0e5d2162b3a1bd
```

Deep mode additionally validates:
- clean-clone reproducibility against RC baseline hash
- rollback rehearsal metadata checks
