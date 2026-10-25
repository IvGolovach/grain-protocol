# Signed Food Ledger v1

SDK ADR-0013 defines this additive workflow. It uses existing NES v0.1 objects,
COSE signatures and reducer rules. It is separate from the unsigned client
workflow v1 and Food Wallet safe-summary formats.

## Public surfaces

- Rust `GrainSignedFoodJournal` owns typed payload construction, signature
  verification, private reservation state and atomic in-memory mutations.
- Swift `GrainSignedFoodWallet` serializes calls and coordinates application-owned
  `GrainFoodSigner` and `GrainSnapshotPersistence` adapters.
- Node TypeScript `verifySignedFoodTransfer(json, trustedRootPubB64)` independently
  verifies a file and returns sorted unique payload CIDs, event count, exact
  kcal mean/variance and reducer diagnostics. Values beyond JS safe integers
  are decimal strings. This function has no network or Rust dependency.
- Kotlin receives the generated low-level binding bridge. A Kotlin durable food
  facade and a WASM signed-food API are not part of this version.

## Operation and persistence contract

Initialize with an actual app-owned Ed25519 root signer. Genesis is a root-signed
LedgerEvent with `seq=0`, `t=LedgerGenesis` and a typed LedgerGenesis body. The
producer supports root-only DeviceKeyGrant/DeviceKeyRevoke and confirmed
estimated/measured IntakeEvent from_profile with one serving and kcal mean and
variance. A canonical NutrientProfile is stored by CID and must match the
intake's values, source and per_serving basis. No attested claim is inferred.

Later operations start at one. `operationId` is 1..128 ASCII alphanumeric,
hyphen or underscore characters, persisted in body.ext under
`grain.food.operation_id`. IDs are scoped to the author. Retrying identical
input resumes the exact reserved bytes or returns AlreadyCommitted; changing
input under a committed ID rejects. A pending operation blocks another operation.
Overflow and invalid input reject before a new signing request is issued.
Until genesis is committed, other preparations and public export reject with
`SDK_ERR_SIGNED_FOOD_PENDING`; retry initialization to resume its reservation.

Rust low-level preparation returns Prepared, a sequence, operation ID, exact
base64 COSE Sig_structure and private snapshot. The host must save that snapshot
before calling any signer, then commit the returned signature and save the new
snapshot before acknowledging success. Rust memory alone is not persistence.
The Swift actor enforces this order and returns only a receipt. It reloads storage
after failed or uncertain save acknowledgement. A failed reload stops that writer.
If the first save fails and reload confirms an empty store, the wallet returns
to its initial state so initialization or import can be retried. Once any snapshot
has been saved or loaded, a missing snapshot also stops the writer: silently
restarting from empty could reuse sequences whose signatures already escaped.
Signer failures retain the exact durable reservation. Never reuse a sequence for
different bytes. There is no implicit cancellation that recycles reservations.

The persistence adapter must provide atomic replacement and the durability
acknowledgement needed by the app. One actor owns one storage location; the app
must prevent other actors/processes from writing it concurrently. The included
file adapter and tests prove atomic process-restart recovery, not hardware
power-loss guarantees. Key retention, hardware custody, rollback-resistant
storage and multi-process locks remain explicit app responsibilities.

## Transfer file

UTF-8 JSON with exactly these fields (no duplicate or unknown keys):

```json
{"bundle_v":1,"root_pub_b64":"<32-byte root public key>","events":["<COSE_Sign1 base64>"],"objects":{"<profile CID>":"<canonical profile CBOR base64>"}}
```

Base64 is canonical padded standard base64. The version is the JSON integer
literal `1` (not `1.0` or `1e0`). The verifier requires an independently supplied
matching trusted root; reading root_pub_b64 from the file is not trust
establishment. Every event contains a typed LedgerEvent whose body has the
matching typed kind. Protected kid must equal the payload author and derive from
the verifying public key. Root-signed grants bind device public keys; non-root
grants do not establish trust. Exactly one unique root genesis at seq zero is
required. Profile CIDs and links are recomputed before reduction.

Invalid signature, encoding, schema, CID, source binding, trust or unsupported
mode rejects the entire SDK transfer atomically. This strict container rejection
does not change protocol quarantine rules. Only verified events reach the
reducer. Duplicate payload CIDs deduplicate. Different payloads at `(ak,seq)`
retain conflict ignore-all semantics; root-only grants and retroactive revokes
retain existing semantics. One author operation ID assigned to different payload
CIDs rejects the SDK container. Rust exports in payload-CID order, using the
lexicographically smallest base64 envelope for duplicate payloads.

Limits: at most 4096 events and 4096 profile objects; 16,000,000 UTF-8 bytes per
transfer JSON; 34,000 bytes per COSE envelope; existing typed-object limits also
apply (LedgerEvent payload 32,768 bytes). Private base64 snapshots are capped at
16,000,000 characters, so importing a file must also fit the resulting snapshot.
This is a bounded local journal, not a segmented archival store.
Each mutation currently revalidates the complete journal and writes a complete
snapshot. The item cap bounds storage; it is not a mobile latency guarantee.
Incremental verification and segmented persistence require separate performance
measurement and recovery-equivalence tests before changing this safety model.

Transfers contain sensitive food data and public verification material. They
contain no private signing keys, sync secrets or images. They are intentionally
not diagnostic telemetry or Food Wallet safe summaries. Protect exports and
private snapshots according to app data policy; never log either payload.

## Recovery and legacy compatibility

Private snapshot v1 stores the transfer, per-author sequence maxima, pending
operation and read-only state. It is a separate format from bundle_v1. Same-root
restore merges known history and maxima, preserving current pending bytes and
rejecting inconsistencies without mutation. A public transfer imported into a
fresh journal is read-only: it omits private sequence reservations. Import into
an existing writer merges verified history only when no operation is pending.

A cold stale private backup cannot reveal unknown newer signatures. The app must
recover newer state or use a newly granted device key before continuing in that
case. Copying one writer state to two live writers is not supported; verified
conflicts are reported, not hidden. Old random-public-field identities cannot
become real signing keys. Existing APIs remain unchanged; start a fresh explicit
signer-bound genesis and reconfirm any legacy record the user wants to append.

## Diagnostics and executable acceptance

Core GRAIN_ERR codes remain unchanged. SDK errors use SIGNED_FOOD_INVALID,
TRUST, LIMIT, UNSUPPORTED, PENDING, READ_ONLY, OPERATION_CONFLICT, SEQUENCE and
STORE under the `SDK_ERR_` prefix; unauthorized authors use SDK_ERR_UNAUTHORIZED_AK.
Receipts expose reducer diagnostics such as SEQ_CONFLICT and AK_REVOKED. A
Committed receipt means durable history exists, not that every event contributes
to totals. Swift wraps storage and signer failures without including payloads.

- `core/rust/grain-client-core/tests/signed_food.rs`: state machine, rejection
  atomicity, retry, recovery, revocation, conflict, overflow and corpus drift.
- `sdk/workflows/signed-food/v1.json`: deterministic synthetic signed files,
  separate from legacy client workflow fixtures. No application private keys.
- `core/ts/grain-sdk/scripts/test-signed-food.ts`: independent verification,
  shuffled/duplicate inputs, large sequences and adversarial mutations.
- `GrainSignedFoodSmoke`: real CryptoKit signing, file restart, uncertain writes,
  signer failure, stopped writer and actor concurrency.
- `scripts/sdk/check_swift_package.sh`: Swift exports a file; a separate Node
  process verifies it. All legacy Swift checks continue to run.

Neither these checks nor green CI prove physical-device deployment, app adoption,
nutritional accuracy or production key custody.
