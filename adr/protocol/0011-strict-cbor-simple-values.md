# ADR-0011: Reject CBOR simple values outside the strict DAG-CBOR data model

- Status: Accepted
- Date: 2026-07-07
- Owners: Grain Contributors
- Affects: Protocol, Conformance, Core
- Invariants touched: INV-ENC-001
- Conformance vectors impacted: NEG-ENC-050, NEG-ENC-051, NEG-ENC-052, NEG-ENC-053, NEG-ENC-054

## Context
Grain v0.1 already requires protocol objects to be strict DAG-CBOR and to reject non-canonical encodings.
The Rust and TypeScript parsers enforced floats, map ordering, duplicate keys, and tag restrictions, but both accepted CBOR simple values that are outside the Grain strict DAG-CBOR data model.

Because both independent implementations accepted the same invalid inputs, the divergence gate stayed green.
The missing anchor was executable conformance coverage for this reject path.

## Decision
Strict Conformance Mode rejects CBOR simple values that are outside the Grain strict DAG-CBOR data model:
- `undefined`
- unassigned simple values
- extended simple values

The parser rejects the following CBOR well-formedness failures regardless of Strict Conformance Mode:
- non-well-formed two-byte simple values below 32
- reserved simple-value additional information

This is not a new wire rule.
It is an implementation and conformance correction for the existing v0.1 strict DAG-CBOR rule.
Booleans and null remain valid CBOR values when allowed by the relevant schema.

## Rationale
Canonical bytes are the basis for stable CIDs, byte-level interop, and deterministic verification.
Accepting values outside the strict data model creates parser differentials and lets invalid data reach CID derivation and higher protocol layers.

## Alternatives considered
- Rely on Rust/TypeScript divergence only. Rejected because both implementations can agree on the same invalid behavior.
- Treat this as a v0.2 protocol change. Rejected because the v0.1 profile already requires strict DAG-CBOR; this change restores implementation behavior to that profile.
- Reject booleans and null. Rejected because those are ordinary CBOR data-model values and may be schema-valid in protocol objects.

## Consequences
### Positive
- Adds executable coverage for a strict DAG-CBOR malleability class.
- Keeps Rust and TypeScript behavior aligned under the conformance suite.
- Preserves the v0.1 protocol line.

### Negative / trade-offs
- Permissive inputs previously accepted by implementations now fail strict conformance.

### Security / privacy impact
- Threats addressed: parser differential, invalid CBOR value acceptance, CID derivation over values outside the strict data model.
- New risks introduced: none known.

### Interop / determinism impact
- Byte-level compatibility: invalid inputs are rejected consistently.
- Order-independence / merge semantics: not affected.
- Forward compatibility: future simple-value support would require explicit schema/profile work and vectors.

## Compatibility
- Is this breaking? No for valid v0.1 data; yes only for invalid inputs that should already have been rejected.
- If breaking: no protocol major bump is required because the frozen rule already requires strict DAG-CBOR rejection.

## Implementation notes
- Update Rust parser strict mode in `core/rust/grain-core/src/cbor.rs`.
- Update TypeScript parser strict mode in `core/ts/grain-ts-core/src/cbor.ts`.
- Add conformance vectors under `conformance/vectors/encoding/`.

## References
- NES sections: `spec/NES-v0.1.md` §3
- Profile: `spec/profiles/cbor-profile.md`
- Vector IDs: NEG-ENC-050, NEG-ENC-051, NEG-ENC-052, NEG-ENC-053, NEG-ENC-054
