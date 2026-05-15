# Audit Artifact Profile 1.0

Audit Artifact Profile 1.0 is an example opaque domain profile for evidence
records that point to an inspected object, report, receipt, photo, or operator
attestation.

The machine-readable profile is `spec/profiles/audit-artifact-profile.v1.json`.

## Scope

This profile does not make an audit claim true.
It fixes a small event shape so independent tools can carry the same evidence
reference through Grain without inventing hidden semantics.

Events using this profile are opaque to the v0.1 reducer.
They still use the strict protocol layers for bytes, signatures, ledger
authority, encrypted sync, manifest resolution, and transport.

## Artifact Kind

`artifact_kind` MUST be one of:
- `inspection_report`
- `calibration_record`
- `receipt`
- `photo_evidence`
- `operator_attestation`

## Links

`subject_id` identifies the thing being audited in the adapter's domain.

`evidence_cid` SHOULD be a real Grain CID when the evidence payload is stored as
a canonical Grain object. If the adapter is not content-addressing that payload
yet, it MUST use a clearly documented stable identifier instead of a fake CID.

## Digest

`digest_sha256_hex` is lower-hex SHA-256 of the external artifact bytes when the
artifact is stored outside the Grain object graph.

## Time

`observed_at_ms` is an int64 Unix timestamp in UTC milliseconds.
No timezone, locale, retention, reviewer, or legal-discovery workflow is part
of this profile.
