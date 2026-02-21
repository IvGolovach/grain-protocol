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

## TS runner C01 smoke

TypeScript smoke runner path:
- `runner/typescript/`

C01 profile definition:
- `runner/typescript/profiles/c01.json`
- profile rule: all `conformance/vectors/**/*-WA-*.json`

Primary commands:
```bash
node --experimental-strip-types runner/typescript/scripts/run-c01.ts
node --experimental-strip-types runner/typescript/scripts/divergence-c01.ts
```

Expected artifacts:
- `runner/typescript/.c01-last-run.json`
- `runner/typescript/.divergence-c01.json`
- `runner/typescript/.divergence-c01.md`

## CI provenance contract

Required CI contexts on `main`:
- `python-tooling`
- `rust-core`
- `ts-c01`
- `evidence-bundle`

Evidence policy:
- CI emits commit-bound bundle `evidence-<commit_sha>.zip`.
- Bundle includes:
  - suite summaries
  - vector manifests and hashes
  - lock/toolchain hashes
  - Rust↔TS divergence summary for C01
- Local `.local-architect-reports/**` are non-normative and MUST NOT be committed.
