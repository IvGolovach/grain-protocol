# Signed Ledger v1 (TypeScript)

SDK ADR-0014 defines this workflow. It writes and verifies real NES v0.1 ledger
events for any event type. It adds no protocol objects and changes no frozen
rule.

## Public surfaces

- `SignedLedgerWriter` (`core/ts/grain-sdk/src/signed-ledger.ts`): signer-bound
  producer over an application `SignedLedgerStore`.
- `verifySignedLedgerTransfer(json, trustedRootPubB64)`: independent verifier.
- `verifySignedFoodTransfer` is the food profile of the same verifier. It
  accepts only what the Rust/Swift food producer writes (SDK ADR-0013).
- `GrainSigner`: `{ publicKey: 32 bytes, sign(bytes) -> 64-byte Ed25519 }`.
  `ed25519SignerFromSeed` and `generateEd25519Signer` are Node conveniences.
  Key custody belongs to the application.
- `GrainValue` / `CidLink` / `encodeGrainValue`: the DAG-CBOR data model as
  plain values. Integers are bigint or safe integers; floats are rejected.

## Events

- `initialize(root)` writes `LedgerGenesis` at root sequence 0. It must happen
  first and is idempotent.
- `grantDevice` / `revokeDevice` are root-only (NES §6.2–§6.3). Revoking root,
  and re-granting a revoked key, reject.
- `append(signer, { operationId, t, body, tsMs?, objects? })` writes any other
  type. Known v0.1 types (`IntakeEvent`, `VoidEvent`, `CorrectionEvent`, ...)
  must match their CDDL production, including `v` and `t`. Unknown types are
  opaque profile events (NES §2.3). `objects` are CAS objects the body links to;
  they are exported with the ledger under their recomputed CIDs.
- Each author's sequence starts at 1 (root: 0 for genesis) and only increases.
- `VoidEvent` and `CorrectionEvent` have no effect on v0.1 totals (NES §6.9).

## Write order and recovery

1. Check the projected export size and item counts using unique attachment CIDs
   and the fixed signature length. Run the reducer on the projected journal so
   a missing kcal field or aggregate overflow rejects before reservation. Then reserve the next sequence; persist the private
   snapshot with the pending payload. No signer call happens before this save
   succeeds.
2. Call the signer over the exact `Sig_structure`; verify the COSE envelope
   with the signer's public key.
3. Persist the snapshot with the committed event; only then return `committed`.

A failed or uncertain save reloads the durable snapshot and throws
`SDK_ERR_SIGNED_LEDGER_STORE`. If the reload also fails, the writer stops.
Retrying with the same operation ID and input resumes the pending operation or
returns `already_committed`, including for an earlier committed operation after
the device was revoked. The v1 input digest includes the ordered attachment
list with repeats. Storage deduplicates those attachments by CID. On resume the payload is rebuilt from the retried
input. If it differs from the stored bytes, the snapshot was altered: the write
rejects with `INVALID` and the signer is not called. Different input under a used ID rejects with
`OPERATION_CONFLICT`. While an operation is pending, other operations reject with
`PENDING`. `abandonPendingOperation()` drops the reservation but never reissues
its sequence. One writer owns one store; coordinate other processes externally.

Opening a writer re-verifies the whole snapshot: signatures, genesis, key
bindings, object CIDs, export bounds, reducer acceptance and counters at or above
every committed sequence. The pending sequence must equal the author's stored
high-water mark and have no committed occupant. A
cold old backup cannot reveal signatures made after it. Using its key again
needs application-level rollback recovery or a newly granted device key.

## Private snapshot v1

```json
{"snapshot_v":1,"root_pub_b64":"…","events":["<COSE b64>"],"objects":{"<cid>":"<b64>"},
 "counters":{"<ak hex>":"<seq>"},"operations":{"<ak hex>:<operation id>":{"payload_cid":"…","input_sha256":"…"}},
 "pending":null}
```

It contains no private keys, but it does contain the records. Protect it like
the transfer.

## Transfer file

The container is the same as Signed Food Ledger v1:

```json
{"bundle_v":1,"root_pub_b64":"<32-byte root public key>","events":["<COSE_Sign1 base64>"],"objects":{"<CID>":"<canonical CBOR base64>"}}
```

Events are sorted by payload CID and deduplicated. The verifier requires the
root key from an independent trust source; `root_pub_b64` in the file must equal
it but never establishes trust by itself. Root-signed grants bind device keys;
an event from any other key rejects. Exactly one genesis, at root sequence 0,
is required.

## Verifier output

For each unique event: payload CID, author `ak`, `seq`, `t`, optional `tsMs`,
the decoded body, and `status`:
- `counted`: authorized under NES §6 and not conflicted;
- `unauthorized`: author not granted, or revoked (retroactively);
- `conflicted`: another eligible payload shares its `(ak, seq)`.
- `quarantined`: the envelope or a known typed body requires an unimplemented critical
  extension (NES §2.4). The SDK currently implements no critical identifiers.
  Quarantined records never participate in totals, authorization or conflicts.
  A transfer still needs an eligible genesis and a trusted key for every signature.

Also: authorized and revoked key IDs, objects by CID, and the reducer's
`sum_mean`/`sum_var` kcal with its diagnostics. A valid signature proves who
wrote a record and that it was not changed. It does not prove the record is true.

## Limits

At most 4096 events and 4096 objects. At most 16,000,000 UTF-8 bytes of
transfer JSON and 34,000 bytes per COSE envelope. Typed-object limits apply
(LedgerEvent payload ≤ 32,768 bytes). Each write rewrites the whole snapshot:
this is a bounded local journal, not an archive.

## Executable acceptance

- `core/ts/grain-sdk/scripts/test-signed-ledger.ts`: lifecycle, idempotency,
  restart, revocation, durability faults, value encoding, verifier rejections,
  the Rust signed-food corpus through the generic verifier and, with
  `GRAIN_RUST_RUNNER_BIN`, Rust runner acceptance of every TS-signed event.
- `core/ts/grain-sdk/scripts/test-signed-food.ts`: the food profile.

Not covered: browser runtimes (the SDK uses `node:crypto`), hardware key
custody, multi-writer coordination and power-loss guarantees of a given store.
