# RC Stabilization Repro Checklist

Goal: prove RC stabilization outputs are reproducible from clean clone.

## 1) Clean clone and checkout RC tag
```bash
git clone --no-single-branch --tags git@github.com:<owner>/<repo>.git grain-rc-repro
cd grain-rc-repro
git checkout repo-rc-v0.4.0-rc1
```

## 2) Run interop certification bundle
```bash
tools/interop_certify.sh --out-dir artifacts/interop-repro --commit-sha "$(git rev-parse HEAD)"
```

## 3) Compare evidence hash with RC baseline
Expected baseline:
- `evidence_sha256 35475fd1767ec873a4bfa46c51ffffd23843831e21df5c17db0e5d2162b3a1bd`

Command:
```bash
cat artifacts/interop-repro/evidence.sha256
```

## 4) Run stabilization smoke (same commit)
```bash
python3 tools/stabilization/run_rc_stab.py \
  --mode smoke \
  --out-dir artifacts/rc-stab-smoke \
  --baseline-tag repo-rc-v0.4.0-rc1 \
  --baseline-evidence-sha 35475fd1767ec873a4bfa46c51ffffd23843831e21df5c17db0e5d2162b3a1bd
```

Expected:
- `stabilization-evidence.json` verdict `PASS`
- no crash findings
- deterministic attack-matrix pass

## 5) Deep mode (nightly/manual)
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
