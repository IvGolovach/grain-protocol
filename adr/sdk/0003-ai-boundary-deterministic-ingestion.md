# ADR 0003: SDK AI Boundary & Deterministic Ingestion (TOR-SDK-A03)

Status: Accepted

Date: 2026-02-26

## Context

SDK already provides strict protocol orchestration, but model-generated suggestions (LLM/CV/agents) can bypass safety if integrators append raw or loosely transformed payloads.

We need a deterministic ingestion firewall that:

1. does not change frozen-core semantics,
2. keeps SDK model/vendor/network agnostic,
3. guarantees explicit side effects only after deterministic acceptance.

## Decision

1. Add `sdk.ai` boundary with two-step contract:
   - `accept(candidate)` (pure, no side effects)
   - `applyAccepted(token)` (explicit side effect)
2. Remove public `sdk.store` from `GrainSdk` API (runtime-hidden `#store`).
3. Introduce opaque accepted token registry:
   - non-forgeable runtime token
   - TTL + bounded pending registry
   - deterministic reject codes for forged/unknown/expired tokens
4. Define `AICandidateEnvelopeV1` with ingestion-specific rules:
   - decimal strings for numeric ingestion fields (conversion convenience only)
   - base64 standard for structured bytes fields
   - deterministic set-array sort normalization, duplicate reject
5. Preserve protocol strictness:
   - strict DAG-CBOR validate + CID derive before acceptance
   - unknown critical extensions -> deterministic quarantine
6. Add no-network CI guard for SDK core paths.

## Consequences

- Integrators get a deterministic firewall for model outputs.
- SDK can no longer be bypassed through direct public store access.
- Breaking SDK API change: package bumped to `0.2.0` while protocol remains major `1`.
- No frozen-core semantics or conformance expected results are changed.

## Invariants touched

- `SDK-AI-001` .. `SDK-AI-007`
- Existing SDK invariants remain active (`SDK-INV-0001` .. `SDK-INV-0010`)
