# ADR-0002: Blessed CID set (CIDv1 + dag-cbor + sha2-256)

- Status: Accepted
- Date: 2026-02-20
- Owners: Grain Contributors
- Affects: Protocol, Conformance
- Invariants touched: (see docs/llm/INVARIANTS.md)
- Conformance vectors impacted: (see conformance/vectors)

## Context
Grain requires byte-level interoperability, offline verification, deterministic merge semantics, and privacy-by-default.
Any ambiguity becomes a forced-major risk.

## Decision
Grain v0.1 blesses a single CID set:
CIDv1, codec=dag-cbor (0x71), multihash=sha2-256 only, base32 lower (multibase 'b') when text is used.

## Rationale
A minimal algorithm matrix is essential for interop.
sha2-256 is widely available across environments and ecosystems.
Hash agility is deferred to additive future profiles (new major) to avoid v0.1 complexity.

## Alternatives considered
See `docs/human/rationale/design-choices.md` and project discussion history.

## Consequences
- Positive: simple, stable interop.
- Negative: algorithm agility is limited in v0.1; crypto breaks require new protocol major.
