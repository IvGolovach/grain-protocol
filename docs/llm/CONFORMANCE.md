# CONFORMANCE (runner contract overview)

Grain v0.1 compatibility is defined by passing the conformance suite in **Strict Conformance Mode**.

- Vectors live in `conformance/vectors/`
- Runner interface is defined in `conformance/SPEC.md`

## Wave A (byte-level closure)

Wave A introduces byte-path tests that must run in strict mode:
- `parse_cborseq_stream_v1` for raw ledger/manifest CBOR-seq framing
- `e2e_derive_v1` for exact HKDF key/nonce expected bytes
- `utf8` vector pack for raw UTF-8 sorting/dedup traps
- mixed manifest sequence vectors under `manifest/*-WA-*`

`parse_cborseq_stream_v1` contract is XOR:
- accept path: `out.item_sha256_hex` is present and deterministic.
- reject path: `pass=false` with deterministic framing `diag`; partial item outputs are not part of reject semantics.

Wave A vector ID scheme:
- `POS-<AREA>-WA-####`
- `NEG-<AREA>-WA-####`

## Strict Conformance Mode (MUST)

The runner MUST provide a mode where:
- baseline limits are enforced exactly (CBL)
- limit exceed returns deterministic `GRAIN_ERR_LIMIT`
- non-canonical inputs are rejected (not canonicalized implicitly)
- vectors are concrete test cases (no placeholder/illustrative vectors)

## Mapping invariants -> vectors

`docs/llm/INVARIANTS.md` is the authoritative mapping between MUST rules and vector IDs.

## Output format

Runner outputs MUST be machine-readable and include:
- vector_id
- pass/fail
- diagnostic codes (if applicable)
- any expected derived outputs (e.g., CID string)

## Reference runner (Rust)

Current reference runner path:
- `core/rust/grain-runner`

CLI contract:
```bash
grain-runner run --strict --vector <path/to/vector.json>
```

Error precedence and diagnostic table:
- `core/rust/grain-core/docs/errors.md`

## TS runner profiles

TypeScript runner path:
- `runner/typescript/`

Profiles:
- C01 profile: `runner/typescript/profiles/c01.json` (Wave A only)
- Full profile: `runner/typescript/profiles/full.json` (all vectors)

Primary commands:
```bash
node --experimental-strip-types runner/typescript/scripts/run-c01.ts
node --experimental-strip-types runner/typescript/scripts/divergence-c01.ts
node --experimental-strip-types runner/typescript/scripts/run-full.ts
node --experimental-strip-types runner/typescript/scripts/divergence-full.ts
node --experimental-strip-types runner/typescript/scripts/properties-full.ts
```

Artifacts:
- `runner/typescript/.c01-last-run.json`
- `runner/typescript/.divergence-c01.json`
- `runner/typescript/.full-last-run.json`
- `runner/typescript/.divergence-full.json`
- `runner/typescript/.properties-full.json`

## CI provenance contract

Required CI contexts on `main`:
- `python-tooling`
- `rust-core`
- `ts-c01`
- `ts-full`
- `evidence-bundle`

Evidence policy:
- CI emits commit-bound bundle `evidence-<commit_sha>.zip`.
- Bundle includes:
  - suite summaries
  - vector manifests and hashes
  - lock/toolchain hashes
  - Rust↔TS divergence summaries for C01 and full
- Local `.local-architect-reports/**` are non-normative and MUST NOT be committed.

Interop certification workflow:
- `/.github/workflows/interop-certify.yml` runs TOR-CERT-D01 certification packaging.
- Certification script: `tools/interop_certify.sh`.
- Claim boundaries are normative in `spec/INTEROP-v0.1.md`.
