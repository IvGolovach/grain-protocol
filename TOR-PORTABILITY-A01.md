# TOR-PORTABILITY-A01

Cross-Platform Reproducibility & Portability Pack (Private / RC-compatible)

## Intent

Close operational reproducibility risk without changing frozen-core semantics.

## Boundaries

- No changes to protocol semantics (`spec/NES-v0.1.md`, profiles, schemas).
- No suite bending to implementation.
- No host toolchain assumptions for the primary verify path.

## Implemented workstreams

1. One-command verification:
   - `scripts/verify`
   - Container-only, strict mode, fail-closed on dirty tree/runtime absence.

2. Golden images:
   - `docker/grain-runner.Dockerfile`
   - `docker/grain-certify.Dockerfile`
   - `.github/workflows/golden-images.yml`
   - `scripts/containers/build_golden_images.sh`

3. WASM read/verify path:
   - `core/rust/grain-core-wasm`
   - `runner/typescript/scripts/run-wasm-subset.ts`
   - `runner/typescript/profiles/wasm-subset.json`

4. Runner contract freeze:
   - `conformance/contract/runner_v1.md`
   - `conformance/contract/runner_v1.ops.json`
   - `conformance/contract/runner_v1.output.schema.json`
   - `tools/ci/check_runner_contract_compat.py`

5. Prohibition and cap_id enforcement:
   - `docs/llm/PROHIBITION_ZONE.md`
   - `tools/ci/check_prohibition_coverage.py`
   - `tools/ci/check_capid_csprng.py`

6. Porting/domain docs:
   - `docs/human/porting-grain.md`
   - `docs/llm/PORTING.md`
   - `docs/human/domain-adapters.md`
   - `docs/llm/DOMAIN_ADAPTERS.md`
   - `docs/human/portability-pack.md`

## CI impact

- Added jobs:
  - `capid-csprng-audit`
  - `wasm-smoke`
  - `fuzz-smoke` (push main)
  - `verify-script-smoke` (push main)
- `evidence-bundle` now includes WASM hash and summary.
- Release evidence pipeline includes runner contract + prohibition + cap_id policy checks and WASM artifacts.
