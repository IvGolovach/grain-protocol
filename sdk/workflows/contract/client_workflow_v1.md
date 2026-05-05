# Client Workflow Contract v1

Client workflow fixtures describe app-facing SDK behavior shared by Rust, Swift, Kotlin, WASM, and future device SDKs.

## Scope

This contract is additive. It does not change `conformance/SPEC.md`, protocol vectors, runner operations, or strict protocol verdicts.

Workflow fixtures can reference protocol vectors as input material. A generated SDK passes a workflow fixture only when its public workflow API returns the same status, diagnostics, and mutation behavior as the Rust client core.

## Fixture Shape

Each fixture is a JSON object with:

- `fixture_id`: stable `SDK-WF-*` identifier.
- `workflow`: workflow name: `scan_preview`, `scan_accept`, `device_lifecycle`, `pairing`, `sync_bundle`, or `store_snapshot`.
- `strict`: must be `true`.
- `input`: workflow input references or inline values.
- `expect`: expected workflow status, diagnostics, output presence, counts, and storage mutation result where applicable.
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

`scan_preview` must not persist data. Persistence starts in the `scan_accept` workflow.

## `scan_accept`

Input fields:

- `qr_string_ref`: required reference to a QR string.
- `trust_pub_b64_ref`: required reference to trust material for positive fixtures.
- `trust_pub_b64`: optional inline trust material for malformed or synthetic trust cases.
- `accept_attempts`: optional positive integer; defaults to `1`. Fixtures use `2` to assert duplicate-scan idempotency through the public workflow API.

`trust_pub_b64_ref` and `trust_pub_b64` are mutually exclusive. If both are absent, the scan is intentionally accepted without trust and must reject with `SDK_ERR_SCAN_ACCEPT_TRUST_REQUIRED`.

Expected fields:

- `status`: one of `Accepted`, `AlreadyAccepted`, `Rejected`.
- `diag`: exact ordered diagnostic strings.
- `diag_contains`: diagnostic strings that must be present when the underlying protocol vector promises containment instead of exact equality.
- `cose_b64`: `present` when the accepted result carries COSE bytes, otherwise `absent`.
- `store_mutation`: `accepted_scan_inserted` or `none`.
- `accepted_record_count`: number of persisted accepted-scan records after the workflow call.

`scan_accept` must mutate storage only inside the client store atomic boundary. Rejected scans must leave `accepted_record_count` unchanged at `0`. `AlreadyAccepted` fixtures must repeat the same accept operation and still end with exactly one persisted accepted-scan record.

## `device_lifecycle`

Input fields:

- `root_label`: optional root device label; defaults to the runner's root label.
- `device_label`: optional child device label; defaults to the runner's device label.

Expected fields:

- `status`: `Ready` after the fixture completes.
- `diag`: exact ordered diagnostics.
- `root_kid`, `active_ak`, `device_ak`: `present` or `absent`.
- `device_count`, `revoked_count`, `accepted_record_count`, `lifecycle_event_count`: final lifecycle counters.

The fixture runner creates a root identity, adds a device key, activates that device, revokes it, and checks `client_lifecycle()`.

## `pairing`

Input fields:

- `root_label`: optional source root label.
- `device_label`: optional source child device label.
- `accept_attempts`: optional positive integer; fixtures use `2` to assert replay idempotency.

Expected fields:

- `status`: final accept status, usually `AlreadyPaired` when `accept_attempts` is `2`.
- `diag`: exact ordered diagnostics.
- `root_kid`, `pairing_id`, `envelope_b64`: `present` or `absent`.
- `device_count`: device count transferred by the pairing envelope.

Pairing envelopes are app-controlled transfer artifacts. They move the portable identity bundle through the generated SDK workflow surface; they are not a claim that the SDK has implemented platform key custody or a secure remote pairing protocol.

## `sync_bundle`

Input fields:

- `root_label`: optional source root label.
- `device_label`: optional source child device label.
- `qr_string_ref`: required reference to a scan QR string.
- `trust_pub_b64_ref` or `trust_pub_b64`: required trust material for the accepted scan inserted before export.
- `import_attempts`: optional positive integer; fixtures use `2` to assert repeated import idempotency.

Expected fields:

- `status`: final import status, usually `AlreadyImported` when `import_attempts` is `2`.
- `diag`: exact ordered diagnostics.
- `bundle_b64`: `present` or `absent`.
- `accepted_record_count`, `device_count`, `lifecycle_event_count`: final imported counters.

Sync import must be atomic. Identity conflicts reject without importing accepted scans or lifecycle events.

## `store_snapshot`

The store snapshot bridge is the persistence boundary for generated platform
wrappers before native Keychain, Keystore, IndexedDB, or device-specific stores
exist.

Expected public API behavior:

- empty stores export status `Empty` and no `snapshot_b64` payload;
- non-empty stores export status `Exported`, a `snapshot_b64` payload, and
  accepted-scan/device/lifecycle counters;
- restore into a fresh client returns `Restored` and reproduces those counters;
- malformed or unsupported snapshot payloads return `Rejected` without mutating
  existing client state.

The snapshot payload is opaque SDK state. Apps persist the returned string; they
must not parse it or use it as a raw mutation surface.
