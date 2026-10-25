# ADR 0010: Merge Identity History Before Persisting a Restorable Client

Status: Accepted

Date: 2026-10-24

Supersedes: the identity authorization replacement behavior and resulting
snapshot inconsistency limit described in SDK ADR-0009. Its sequence guarantees
and cold-backup limits remain applicable.

## Context

Replacing identity metadata from an old bundle leaves current lifecycle records
in place. The bundle can then omit a granted device or its later revocation.
Snapshot restore correctly rejects that inconsistent state. A stale import can
also make a locally revoked device appear authorized again.

## Decision

- Same-root identity import merges known devices and revocations instead of
  replacing them. Revocation wins over a grant and cannot be removed by an older
  bundle. Retain current device labels/order and append previously unknown
  devices in author-key order; sort the revocation union.
- Require the same root ID, root public key, and sync secret. Reject conflicting
  key material with `SDK_ERR_IDENTITY_CONFLICT`; import is not a rotation API.
- Preserve the current active key if still authorized. Otherwise use the
  incoming active key if authorized by the merged state, then fall back to root.
- Retain the per-author sequence maxima established by ADR-0009, including
  TypeScript live allocator state. Validate the complete merged identity before
  saving it. Counter entries alone never authorize a device.
- Rust identity and sync import share the existing sync merge implementation.
  Direct Rust identity import additionally validates every retained lifecycle
  record against the merged identity before saving allocator or identity state.
  Inconsistent retained history rejects with `SDK_ERR_IDENTITY_CONFLICT` and
  leaves all state unchanged.
- Keep accepted scans and lifecycle records intact. Identity import does not
  invent events, delete history, or import the source client's event log.
- Perform conflict checks, merge, validation, and persistence atomically.

## Alternatives considered

- Delete events absent from an old identity: discards committed history.
- Accept snapshots with missing devices/revocations: weakens restore validation
  and can reauthorize a revoked device.
- Reject every stale bundle: safe but needlessly prevents useful recovery when
  the current store already contains the required identity data.

## Consequences and limits

- This intentionally changes same-root import behavior. It no longer removes
  devices/revocations, overwrites local labels or active selection, or silently
  changes the sync secret. There is no destructive reset implied by import.
- A valid client remains snapshot-restorable after importing an older identity.
  A legacy inconsistent client needs a compatible bundle containing the missing
  device metadata and sufficient sequence state. If neither input contains it,
  reject rather than derive public keys from author IDs or discard events.
- A fresh client cannot recover unknown later revocations, events, or counters
  from an old backup. Apps still own protected persistence and rollback recovery.
- TypeScript retains the same authorization merge rules, but its generic ledger
  remains governed by the protocol reducer. The Rust preflight applies to the
  narrower derived lifecycle records used by the portable snapshot bridge.
- Snapshot replacement, pairing, wire schemas, public FFI shapes, and frozen
  protocol authorization/conflict rules remain unchanged. No protocol major bump
  is required; release notes must describe the SDK behavior change.

## Verification

- Rust `identity_recovery`: stale grant/revoke imports, newer incoming history,
  idempotent import, active-key fallback, secret conflict without mutation, and
  recovery of legacy inconsistent state only with sufficient identity data.
- Rust `binding_api`: public binding flow through old identity import, retained
  scans and revocations, snapshot export/restore, and another device operation.
- Existing Rust identity/sequence, snapshot, and sync tests retain their checks.
- TypeScript `SDK-REG-0003`: grant/revoke retention, export/restart, incoming
  devices/revocations, and secret conflict without identity/allocator mutation.

## Invariants touched

- SDK-INV-0012, SDK-INV-0013, SDK-INV-0013a, SDK-INV-0013b, SDK-INV-0014.
- Protocol vectors: none; snapshot validation remains strict.
