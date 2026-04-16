# ADR-0004: Root-only authority and retroactive revoke

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
Only the root key in LedgerGenesis may issue DeviceKeyGrant/DeviceKeyRevoke in v0.1.
Revoke is retroactive and time-independent: revoked keys are unauthorized for all events.

## Rationale
Delegated admin introduces complex conflict semantics and is intentionally excluded from v0.1.
Retroactive revoke removes reliance on trusted time and makes authorization order-independent.

## Alternatives considered
See `docs/human/rationale/design-choices.md` and project discussion history.

## Consequences
- Positive: simple deterministic authorization.
- Negative: compromised root requires new genesis; no root rotation in v0.1.
