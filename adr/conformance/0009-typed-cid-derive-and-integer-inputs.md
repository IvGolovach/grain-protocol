# ADR 0009: Typed `cid_derive` context and exact integer inputs

- Status: Accepted
- Date: 2026-11-23
- Owners: @IvGolovach
- Affects: Conformance | Core | Docs
- Invariants touched: INV-CID-005, INV-LED-009 (new)
- Conformance vectors impacted: POS-CID-003, NEG-CID-030, POS-LED-005, NEG-LED-060, NEG-LED-061 (new)

## Context

Running TypeScript-signed ledger events through the Rust runner (SDK ADR-0014)
exposed two gaps in the `runner_v1` contract. The Rust/TS divergence gate
missed both because no vector exercised them.

1. `cid_derive` applied the context-free closed-key check keyed by `t`. A
   `LedgerEvent` payload's `t` is its event type (NES §2.3.1). So for any
   genesis, grant, revoke or intake event, the op read the payload as that
   object and rejected `ak`/`seq`/`body` with `GRAIN_ERR_UNKNOWN_TOPLEVEL_KEY`.
   Payload CIDs underpin conflict detection (NES §6.5), yet the conformance
   interface could not derive them for real events.
2. `ledger_reduce` integer inputs diverged. The TypeScript runner parses
   vectors with exact JSON and turns unsafe integers into decimal strings, so
   it accepted decimal-string `seq`/`kcal`, including non-canonical forms such
   as `"007"`. Rust accepted JSON numbers only.

## Decision

1. `cid_derive` accepts optional `object_type`, with exactly the selector and
   validation semantics of `dagcbor_validate.object_type` (ADR-0012). Without
   it, behavior is unchanged. `NEG-CID-030` records why ledger payloads need it.
2. `ledger_reduce` event integers (`seq`, `mean.kcal`, `var.kcal`) MAY be JSON
   integers or canonical base-10 decimal strings (`0` or `-?[1-9][0-9]*`).
   Both runners implement the same grammar and ranges (`seq` ≤ 2^64−1, kcal in
   int64). Non-canonical strings reject with `GRAIN_ERR_SCHEMA`. This mirrors
   the existing output rule for unsafe integers.

## Rationale

Both are runner-boundary changes. They do not touch protocol bytes, CIDs,
signatures or reducer semantics. Accepting decimal strings in Rust, rather
than rejecting them in TypeScript, keeps exact transport for values above
2^53 in either direction. Rejecting leading zeros keeps one textual form per
integer.

## Consequences

- Independent implementers can check ledger payload CIDs through the suite.
- Known residual: a JSON literal such as `1.0` cannot be told apart from `1`
  after `JSON.parse` in TypeScript, so a TypeScript runner may accept it where
  Rust rejects it. No vector uses such literals. Closing this needs exact-JSON
  number-literal tracking in the TypeScript loader.

## Compatibility

- Breaking? No. Existing vectors are unchanged. The only newly rejected inputs
  are non-canonical decimal strings, which TypeScript alone accepted and no
  vector used.
- `runner_v1` operation names, CLI and output schema are unchanged.

## References

- `conformance/SPEC.md` (cid_derive, Runner JSON boundary)
- `conformance/contract/runner_v1.md`
- ADR protocol/0012 (typed context precedent), SDK ADR-0014
