# Grain Conformance Suite

Conformance is the release gate for Grain.

Passing conformance in **Strict Conformance Mode** is the conformance criterion for Protocol v0.1.
A strong interoperability claim is made after two independent implementations pass the full suite.

## What this suite is

- A set of **positive and negative vectors** (machine-readable).
- A **language-agnostic runner contract** (SPEC.md) so any implementation can plug in.
- A mapping from **protocol invariants** to vectors:
  - `docs/llm/INVARIANTS.md`
  - `docs/llm/EDGE_CASES.md`

## What this suite is not

- Not a benchmark.
- Not a fuzzing harness (though you can add fuzzing separately).
- Not a centralized certification authority. Anyone can run it.

## Structure

- `vectors/` — test vectors grouped by area
- `SPEC.md` — runner interface
- `contract/runner_v1.md` — frozen CLI/output contract for portability
- `harness/` — optional tooling for vector validation (format-level)

Reference runner implementation:
- `core/rust/grain-runner`

Cross-language independent implementation:
- `runner/typescript` (full strict suite; C01 retained as Wave A smoke lens)

## Wave A byte-level coverage

Conformance Wave A adds byte-path closure for:
- raw CBOR-seq framing (`parse_cborseq_stream_v1`) for ledger/manifest streams
- deterministic HKDF expected-bytes checks (`e2e_derive_v1`)
- UTF-8 raw-byte sorting traps (multi-byte / normalization pitfalls)
- mixed manifest resolution scenarios (eligible/ineligible/quarantine/conflict/tombstone)

Wave A vector IDs use: `POS/NEG-<AREA>-WA-####`.

## Strict Conformance Mode

All vectors assume Strict Conformance Mode:
- baseline limits enforced exactly
- reject non-canonical inputs
- deterministic diagnostic codes (for example `GRAIN_ERR_*`, `NONCE_PROFILE_MISMATCH`, `SEQ_CONFLICT`)
- vectors are concrete; placeholder/illustrative vectors are not allowed

## Provenance

- Conformance verdicts are release gates in CI.
- CI emits commit-bound evidence bundle `evidence-<commit_sha>.zip`.
- Local `.local-architect-reports/**` is for local analysis only and is never committed.
