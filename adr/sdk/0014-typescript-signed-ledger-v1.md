# ADR 0014: TypeScript Signed Ledger v1

Status: Accepted

Date: 2026-11-23

## Context

Until SDK ADR-0013, no SDK path produced a signed Grain record. The TypeScript
`GrainSdk` identity generates a random 32-byte value as its "root public key",
with no private key. Its events are unsigned reducer-model records whose
`payload_cid` is an arbitrary string. The Rust client core identity works the
same way. ADR-0013 added the first signed path: Rust builds the events, Swift
signs them. TypeScript only verified files, and only food files. A web or
Node application still had no way to write a signed record.

## Decision

Add a domain-neutral Signed Ledger to the TypeScript SDK:

- `SignedLedgerWriter` writes NES v0.1 ledger events of any type through an
  application-owned `GrainSigner`. It follows the ADR-0013 order: reserve and
  persist, sign, verify, persist, then succeed. Operation IDs live in the
  private snapshot, not in the signed records, so signed bodies carry only
  domain data.
- `verifySignedLedgerTransfer` verifies the shared transfer container for any
  event type, keeps unknown types (NES §2.3), and reports each event's status
  under NES §6.
- `verifySignedFoodTransfer` is re-implemented as a food profile over the same
  parsing and event verification. The original 73 regression checks continue to apply. Conformance ADR-0010 records the critical-extension rule.
- `GrainValue` and `CidLink` let applications write DAG-CBOR data without
  handling CBOR nodes. Floats and lone surrogates are rejected before encoding.

The legacy `GrainSdk` identity/events model stays. It is documented as an
unsigned reducer model and is never accepted as signed evidence.

## Consequences

- Node applications can write records that the Rust core accepts
  independently: `cose_verify`, typed `dagcbor_validate`, typed `cid_derive`
  and `ledger_reduce` all pass in CI.
- There are now two producers of signed records: Rust/Swift (food) and
  TypeScript (generic). Both share one container format and one verifier core.
- Not included: a browser signer (the SDK uses `node:crypto`), Kotlin and WASM
  signed producers, merging transfers from several writers, and incremental
  persistence.

## Verification

`test-signed-ledger.ts` covers the lifecycle, idempotency, restart, revocation,
durability faults (save before sign, save after sign, signer failure, invalid
signature, failed reload, abandon), value encoding and verifier rejections.
It also runs both cross-implementation checks above. The food profile keeps
`test-signed-food.ts` and the Swift handoff.
