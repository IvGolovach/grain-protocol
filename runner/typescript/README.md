# grain-ts-runner (TOR-03 / C01 smoke)

TypeScript conformance runner for Grain, focused on C01 smoke profile (all Wave A vectors).

## Scope

Implemented ops for C01:
- `dagcbor_validate`
- `parse_cborseq_stream_v1`
- `e2e_derive_v1`
- `e2e_decrypt`
- `manifest_resolve`

Also includes `qr_decode_gr1` helper op.

This runner is a smoke probe for cross-language strictness. It is not the full second independent implementation.

## Requirements

- Node >= 22 (tested on Node 23)
- Rust reference runner available via Docker for divergence comparison

## Commands

Run one vector:

```bash
node --experimental-strip-types runner/typescript/src/cli.ts run --strict --vector conformance/vectors/e2e/POS-E2E-WA-0001.json
```

Run C01 profile:

```bash
node --experimental-strip-types runner/typescript/scripts/run-c01.ts
```

Generate Rust↔TS divergence report (C01):

```bash
node --experimental-strip-types runner/typescript/scripts/divergence-c01.ts
```

Outputs:
- `runner/typescript/.c01-last-run.json`
- `runner/typescript/.divergence-c01.json`
- `runner/typescript/.divergence-c01.md`

## Determinism notes

- UTF-8 comparisons are raw-byte lexicographic only.
- HKDF labels are ASCII with explicit `0x00` separators.
- DAG-CBOR decoding is strict and rejects duplicate map keys/non-canonical forms.
