# Signed Ledger (TypeScript)

Use this when a Node application must write records that anyone can verify
from a file. The signature authenticates the author and signed bytes of each record present. It
works for any event type. Food, inventory, symptoms or your own profile are
all events with their own `t`.

The SDK writes real Grain v0.1 ledger events: canonical DAG-CBOR payloads,
COSE_Sign1 with Ed25519, and payload CIDs. Your application owns the keys and
the storage.

## Write

```ts
import {
  CidLink, encodeGrainValue, ed25519SignerFromSeed, InMemorySignedLedgerStore,
  SignedLedgerWriter, verifySignedLedgerTransfer
} from "grain-sdk-ts";

// Load these seeds from your key custody; never create new ones per launch.
const root = ed25519SignerFromSeed(rootSeed);
const phone = ed25519SignerFromSeed(phoneSeed);

const ledger = await SignedLedgerWriter.open({
  trustedRootPublicKey: root.publicKey,
  store: new InMemorySignedLedgerStore() // use durable, atomic storage in an app
});
await ledger.initialize(root);
await ledger.grantDevice(root, { operationId: "grant-phone", devicePublicKey: phone.publicKey });

// Use observation times saved with the input so retrying reproduces the same record.
const recordedAtMs = 1795456800000;
const symptomObservedAtMs = 1795460400000;

const profile = {
  v: 1, t: "NutrientProfile", dataset_snapshot_id: "my-app-v1", source: "estimated",
  basis: "per_serving", nutr: { kcal: 640 }, uncert: { kcal: 36 }
};
await ledger.append(phone, {
  operationId: "meal-2026-11-23-lunch",
  t: "IntakeEvent",
  tsMs: recordedAtMs, // preserve the original observation time for a retry
  body: {
    v: 1, t: "IntakeEvent", source_class: "estimated", mode: "from_profile",
    profile: CidLink.to(encodeGrainValue(profile)), servings: 1,
    mean: { kcal: 640 }, var: { kcal: 36 }
  },
  objects: [profile]
});

// Any other event type is stored as an opaque profile event.
await ledger.append(phone, {
  operationId: "symptom-2026-11-23-1",
  t: "SymptomObservation",
  body: { symptom: "bloating", severity: 3, observed_at_ms: symptomObservedAtMs }
});

const transferJson = await ledger.exportTransfer();
```

Retry with the original operation ID and input. A retry that completes a reserved
write returns `committed`. A previously saved write returns `already_committed`.
Both receipts indicate success. A changed input under the same ID is rejected.
Keep the original timestamp and attachment list with that ID. If a write would
exceed the transfer limit, omit required kcal fields or overflow a total, it
fails before consuming a sequence number. The writer saves before it signs, and saves again before it reports success.
After a crash it resumes the reserved operation instead of reusing a sequence
number.

## Verify

```ts
const result = verifySignedLedgerTransfer(transferJson, trustedRootPublicKeyBase64);
for (const event of result.events) {
  console.log(event.t, event.status, event.payloadCid);
}
console.log(result.sumMeanKcal, result.diagnostics);
```

Get the trusted root key from somewhere other than the file. The file includes
it, but a file cannot vouch for itself. An invalid signature, unknown signing key, malformed field or
object CID mismatch rejects the transfer. The container has no signature over
the record list. To detect omitted records, compare the verified CIDs with an
independently trusted record of the expected contents. `status` is `counted`,
`unauthorized` (for example a revoked device; revocation is retroactive) or
`conflicted` (two eligible records with the same author and sequence).
A `quarantined` record requires an unknown critical extension. Its bytes
remain in the file and it contributes neither authority, conflicts nor totals.

## What it does not prove

A signature shows who wrote a record and that it was not changed. It does not
show that the record is true: a person can sign a wrong estimate.
`VoidEvent` and `CorrectionEvent` make no direct contribution to v0.1 totals. An eligible conflict can exclude an intake.
Apps that hide voided entries do so in their own views.

## Limits

One writer per store. Up to 4096 events per ledger. Node only (`node:crypto`).
For Swift apps writing food entries, see [Signed Food Ledger](./signed-food-ledger.md).
The full contract is in
[`sdk/workflows/contract/signed_ledger_v1.md`](../../../sdk/workflows/contract/signed_ledger_v1.md).
