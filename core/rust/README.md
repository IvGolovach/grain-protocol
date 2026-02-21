# Grain Core Rust (TOR-02)

This directory contains the Rust reference implementation for Protocol v0.1 frozen core.

## Workspace

- `grain-core`: pure library (strict decoding, CID/COSE/E2E/manifest/ledger semantics)
- `grain-runner`: conformance runner binary (`grain-runner run --strict --vector ...`)

## Build & test

```bash
docker run --rm -v "$PWD":/work -w /work/core/rust rust:1.86 \
  bash -lc 'export PATH=/usr/local/cargo/bin:$PATH; cargo test --workspace'
```

## Run one vector

```bash
docker run --rm -v "$PWD":/work -w /work/core/rust rust:1.86 \
  bash -lc 'export PATH=/usr/local/cargo/bin:$PATH; cargo run -q -p grain-runner -- run --strict --vector /work/conformance/vectors/cid/POS-CID-001.json'
```

## Run full suite

```bash
docker run --rm -v "$PWD":/work -w /work/core/rust rust:1.86 \
  bash -lc 'export PATH=/usr/local/cargo/bin:$PATH; total=0; fails=0; for v in $(find /work/conformance/vectors -name "*.json" | sort); do total=$((total+1)); if ! cargo run -q -p grain-runner -- run --strict --vector "$v" >/dev/null; then fails=$((fails+1)); fi; done; echo "TOTAL=$total FAILS=$fails"; [ "$fails" -eq 0 ]'
```

## Determinism docs

- error code table + precedence: `core/rust/grain-core/docs/errors.md`
- invariant mapping: `docs/llm/INVARIANTS.md`
- conformance contract: `conformance/SPEC.md`

## Notes

- Protocol semantics are frozen at v0.1; do not change behavior to fit implementation convenience.
- If vectors expose ambiguous behavior, open a separate court-hardening wave (new vectors/ADR) instead of silently drifting core behavior.
