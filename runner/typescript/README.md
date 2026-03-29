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

- Node `22.22.0` for evidence-generating and stabilization paths (`.nvmrc` is the source of truth)
- Docker available for divergence scripts
- `npm ci --prefix runner/typescript`

## Commands

Run one vector:

```bash
npm --prefix runner/typescript run run:vector -- conformance/vectors/cid/POS-CID-001.json
```

Run C01 (Wave A smoke):

```bash
npm --prefix runner/typescript run run:c01
npm --prefix runner/typescript run divergence:c01
```

Run full suite + divergence:

```bash
npm --prefix runner/typescript run run:full
npm --prefix runner/typescript run divergence:full
```

Run TS property tests:

```bash
npm --prefix runner/typescript run test:properties
npm --prefix runner/typescript run test:integer-precision
```

Run WASM subset portability smoke:

```bash
npm --prefix runner/typescript run run:wasm-subset
```

Build the stable JS output explicitly:

```bash
npm --prefix runner/typescript run build
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
