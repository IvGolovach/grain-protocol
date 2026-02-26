# Stabilization Tooling

`run_rc_stab.py` executes TOR-RC-STAB-A01 checks in two modes:
- `smoke`: PR-safe fast pressure test.
- `deep`: nightly/manual expanded pressure test with repro and rollback rehearsal.

Cleanup contract:
- protocol verdict is decided by stabilization gates (attack/fuzz/properties/repro/rollback).
- cleanup runs as best-effort and emits `STAB_CLEANUP_WARN` on failure.
- cleanup warnings are recorded in `stabilization-evidence.json.cleanup` and MUST NOT flip `PASS` to `FAIL`.

Example:
```bash
python3 tools/stabilization/run_rc_stab.py \
  --mode smoke \
  --out-dir artifacts/rc-stab-smoke
```
