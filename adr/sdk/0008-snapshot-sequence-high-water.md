# ADR 0008: Preserve Sequence High-Water Marks on Snapshot Restore

Status: Accepted

Date: 2026-10-23

## Context

Restoring an older portable-client store snapshot replaced `seq_by_ak` with
the snapshot's counters. A subsequent device lifecycle mutation could reuse
the same `(ak, seq)` for a different event, even if the earlier event had
already left the client. The snapshot bridge must preserve locally known
sequence allocation history without changing the frozen protocol.

## Decision

- Validate the entire snapshot before changing the store.
- For each author key, restore the maximum of the current store's counter and
  the snapshot's counter, retaining entries absent from either map.
- If the snapshot contains identity state, write the merged counters back to
  its `seq_state` before installing it. This preserves the high-water marks
  through identity saves and subsequent snapshot export/restore.
- Keep the existing replacement semantics for accepted scans, identity
  authorization, and lifecycle records. Counters do not grant authorization.
- Keep checked sequence allocation: a retained `u64::MAX` rejects allocation
  with `SDK_ERR_STORE_CONFLICT`; it must not wrap or restart at one.

## Alternatives considered

- Reject all older snapshots: prevents intended data restoration when retaining
  sequence high-water marks is sufficient for allocation safety.
- Merge only the in-memory counter map: the next identity save or exported
  snapshot would still contain stale counters and reintroduce the problem.

## Consequences and limits

- An identity-bearing restored snapshot can export different bytes from the
  input snapshot when the store already knows higher sequence values.
- Restoring an old backup into a fresh store cannot recover counters that are
  absent from both that store and the backup. Apps still own durable rollback
  protection and custody; this is not an anti-rollback guarantee for backups.
- A snapshot without identity has no persisted identity sequence state. Any
  retained counters remain in memory only until identity state is restored.
- This change does not merge authorization history, change identity/sync import
  semantics, or recover events that snapshot replacement removes.
- Snapshot v1, public API/FFI shapes, protocol encoding, and reducer conflict
  rules remain unchanged. No protocol major bump is required.

## Verification

`core/rust/grain-client-core/tests/storage_contract.rs` covers stale restore
followed by another event, an intervening identity save, repeated restore and
immediate persistence into a fresh store, newer incoming counters, exhausted
counters, and invalid snapshot rejection without state mutation.

## Invariants touched

- SDK-INV-0018a
- Protocol conformance vectors: none; this changes SDK store allocation only.
