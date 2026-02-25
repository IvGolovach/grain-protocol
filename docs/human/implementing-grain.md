# Implementing Grain

This page is for protocol implementers (new Core/SDK/runner).

## Recommended order

1. `conformance/contract/runner_v1.md` (frozen runner API)
2. `conformance/SPEC.md` (runner semantics)
3. `conformance/vectors/**` (expected behavior)
4. `spec/NES-v0.1.md` + `spec/profiles/*` (normative rules)
5. `spec/FREEZE-CONFIRMATION-v0.1.md` + `spec/SCOPE-v0.1.md` + `spec/INTEROP-v0.1.md`

Conformance is the executable court. Implementation must follow vectors, not vice versa.

## TS Full Engine constraints (TOR-04)

- Independence: no Rust FFI/WASM inside TS execution logic.
- Strict mode only for conformance runs.
- BigInt policy for integer domains and reducer sums.
- Raw-byte UTF-8 ordering only (no locale/normalization).
- Strict CBOR scanner must reject duplicate map keys and non-canonical forms.
- COSE verification must enforce narrow profile and deterministic-bytes checks.

## High-risk implementation traps

- Duplicate map keys silently accepted by decoder (`last wins`).
- String ordering by locale/UTF-16 instead of raw UTF-8 bytes.
- Numeric domains implemented with JS `number` instead of `BigInt`-safe handling.
- COSE accepted but not deterministic-bytes checked.
- HKDF labels with incorrect `0x00` separators.
- `parse_cborseq_stream_v1` treated as partial-success instead of XOR accept/reject framing verdict.
- Silent dependency on host toolchain/runtime instead of containerized verify path.

## Conformance statements

- Passing the suite is the conformance criterion.
- A strong interoperability claim is valid only after two independent full implementations pass the full suite.
- TS full engine now targets full-suite parity; C01 remains a byte-path smoke profile.

## Portability references

- `docs/human/portability-pack.md`
- `docs/human/porting-grain.md`

## Domain scope note

- v0.1 core invariants are domain-neutral.
- v0.1 shipped schemas are food-first.
- New domains are additive via new `t`/schemas/vectors; frozen core semantics must remain unchanged.
