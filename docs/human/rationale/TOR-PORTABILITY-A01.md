# TOR-PORTABILITY-A01

Cross-Platform Reproducibility & Portability Pack

Code: `TOR-PORTABILITY-A01`
Status: Active, RC-compatible
Class: Tooling / Packaging / Portability / Evidence (no frozen-core semantic changes)

## 0) Problem

Grain protocol semantics and interop are stabilized, but operational reproducibility can still drift:
- toolchain/runtime differences (Rust/Node/Python),
- OS/environment differences (macOS/Linux/CI),
- hidden local dependencies and local-only behavior,
- portability cost for new runtimes (WASM/edge/new language runner).

This TOR closes that risk class without changing protocol semantics.

## 1) Goal

From clean clone, one command:

```bash
./scripts/verify
```

MUST yield:
- strict conformance PASS/FAIL,
- deterministic evidence bundle,
- stable diagnostics,
- same semantic result across macOS/Linux/CI given same commit, vectors, and container digests.

## 2) Non-goals

- No changes to frozen-core semantics (`spec/NES-v0.1.md`, profiles, schemas, strict limits semantics).
- No conformance expected-output bending.
- No performance tuning scope.
- No public-release/marketing scope.

## 3) Scope (workstreams)

### I. One-command reproducibility baseline

Deliverables:
- `scripts/verify` as canonical entrypoint.
- Containerized execution for Rust/TS/suite/evidence.
- Strict mode only, fail-closed behavior.

Gate:
- Works from clean machine with Docker/Podman.
- Reproduces CI verdict for same commit and image digest.

### II. Golden toolchain containers

Deliverables:
- `docker/grain-runner.Dockerfile`
- `docker/grain-certify.Dockerfile`
- `scripts/containers/build_golden_images.sh`
- publish digests + lock/toolchain hashes in evidence.

Requirements:
- Rust/Node/Python versions pinned.
- Base images pinned by digest.

### III. WASM read/verify path

Deliverables:
- `core/rust/grain-core-wasm`
- `runner/typescript/profiles/wasm-subset.json`
- `runner/typescript/scripts/run-wasm-subset.ts`

Scope:
- read/verify operations first (validate/derive/verify/parse/reduce subset).
- deterministic build metadata where possible.

### IV. Fuzz corpus as release artifact

Deliverables:
- corpus manifest with hash anchors for malformed CBOR/COSE/E2E/CBOR-seq classes.
- deterministic smoke subset for gate path.
- expanded fuzz in the deep lane.

### V. Runner contract as public API

Deliverables:
- `conformance/contract/runner_v1.md`
- `conformance/contract/runner_v1.ops.json`
- `conformance/contract/runner_v1.output.schema.json`
- drift gate: `tools/ci/check_runner_contract_compat.py`

Rule:
- incompatible contract changes require version bump + governance update.

### VI. Domain adapter contract

Deliverables:
- `docs/human/domain-adapters.md`
- `docs/llm/DOMAIN_ADAPTERS.md`
- non-food adapter example (telemetry/sensor style).

### VII. Porting guide (human + LLM)

Deliverables:
- `docs/human/porting-grain.md`
- `docs/llm/PORTING.md`

Required topics:
- UTF-8 raw-byte ordering only,
- duplicate map-key reject strategy,
- no float semantics,
- deterministic nonce derivation bytes,
- E2E AAD binding bytes,
- conflict/quarantine invariants.

### VIII. Strict prohibition zone

Deliverables:
- `docs/llm/PROHIBITION_ZONE.md`
- coverage check: `tools/ci/check_prohibition_coverage.py`

Cluster rules:
- no locale sorting,
- no timezone semantics,
- no arrival-order semantics,
- no silent canonicalization,
- no platform-width overflow behavior.

### IX. cap_id CSPRNG enforcement audit

Deliverables:
- `tools/ci/check_capid_csprng.py`
- CI gate for fail-closed cap_id generation policy.

### X. Reproducibility guarantees document

Deliverables:
- `docs/human/portability-pack.md`
- clear guarantees vs non-guarantees with reproducible command path.

## 4) CI requirements

Required lanes:
- `verify-script-smoke`
- `wasm-smoke`
- `capid-csprng-audit`
- `fuzz-smoke` (deterministic subset)
- `evidence-bundle` with portability artifacts

Rule:
- no warning-only bypass for critical determinism checks.
- fail-closed unless explicitly designated warning-only by invariant and documented policy.

## 5) Reproducibility guarantees

Given same:
- commit SHA,
- vector manifest hash,
- container image digests,
- toolchain lock hashes,

must match:
- strict verdict,
- suite counts,
- divergence results,
- evidence content hash.

Metadata fields (timestamps/host details) are allowed to differ but must be excluded from deterministic content digest.

## 6) Artifact matrix

Each verify/certify run should emit:
- `suite-run-rust.json`
- `suite-run-ts.json`
- `sdk-suite.json` (when SDK lane is active)
- `divergence-full.json`
- `vector-manifest.json` + hash
- `container_image_digests.json`
- lock/toolchain hash files
- `evidence.sha256` (or equivalent deterministic content hash)
- WASM hash artifacts when WASM lane runs.

## 7) Risk register

1. Container drift via unpinned tags  
Mitigation: digest pinning + evidence anchors.

2. Host filesystem and permissions differences  
Mitigation: containerized execution + fail-safe cleanup discipline (`INV-STAB-001` pattern).

3. Runtime drift in Node/text/crypto behavior  
Mitigation: pinned Node version in container and byte-level checks.

4. WASM toolchain churn  
Mitigation: pinned wasm toolchain and hash-anchored artifacts.

5. Fuzz nondeterminism  
Mitigation: deterministic gate subset + deep fuzz with seed capture.

## 8) Audit visibility

Auditor should be able to:
1. clone the repository at commit/tag,
2. run `./scripts/verify`,
3. inspect evidence hashes and portability manifests,
4. confirm runner contract stability and portability gates.

## 9) PASS / FAIL

PASS if all:
- `./scripts/verify` is containerized and reproducible,
- portability lanes are green,
- evidence includes digest anchors for runtime/container/toolchain/corpus,
- no frozen-core semantic changes,
- runner contract drift gate enforced.

FAIL if any:
- host toolchain becomes implicit dependency,
- unpinned runtime/container path affects outcomes,
- deterministic evidence cannot be reproduced,
- portability gates become flaky in required path.

## 10) Relationship to RC stabilization

This TOR complements, not replaces, `TOR-RC-STAB-A01`.
- RC stabilization remains the pressure-test decision gate.
- Portability pack hardens reproducibility/portability substrate used by that gate.
- `INV-STAB-001` remains mandatory for cleanup behavior in stabilization tooling.
