# SCOPE v0.1

Protocol line: `v0.1.x` (`schema_major = 1`)

This document clarifies domain scope for v0.1 and separates:
- domain-neutral infrastructure invariants, and
- current domain profile content.

## 1) Domain-neutral core vs domain profile

Grain v0.1 includes two layers:

1. Domain-neutral core infrastructure:
- canonical encoding
- identity via content addressing
- signature verification
- append-only deterministic event processing
- E2E capability-based private sync
- deterministic manifest resolution

2. Domain profile currently implemented in v0.1 schemas/vectors:
- food events and related payload shapes.

Conclusion:
- v0.1 is not "schema-neutral" in practice because the shipped domain profile is food-first.
- v0.1 core invariants are domain-neutral by construction.

## 2) Coupling constraints

Frozen core layers MUST NOT require food-specific semantics:
- `encoding/cid/cose/ledger/e2e/manifest` rules must stay domain-agnostic.
- domain coupling is allowed only in concrete object/event `t` schemas and profile-level reducers for those types.

If food-specific logic appears inside core invariants, this is a design bug and must be treated as a freeze violation.

## 3) Verifiable physical events direction

Project direction:
- Grain is infrastructure for verifiable physical events.
- Food is the first production profile, not the final boundary.

Extension path (major-preserving):
- new domains add new `t` schemas and vector coverage,
- core deterministic/security invariants remain unchanged.

## 4) Portability to other domains

The v0.1 infrastructure model (`event + CID + signature + ledger + E2E + deterministic resolution`) is portable to domains such as:
- IoT telemetry with signed attestations,
- robotics operation events,
- supply chain event traceability,
- medical event provenance.

Domain adoption requires additive profile work:
- domain schemas/event types,
- domain reducer semantics,
- corresponding conformance vectors.

No frozen-core change is required for this class of expansion.

## 5) Non-goals and non-claims

Scope clarification does not change v0.1 semantics.
It does not claim:
- truth oracle behavior,
- social consensus,
- global registry authority,
- availability guarantees.

Signed data remains authorship/integrity evidence, not objective truth.
