# Terms of Reference (ToR) — Grain Protocol v0.1 Public Launch

This document defines what “done” means for the initial public open-source launch.

## Scope

Deliverables:
1) Protocol v0.1 frozen core (spec + profiles + freeze statement)
2) Conformance suite (vectors + runner contract)
3) Grain Core (reference implementation, Rust)
4) TypeScript runner smoke profile (C01 / Wave A)
5) Repository with high-quality docs (human + LLM-first)
6) Provenance discipline (Git history + CI evidence + signed tags)
7) LLM-oriented documentation for auditing and contribution

## Principles

- Byte-level interoperability is the metric.
- Conformance suite is the release gate.
- Frozen core means additive only, unless major bump.
- Privacy-by-default: cap_id is random; ciphertext is not CAS-addressed.
- Determinism over convenience: no arrival-order semantics.

## Acceptance criteria (v0.1 launch)

- `spec/` contains NES, CDDL, profiles, FREEZE statement.
- `docs/human/` explains Grain without requiring NES reading first.
- `docs/llm/` enumerates invariants and edge cases, with mappings to vectors.
- `conformance/` contains runner contract and initial vector sets.
- ADRs exist for all foundational decisions.
- CI blocks merges on:
  - malformed vectors
  - missing invariants/vector mapping
  - missing required spec artifacts

## Next phases

1) Court hardening Wave B (fuzz corpus + additional adversarial vectors).
2) Full independent TypeScript implementation (beyond runner smoke profile).
3) Grain SDK implementation and certification against full conformance suite.
