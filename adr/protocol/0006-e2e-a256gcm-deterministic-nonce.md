# ADR-0006: E2E baseline = HKDF-SHA256 + A256GCM with deterministic nonce

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
E2E encryption in v0.1 uses HKDF-SHA256 and AES-256-GCM only (A256GCM).
Nonce is derived deterministically (stateless, crash-safe) and MUST equal derived value.
AAD is cap_id raw bytes.
cap_id MUST be random (CSPRNG) and single-assignment.

## Rationale
AEAD nonce reuse is catastrophic; stateful counters are crash-prone and hard to standardize across runtimes.
Deterministic nonce removes runtime state and makes behavior reproducible.
Random cap_id prevents correlation on plaintext identifiers.

## Alternatives considered
See `docs/human/rationale/design-choices.md` and project discussion history.

## Consequences
- Positive: safer nonce lifecycle; simpler interop; privacy-by-default.
- Negative: crypto breaks require new profile/major; deterministic nonce binds correctness to derivation inputs.
