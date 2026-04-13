# Runner Contract `runner_v1` (Frozen Interface)

This document freezes the `runner_v1` machine contract for conformance execution.
It is the portability-facing API between vectors and implementations.

## CLI shape (MUST)

The runner MUST support:

```bash
grain-runner run --strict --vector <path/to/vector.json>
```

Compatibility rules:
- `--strict` MUST enable Strict Conformance Mode.
- `--vector` MUST accept a single UTF-8 JSON vector file path.
- stdout MUST emit exactly one JSON object with the output schema below.
- non-zero exit is allowed only when `pass=false` (or fatal process failure).

## Output schema (MUST)

`runner_v1` output MUST contain:
- `vector_id` (string)
- `pass` (boolean)
- `diag` (array of deterministic codes)
- `out` (object)

JSON integer interoperability rule:
- values inside `out` whose absolute value is greater than `9007199254740991` MUST be emitted as base-10 decimal strings
- safe integers MAY be emitted as JSON numbers
- this keeps `runner_v1` interoperable across IEEE-754 / JavaScript runtimes without losing exactness

Normative schema file:
- `conformance/contract/runner_v1.output.schema.json`

## Supported operations (MUST)

The operation set for `runner_v1` is frozen to:
- `dagcbor_validate`
- `cid_derive`
- `cose_verify`
- `qr_decode_gr1`
- `e2e_decrypt`
- `e2e_derive_v1`
- `parse_cborseq_stream_v1`
- `manifest_resolve`
- `ledger_reduce`

Normative manifest file:
- `conformance/contract/runner_v1.ops.json`

## Compatibility policy

- Additive changes that do not change flags/output schema/operation names MAY be introduced under `runner_v1`.
- Any incompatible CLI flag change, JSON output schema change, or operation rename/removal MUST use a new contract version (`runner_v2`).
- Conformance vectors for protocol `v0.1.x` are bound to `runner_v1`.
