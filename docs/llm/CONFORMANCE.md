# CONFORMANCE (runner contract walkthrough)

Hi teammate LLM. This is the practical contract page.
If you need to prove behavior, this is where you anchor execution.

Grain v0.1 compatibility is defined by passing the conformance suite in **Strict Conformance Mode**.

- Vectors live in `conformance/vectors/`
- Runner interface is defined in `conformance/SPEC.md`
- Frozen runner API is in `conformance/contract/runner_v1.md`

## Wave A (byte-level closure)

Wave A is the byte-path hardening pack:
- `parse_cborseq_stream_v1` for raw ledger/manifest CBOR-seq framing
- `e2e_derive_v1` for exact HKDF key/nonce expected bytes
- `utf8` vector pack for raw UTF-8 sorting/dedup traps
- mixed manifest sequence vectors under `manifest/*-WA-*`

`parse_cborseq_stream_v1` contract is XOR:
- accept path: `out.item_sha256_hex` is present and deterministic
- reject path: `pass=false` with deterministic framing `diag`
- partial item outputs are not part of reject semantics

Wave A vector ID scheme:
- `POS-<AREA>-WA-####`
- `NEG-<AREA>-WA-####`

## Strict Conformance Mode (MUST)

The runner MUST provide a mode where:
- baseline limits are enforced exactly (CBL)
- limit exceed returns deterministic `GRAIN_ERR_LIMIT`
- non-canonical inputs are rejected (not canonicalized implicitly)
- vectors are concrete test cases (no placeholder/illustrative vectors)

## Invariant mapping

`docs/llm/INVARIANTS.md` is the authoritative invariant -> vector mapping.
If you add vectors or change contract shape, update the mapping in the same change.

## Output contract

Runner outputs MUST be machine-readable and include:
- `vector_id`
- `pass/fail`
- diagnostic codes (when applicable)
- expected derived outputs (when applicable, e.g. CID or nonce bytes)

## Reference runner (Rust)

Path:
- `core/rust/grain-runner`

CLI contract:
```bash
grain-runner run --strict --vector <path/to/vector.json>
```

Error precedence / diagnostic table:
- `core/rust/grain-core/docs/errors.md`

## TypeScript runner

Path:
- `runner/typescript/`

Profiles:
- C01 profile: `runner/typescript/profiles/c01.json` (Wave A focused smoke lens)
- Full profile: `runner/typescript/profiles/full.json` (all vectors)
- WASM subset profile: `runner/typescript/profiles/wasm-subset.json` (read/verify portability lane)

Primary commands:
```bash
npm --prefix runner/typescript run run:c01
npm --prefix runner/typescript run divergence:c01
npm --prefix runner/typescript run run:full
npm --prefix runner/typescript run divergence:full
npm --prefix runner/typescript run test:properties
npm --prefix runner/typescript run run:wasm-subset
```

Artifacts:
- `runner/typescript/.c01-last-run.json`
- `runner/typescript/.divergence-c01.json`
- `runner/typescript/.full-last-run.json`
- `runner/typescript/.divergence-full.json`
- `runner/typescript/.properties-full.json`
- `runner/typescript/.wasm-subset-last-run.json`

## SDK runner (TOR-SDK-A01)

Path:
- `core/ts/grain-sdk/`

Primary commands:
```bash
npm --prefix core/ts/grain-sdk run run:protocol-suite
npm --prefix core/ts/grain-sdk run test:invariants
```

Contract:
- protocol vectors are executed through SDK boundary (no bypass path)
- SDK invariants are additional and MUST NOT weaken protocol vectors
- CI includes SDK checks inside required context `ts-full`

## CI and provenance contract

Required CI contexts on `main`:
- `python-tooling`
- `rust-core`
- `ts-c01`
- `ts-full`
- `evidence-bundle`

Evidence policy:
- CI emits commit-bound bundle `evidence-<commit_sha>.zip`
- bundle includes suite summaries, vector manifests/hashes, toolchain/lock hashes, Rust↔TS divergence summaries
- local `.local-architect-reports/**` are non-normative and MUST NOT be committed
- containerized portability certify path: `scripts/certify` (strict, fail-closed, clean-tree required)

Interop certification workflow:
- `/.github/workflows/interop-certify.yml` runs TOR-CERT-D01 packaging
- certification script: `tools/interop_certify.sh`
- claim boundaries: `spec/INTEROP-v0.1.md`

## RC stabilization contract (TOR-RC-STAB-A01)

Paths:
- `tools/stabilization/run_rc_stab.py`
- `stabilization/RC-STAB-A01/*`
- `/.github/workflows/rc-stabilization-nightly.yml`

Modes:
- `smoke` (PR-safe pressure test, now executed inside `ts-full` context)
- `deep` (nightly/manual pressure test with clean-clone repro + rollback rehearsal)

Key rule:
- Stabilization never changes frozen-core semantics.
- Any failure yields blocker handling (`rc1` revoke + `rc2` cut), not silent weakening.
- Addendum A02: deep reproducibility includes SDK strict suite parity when SDK lane is required.
- Addendum A02 / `INV-STAB-001`: cleanup failures are warning-only (`STAB_CLEANUP_WARN`) and MUST NOT flip protocol verdict.

## Portability pack contract (TOR-PORTABILITY-A01)

Primary anchors:
- `TOR-PORTABILITY-A01.md`
- `scripts/verify`
- `scripts/certify`
- `docker/grain-runner.Dockerfile`
- `docker/grain-certify.Dockerfile`

Required portability checks:
- containerized strict verify path
- runner contract compatibility checks
- prohibition-zone coverage checks
- cap_id CSPRNG policy audit
