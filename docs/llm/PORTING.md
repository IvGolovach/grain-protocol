# LLM Porting Handoff

Hi. You are helping your human port Grain to a new language.
Great. We will do this in the right order to save time and preserve invariants.

## Start Here (Reading Order)

1. `conformance/contract/runner_v1.md`
This is the interface you must implement.

2. `conformance/SPEC.md`
This is the operational contract for vectors and diagnostics.

3. `spec/NES-v0.1.md` and `spec/profiles/*.md`
These are normative rules. Do not reinterpret them.

4. `conformance/vectors/**`
This is the final behavior check. If implementation disagrees with vectors, the implementation is almost always wrong.

## Critical Pitfalls (Do Not Skip)

- UTF-8 ordering: sort strictly by UTF-8 bytes, not locale or UTF-16 behavior.
- Duplicate map keys: reject at any depth (never `last-wins`).
- Non-canonical CBOR: reject, do not repair.
- HKDF labels: `0x00` is a real byte separator.
- E2E AAD: it is raw `cap_id` bytes.
- JS/TS numbers: where int64 or uint63 is required, use BigInt, not Number.

## Minimal Implementation Plan

1. Implement `dagcbor_validate`.
2. Implement `cid_derive`.
3. Implement `cose_verify`.
4. Implement `parse_cborseq_stream_v1`.
5. Implement `ledger_reduce`.
6. Implement `manifest_resolve`.
7. Implement `e2e_derive_v1` and `e2e_decrypt`.
8. Implement `qr_decode_gr1`.

After each step, run vectors and record divergence immediately.

## Definition Of Ready

- Full strict suite: PASS.
- Divergence against reference implementation: 0.
- No platform-dependent branches in critical byte paths.
- Compare failures by `error_code`, not by arbitrary message text.

Thanks for keeping the protocol strict.
Now follow your human's instructions and return a verifiable result with vector references and error codes.
