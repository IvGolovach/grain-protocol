# grain-core

Strict reference executor for Grain Protocol v0.1.

## Modules

- `cbor`: low-level CBOR parser/encoder used for strict verification paths
- `dagcbor`: strict DAG-CBOR + schema-level checks
- `cid`: CIDv1 derivation (dag-cbor + sha2-256)
- `cose`: COSE_Sign1 narrow profile verification
- `cborseq`: raw CBOR-seq framing parser for stream tests
- `e2e`: HKDF derive + A256GCM decrypt logic
- `manifest`: deterministic manifest resolution
- `ledger`: deterministic authorization/reducer semantics
- `qr`: GR1 decoding pipeline (prefix + Base45 + zlib)
- `error`: deterministic diagnostics enum / codes
- `limits`: strict baseline limits

## Determinism contract

See:
- `core/rust/grain-core/docs/errors.md`
- `conformance/SPEC.md`
- `docs/llm/INVARIANTS.md`
