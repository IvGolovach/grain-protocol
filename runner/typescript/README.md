# grain-ts-runner (TOR-04 / Full Engine)

TypeScript independent implementation for Grain conformance.

## Scope

Implemented full conformance op set:
- `dagcbor_validate`
- `cid_derive`
- `cose_verify`
- `qr_decode_gr1`
- `parse_cborseq_stream_v1`
- `ledger_reduce`
- `manifest_resolve`
- `e2e_derive_v1`
- `e2e_decrypt`

## Independence boundary

- No Rust FFI/WASM in engine execution.
- Rust is used only by divergence tooling as external oracle process comparison.

## Requirements

- Node >= 22
- Docker available for divergence scripts

## Commands

Run one vector:

```bash
node --experimental-strip-types runner/typescript/src/cli.ts run --strict --vector conformance/vectors/cid/POS-CID-001.json
```

Run C01 (Wave A smoke):

```bash
node --experimental-strip-types runner/typescript/scripts/run-c01.ts
node --experimental-strip-types runner/typescript/scripts/divergence-c01.ts
```

Run full suite + divergence:

```bash
node --experimental-strip-types runner/typescript/scripts/run-full.ts
node --experimental-strip-types runner/typescript/scripts/divergence-full.ts
```

Run TS property tests:

```bash
node --experimental-strip-types runner/typescript/scripts/properties-full.ts
```

Run WASM subset portability smoke:

```bash
node --experimental-strip-types runner/typescript/scripts/run-wasm-subset.ts
```

## Artifacts

- `runner/typescript/.c01-last-run.json`
- `runner/typescript/.divergence-c01.json`
- `runner/typescript/.full-last-run.json`
- `runner/typescript/.divergence-full.json`
- `runner/typescript/.properties-full.json`
- `runner/typescript/.wasm-subset-last-run.json`

## Determinism notes

- UTF-8 comparisons are raw-byte lexicographic only.
- HKDF labels are ASCII with explicit `0x00` separators.
- DAG-CBOR decoding is strict and rejects duplicate map keys/non-canonical forms.
- Ledger and manifest outputs are order-independent for identical input sets.
