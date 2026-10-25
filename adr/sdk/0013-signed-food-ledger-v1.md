# ADR 0013: Signed Food Ledger v1

Status: Accepted

Date: 2026-10-25

## Outcome and boundary

Provide one additive client path: a confirmed food input becomes a signed Grain
ledger event, survives durable restart, and travels in a file independently
verified by TypeScript. Existing unsigned identities, snapshots and Food Wallet
helpers retain their API and are not relabeled as signed history.

The first producer covers root genesis, device grants/revokes and self-issued
estimated/measured IntakeEvent records using the existing from_profile branch.
It does not infer attestation from a user signature, change frozen semantics,
implement root rotation or reinterpret mutable update/delete as ledger edits.

## Wire objects

Use existing canonical DAG-CBOR types and the existing COSE profile. Every
journal item is COSE_Sign1 of a LedgerEvent whose body is the matching typed
object. Genesis is a root-authored sequence-zero LedgerEvent containing
LedgerGenesis; later root operations start at one. The root public key must
also be provided explicitly as the verifier's trust input.

A versioned SDK transfer container contains those signed events and referenced
NutrientProfile objects by their computed CID. The container adds no protocol
object types. Import verifies encoding, schema, CID, signatures, kid/public-key
binding and genesis before deriving reducer input. Valid grants/revokes retain
root-only, retroactive-revoke and conflict ignore-all rules. Malformed bundles
reject atomically; invalid signatures never enter conflict detection.

## Signer and durability

The application owns its Ed25519 private key and key handle. Rust constructs
the signing request and verifies the returned signature. The Swift coordinator
hides this bridge behind a confirmed-food workflow; test signers stay in tests.

1. Prepare an operation, reserve its sequence, and retain its exact bytes and
   operation ID in the private journal snapshot.
2. Persist that snapshot through the app's atomic storage adapter before calling
   the signer. A failed or uncertain persistence acknowledgement stops signing.
3. Sign the prepared bytes and commit the verified signed event in memory.
4. Persist the committed snapshot before returning success to the application.

After any storage error, discard the in-memory candidate and reload durable
state. If reload also fails, stop writes. Retrying an operation ID with the same
input resumes its reservation or returns the committed result; a different
input under that ID rejects. Reserved counters are never recycled. A crash
after signing can replay only the exact persisted operation bytes.

An application persistence adapter must provide atomic replacement and a clear
durability acknowledgement. Memory-only success is not durable success. The
initial Swift implementation serializes writers; cross-process sharing needs
an application-provided locking/CAS adapter and is not claimed implicitly.

## Recovery and migration

Snapshots and public transfer containers have distinct versions and purposes.
Snapshots retain private coordination state and counters; transfer files omit
private keys, sync secrets and raw photos but still contain sensitive food data.
Known sequence maxima survive recovery. A cold old backup cannot reveal unknown
later state; reuse of its signing key needs app-owned rollback recovery.

Legacy random-public-field identities have no corresponding signing private key.
Starting this API requires an explicit new signer-bound genesis. Legacy records
remain accessible through existing APIs. Reconfirmation creates a new record
with truthful provenance rather than fabricating a historical signature.

## Required acceptance

- Rust producer and independent TS verifier agree on canonical payload CID,
  author identity, signature validity, totals and conflict/revocation results.
- Public Swift workflow writes, persists, restarts, retries and exports a file;
  a separate TS process consumes that file with explicit trust input.
- Failure injection covers persistence before signing, persistence after commit,
  crash/retry, signer failure, old recovery, tampering and wrong trust.
- Existing API, platform binding and 187-vector conformance gates remain green.

The implementation includes Rust state/corpus tests, independent TypeScript
verification and a Swift file handoff with a second-process restart. CI remains
a merge gate; these tests do not establish production app or hardware claims.
