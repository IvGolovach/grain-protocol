# Client Workflow Contract v1

Client workflow fixtures describe app-facing SDK behavior shared by Rust, Swift, Kotlin, WASM, and future device SDKs.

## Scope

This contract is additive. It does not change `conformance/SPEC.md`, protocol vectors, runner operations, or strict protocol verdicts.

Workflow fixtures can reference protocol vectors as input material. A generated SDK passes a workflow fixture only when its public workflow API returns the same status, diagnostics, and mutation behavior as the Rust client core.

## Fixture Shape

Each fixture is a JSON object with:

- `fixture_id`: stable `SDK-WF-*` identifier.
- `workflow`: workflow name, currently `scan_preview`.
- `strict`: must be `true`.
- `input`: workflow input references or inline values.
- `expect`: expected workflow status, diagnostics, COSE output presence, and storage mutation result.
- `meta.desc`: short human-readable reason for the fixture.

## References

References use repository-relative JSON pointers:

```text
conformance/vectors/qr/POS-QR-001.json#/input/qr_string
conformance/vectors/cose/POS-COSE-001.json#/input/pub_b64
```

Future runners must resolve references without network access and must fail closed when a reference is missing or points to a non-string field. Runners must canonicalize the file path before reading it, reject absolute paths and `..` path segments, and ensure the resolved file remains inside the repository `conformance/vectors/` tree.

## `scan_preview`

Input fields:

- `qr_string_ref`: required reference to a QR string.
- `trust_pub_b64_ref`: optional reference to trust material.
- `trust_pub_b64`: optional inline trust material for malformed or synthetic trust cases.

`trust_pub_b64_ref` and `trust_pub_b64` are mutually exclusive. If both are absent, the scan is intentionally previewed without trust.

Expected fields:

- `status`: one of `Verified`, `Untrusted`, `Rejected`.
- `diag`: exact ordered diagnostic strings.
- `diag_contains`: diagnostic strings that must be present when the underlying protocol vector promises containment instead of exact equality.
- `cose_b64`: `present` or `absent`.
- `store_mutation`: currently always `none`.

`cose_b64: present` means the COSE envelope was successfully decoded from the QR input. It does not imply that trust verification passed.

`scan_preview` must not persist data. Persistence starts in a later `scan_accept` workflow.
