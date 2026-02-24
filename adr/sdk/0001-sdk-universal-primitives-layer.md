# ADR 0001: SDK Universal Primitives Layer (TOR-SDK-A01)

Status: Accepted

Date: 2026-02-24

## Context

Protocol/core layers are frozen at major v1 and already conformance-gated.
Application developers still had to compose risky low-level paths manually:
canonical bytes, identity sequencing, E2E nonce/profile constraints, manifest resolution, and transport framing.

Without a strict SDK boundary, implementation mistakes become easy and often silent.

## Decision

Introduce a TypeScript SDK layer at `core/ts/grain-sdk` with these constraints:

1. SDK adds no protocol semantics.
2. SDK is strict-by-default and fail-closed on sensitive boundaries.
3. Core diagnostics are preserved; SDK-only errors are namespaced `SDK_ERR_*`.
4. SDK public API is orchestration-focused:
   - identity lifecycle
   - event lifecycle helpers
   - E2E helpers
   - manifest helpers
   - transport helpers
   - canonicalization toolkit
   - evidence bundle helper
5. SDK conformance is enforced in CI by running:
   - full protocol suite through SDK runner
   - SDK-specific invariant checks
   inside existing required context `ts-full`.

## Consequences

- Developer onboarding improves without softening protocol behavior.
- Strictness regressions at SDK boundary fail CI.
- No branch protection context rename is required.
- SDK remains domain-neutral; domain adapters are additive.

## Invariants Touched

- SDK-INV-0001..0007 (`docs/llm/SDK_INVARIANTS.md`)
- Protocol invariants remain unchanged (`docs/llm/INVARIANTS.md`)
