# Portability Pack

This page is the short map for repeatable verification across machines.
If you want one command and a clear answer, start here.

## Verification paths

Blessed local bootstrap:

```bash
./scripts/bootstrap
```

Quick health view:

```bash
./scripts/doctor
```

Fast developer verification:

```bash
./scripts/verify
```

What you get:

- host toolchains required (`Rust`, `Node`, `Python`)
- no clean-tree requirement
- no container image build
- no evidence bundle generation

Release-grade certification:

Run from a clean clone:

```bash
./scripts/certify
```

Compatibility alias for older scripts or operator paths:

```bash
./scripts/ops/run_verification_pack_v1.sh
```

What you get:

- strict mode only
- container-only execution (`docker` or `podman`)
- deterministic PASS/FAIL verdict
- evidence bundle with `evidence_content.sha256`

Optional fuzz smoke:

```bash
./scripts/certify --fuzz-smoke
```

## Golden images

Build or publish script:

```bash
OWNER="${GITHUB_REPOSITORY_OWNER:-your-ghcr-namespace}"
./scripts/containers/build_golden_images.sh "ghcr.io/${OWNER}"
```

Expected image families:

- `ghcr.io/${OWNER}/grain-runner:stable`
- `ghcr.io/${OWNER}/grain-certify:stable`

If `GITHUB_REPOSITORY_OWNER` or `GOLDEN_IMAGE_REGISTRY` is already set, the script can derive the registry without an explicit argument.

## WASM read/verify path

Build:

```bash
cargo build --manifest-path core/rust/Cargo.toml -p grain-core-wasm --target wasm32-wasip1 --release
```

Run subset vectors in Node runtime:

```bash
npm --prefix runner/typescript run run:wasm-subset
```

## Evidence model

`evidence_content.sha256` is computed from deterministic artifacts only:

- vector manifests
- suite outputs
- divergence outputs
- invariant audit

`metadata.json` may contain timestamps and host details.
It is intentionally excluded from `evidence_content.sha256`.

`inputs-hashes.json` records `node -v`, so evidence-generating paths must use the exact Node patch version pinned in `.nvmrc`.
The same version must also be pinned in `docker/grain-certify.Dockerfile`.
`python3 tools/ci/check_node_runtime_pin.py` enforces that parity.
`python3 tools/ci/check_toolchain_bootstrap.py` keeps `mise.toml` aligned with the repo pins.
