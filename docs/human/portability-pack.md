# Portability Pack (TOR-PORTABILITY-A01)

This document defines the cross-platform reproducibility baseline.

## One-command verification

Run from a clean clone:

```bash
./scripts/verify
```

Properties:
- strict mode only
- container-only execution (`docker` or `podman`)
- deterministic PASS/FAIL verdict
- evidence bundle with `evidence_content.sha256`

Optional fuzz smoke:

```bash
./scripts/verify --fuzz-smoke
```

## Golden images

Build/publish script:

```bash
./scripts/containers/build_golden_images.sh
```

Expected image families:
- `ghcr.io/<owner>/grain-runner:stable`
- `ghcr.io/<owner>/grain-certify:stable`

## WASM read/verify path

Build:

```bash
cargo build --manifest-path core/rust/Cargo.toml -p grain-core-wasm --target wasm32-wasip1 --release
```

Run subset vectors in Node runtime:

```bash
node --experimental-strip-types runner/typescript/scripts/run-wasm-subset.ts
```

## Evidence model

`evidence_content.sha256` is computed from deterministic artifacts only (vector manifests, suite outputs, divergence outputs, invariant audit).  
`metadata.json` may contain timestamps/host details and is intentionally excluded from `evidence_content.sha256`.
