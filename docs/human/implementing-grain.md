# Implementing Grain

This page is for protocol implementers (new Core/SDK/runner).

## Recommended order

1. `conformance/contract/runner_v1.md` (frozen runner API)
2. `conformance/SPEC.md` (runner semantics)
3. `conformance/vectors/**` (expected behavior)
4. `spec/NES-v0.1.md` + `spec/profiles/*` (normative rules; `NES` = Normative Encoding & Semantics)
5. `spec/FREEZE-CONFIRMATION-v0.1.md` + `spec/SCOPE-v0.1.md` + `spec/INTEROP-v0.1.md`

Treat the conformance vectors as the final behavior check. Implementations should match the vectors, not the other way around.

## TypeScript full engine rules

- Independence: no Rust FFI/WASM inside TS execution logic.
- Strict mode only for conformance runs.
- BigInt policy for integer domains and reducer sums.
- Raw-byte UTF-8 ordering only (no locale/normalization).
- Strict CBOR scanner must reject duplicate map keys and non-canonical forms.
- COSE verification must enforce narrow profile and deterministic-bytes checks.
- COSE Ed25519 verification must reject weak keys, small-order signature `R`,
  non-canonical compressed point encodings, and non-canonical signature scalars
  before relying on host crypto-library acceptance. Point decoding must also
  reject x=0 when the encoded x-sign bit is set.

## High-risk implementation traps

- Duplicate map keys silently accepted by decoder (`last wins`).
- String ordering by locale/UTF-16 instead of raw UTF-8 bytes.
- Numeric domains implemented with JS `number` instead of `BigInt`-safe handling.
- COSE accepted but not deterministic-bytes checked.
- COSE delegated entirely to host crypto, accepting weak-key or non-canonical
  Ed25519 inputs differently across runtimes.
- HKDF labels with incorrect `0x00` separators.
- `parse_cborseq_stream_v1` treated as partial-success instead of XOR accept/reject framing verdict.
- Silent dependency on host toolchain/runtime instead of containerized verify path.
- Treating canonical DAG-CBOR as sufficient proof that a selected known object
  matches its full CDDL production.
- Checking only the tag-42 `0x00` prefix instead of the complete CIDv1,
  dag-cbor, sha2-256, 32-byte-digest structure.

## Typed object validation

Use the existing `dagcbor_validate` runner operation with optional
`object_type` when the caller knows which v0.1 production it expects:

```json
{
  "bytes_b64": "<canonical DAG-CBOR>",
  "object_type": "ServingOffer"
}
```

This is a pure validation selector. It is not encoded into the object and does
not create a second wire format. A complete implementation validates required
fields, exact value kinds, fixed byte widths, full CID links, nested records,
union branches, numeric domains, set-arrays, and limits. Start with
`conformance/vectors/object/POS-OBJ-001.json`, then run the full object pack.

## Conformance statements

- Passing the suite is the conformance criterion.
- A strong interoperability claim is valid only after two independent full implementations pass the full suite.
- TS full engine now targets full-suite parity; `C01` remains the smaller byte-path smoke profile.

## Portability references

- `docs/human/portability-pack.md`
- `docs/human/porting-grain.md`

## Domain scope note

- v0.1 core invariants are domain-neutral.
- v0.1 shipped schemas are food-first.
- New domains are additive via new `t`/schemas/vectors; frozen core semantics must remain unchanged.
