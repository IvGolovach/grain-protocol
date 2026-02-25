# Porting Grain to a New Language

This guide is for implementation teams building a new `runner_v1` without reading Rust internals.

## Required inputs

You only need:
- `spec/NES-v0.1.md`
- `spec/profiles/*.md`
- `conformance/SPEC.md`
- `conformance/contract/runner_v1.md`
- `conformance/vectors/**`
- `docs/llm/PORTING.md`

## Non-negotiable implementation rules

1. Compare strings by raw UTF-8 bytes where protocol requires ordering; never use locale APIs.
2. Reject duplicate map keys at any CBOR nesting depth.
3. Reject non-canonical CBOR; no silent canonicalization.
4. Keep integer semantics deterministic (`BigInt` in JS/TS; no float fallbacks).
5. Preserve exact HKDF label bytes (`0x00` separators are real bytes, not escaped text).
6. Bind E2E AAD to raw `cap_id` bytes.
7. Keep deterministic diagnostics by error codes; free-text is non-normative.

## Minimal boot path

1. Implement `dagcbor_validate`.
2. Implement `cid_derive`.
3. Implement `cose_verify`.
4. Implement `parse_cborseq_stream_v1`.
5. Implement `ledger_reduce`.
6. Implement `manifest_resolve`.
7. Implement `e2e_derive_v1` and `e2e_decrypt`.
8. Implement `qr_decode_gr1`.

Then run full vectors in strict mode and compare divergence against reference engines.

## Fast failure checklist

- If one vector differs, treat it as a contract bug until proven otherwise.
- If diagnostics differ, compare codes only.
- If results differ across OS/runtime, pin toolchain and compare inside container.
- If your parser library normalizes maps/strings, replace it or add a strict scanner before decode.
