# ADR 0009: Preserve Sequence High-Water Marks on Identity Import

Status: Accepted

Date: 2026-10-24

## Context

Importing an older identity bundle into an initialized Rust or TypeScript
client replaced its saved sequence state. A later device operation could emit
a different event with the same `(ak, seq)`. Snapshot restore already preserves
local counters under ADR-0008; direct identity import needs the same protection
for the counters recorded in the current identity.

## Decision

- Validate the incoming bundle before mutation.
- Inside the atomic transaction, check root compatibility and retain the
  maximum sequence per author across the current and incoming identity bundles.
  TypeScript also merges the live allocator snapshot: public event and manifest
  operations can advance it without updating the saved identity. Retain entries
  missing from any input, comparing numeric values rather than decimal strings.
- Install the merged sequence map in both the allocator and the saved identity.
  Subsequent identity saves, repeated imports, and identity exports must not
  undo the merge. Valid store snapshots also persist these merged counters.
- Keep incoming authorization and existing lifecycle records unchanged by the
  counter merge. A retained counter does not authorize its author.
- Preserve Rust's checked allocation: importing an older bundle cannot reset
  an exhausted `u64::MAX` counter. Invalid input and transaction failures must
  leave the store unchanged.

## Alternatives considered

- Reject all imports into initialized identities: breaks supported same-root
  transfers even when retaining saved counters is enough to avoid reuse.
- Merge only allocator state: a subsequent identity save would reset it again.
- Merge authorization and lifecycle history: requires separate recovery-policy
  decisions and is outside this sequence-allocation fix.

## Consequences and limits

- Exported identity bytes can differ from the imported bundle because counters
  retain newer saved values. Public API, bundle schema, and protocol rules do
  not change. No protocol major bump is required.
- Rust covers sequence history saved in either identity bundle. Custom Rust
  stores must persist allocations with identity state atomically; unsaved
  low-level reservations are not reconstructed by identity import. TypeScript
  additionally retains all counters exposed by its live allocator snapshot.
- A fresh store importing an old backup cannot infer later sequence history
  missing from that backup. Apps own durable rollback protection and custody.
- Existing authorization replacement semantics remain: an older identity may
  omit devices or revocations still referenced by retained lifecycle records.
  A snapshot of that inconsistent state can be rejected on restore. This PR
  does not reconcile those records or claim complete backup recovery safety.
- TypeScript allocator overflow policy is unchanged; the explicit exhausted
  counter regression applies to Rust's checked u64 allocator.

## Verification

`core/rust/grain-client-core/tests/identity_device_lifecycle.rs` and
`core/ts/grain-sdk/scripts/test-sdk-invariants.ts` cover stale import followed
by another identity save and event, export/restart, repeated import, missing
author entries, higher incoming counters, and unchanged authorization rules.
Rust also covers snapshot persistence, exhausted counters, and invalid
sequence input without mutation. TypeScript also covers counters advanced only
by public event append and manifest put/delete, including export/restart after
import. Existing TypeScript transaction-failure
coverage continues to assert rollback of identity and allocator state.

## Invariants touched

- SDK-INV-0013, SDK-INV-0013a, SDK-INV-0014.
- Protocol conformance vectors: none; this changes SDK allocation only.
