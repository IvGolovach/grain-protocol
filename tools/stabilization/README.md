# Stabilization Tooling

`run_rc_stab.py` executes TOR-RC-STAB-A01 checks in two modes:
- `smoke`: PR-safe fast pressure test.
- `deep`: nightly/manual expanded pressure test with repro and rollback rehearsal.

Example:
```bash
python3 tools/stabilization/run_rc_stab.py \
  --mode smoke \
  --out-dir artifacts/rc-stab-smoke
```
