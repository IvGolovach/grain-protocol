# ADR-0013: Require blessed CIDs inside every tag-42 link

- Status: Accepted
- Date: 2026-11-23
- Owners: @IvGolovach
- Affects: Protocol, Conformance, Core
- Invariants touched: INV-CID-002, INV-CID-003 (new), INV-CID-004 (new)
- Conformance vectors impacted: POS-CID-002, NEG-CID-011, NEG-CID-012, NEG-CID-013, NEG-CID-014, NEG-CID-015, NEG-CID-020, NEG-CID-021, NEG-CID-022 (new)

## Context
NES §4.1 fixes the blessed CID set (CIDv1, dag-cbor, sha2-256). NES §4.3
requires a CID link to be tag 42 over a bstr holding `0x00` followed by "the
binary CID bytes". Typed Object Validation (ADR-0012) already enforces the full
blessed link structure for the 14 known productions.

The generic strict DAG-CBOR parsers in Rust and TypeScript checked only the
`0x00` prefix. Both accepted tag-42 links holding a CID version 2, sha2-512,
the raw codec, a CIDv0 shape, or a digest truncated to 31 bytes. Objects of
unknown `t`, which NES §2.3 stores opaquely without typed validation, could
carry such links. `cid_derive` hashed them too. Because both implementations
agreed, the divergence gate stayed green.

## Decision
The strict DAG-CBOR parser rejects every tag-42 link whose bstr is not exactly
`0x00 0x01 0x71 0x12 0x20` followed by a 32-byte digest, with
`GRAIN_ERR_BAD_CID_LINK`. This applies to typed and untyped validation and to
CID derivation alike. Both cores share one predicate with typed validation
(`is_blessed_cid_link_bstr` in Rust, `isBlessedCidLinkBstr` in TypeScript).

NES §4.3 now states the rule explicitly. The CDDL comment is aligned.

This is not a new wire rule. Like ADR-0011, it corrects implementations to
an existing v0.1 rule: NES §4.3 already demanded a binary CID, and §4.1 already
limited protocol identifiers to the blessed set.

## Rationale
A strict profile that accepts a truncated digest as a link is not strict.
Unknown-type objects are forwarded unchanged between implementations. An
implementation that resolves links could then disagree with one that only
stores them, which is a parser differential. One predicate for every path
removes the gap between typed and untyped validation.

## Alternatives considered
- Accept any well-formed IPLD CID in untyped mode. Rejected: Grain links point
  at Grain protocol objects, which are always blessed, and typed validation
  already requires the blessed form.
- Leave untyped mode permissive and document it. Rejected: it keeps a
  malleability class open in opaque objects.

## Consequences
### Positive
- One link rule for every strict DAG-CBOR path.
- `cid_derive` never assigns an identifier to bytes that contain an invalid link.

### Negative / trade-offs
- Inputs with non-blessed links that implementations previously accepted now
  fail. They were never valid under NES §4.3.

### Security / privacy impact
- Threats addressed: parser differential through malformed links in opaque
  objects; CIDs derived over invalid data.
- New risks introduced: none known.

### Interop / determinism impact
- Byte-level compatibility: unchanged for NES-valid data.
- Order-independence / merge semantics: unaffected.
- Forward compatibility: other CID forms would need a new blessed set, which
  is a protocol major change under FREEZE-CONFIRMATION §1.2.

## Compatibility
- Is this breaking? No for valid v0.1 data. Only inputs that already violated
  NES §4.3 change verdict. All 190 previously existing vectors pass unchanged in
  both cores.
- Diagnostic precedence: the link check runs inside the strict parse, at the
  same point where the existing `0x00` prefix check ran.

## Implementation notes
- Rust: `core/rust/grain-core/src/cid.rs`, `cbor.rs`, `typed_object.rs`.
- TypeScript: `core/ts/grain-ts-core/src/utils.ts`, `cbor.ts`, `typed-object.ts`.
- `e2e_derive_v1` keeps its documented input contract
  (`cid_link_bstr` prefix check, NEG-E2E-WA-0003). It derives keys and does not
  parse protocol objects.

## References
- NES sections: §2.3, §3.1, §4.1, §4.2, §4.3
- Precedent: ADR-0011
- Vector IDs: POS-CID-002, NEG-CID-011 through NEG-CID-015, NEG-CID-020 through NEG-CID-022
