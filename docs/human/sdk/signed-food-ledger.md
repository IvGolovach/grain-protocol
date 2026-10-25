# Signed Food Ledger

Use this path when confirmed food entries must survive restart and be verifiable
by another client. Rust constructs typed Grain events; your Swift app owns the
Ed25519 signer and storage; Node TypeScript verifies exported files independently.
The existing Food Wallet helpers and scanner APIs remain available.

## App integration

Add the `GrainSignedFood` Swift product. Implement `GrainFoodSigner` around an
application-owned Ed25519 key. Its `publicKey` is the 32-byte public key;
`signPreparedMessage` signs the supplied bytes unchanged. Keep the corresponding
private key in your chosen custody system across app restarts. Do not create a
new temporary key whenever the wallet opens.

```swift
import GrainSignedFood
import GrainClientIOSAdapters

let persistence = try GrainFileSnapshotPersistence.applicationSupport(
    subdirectory: "GrainSignedFood", filename: "journal.snapshot"
)
let wallet = try GrainSignedFoodWallet(
    trustedRootPublicKey: enrolledRootPublicKey, persistence: persistence
)
// rootSigner is the app's persistent Ed25519 signer enrolled under that root.
_ = try await wallet.initialize(using: rootSigner)

// Confirm the input with the user first. Retain this ID across retries.
let food = GrainConfirmedFood(
    operationId: "meal-2026-10-25-001", source: .estimated,
    meanKcal: 700, varianceKcal: 4
)
let receipt = try await wallet.record(food, using: rootSigner)
let privateFoodExport = try await wallet.exportTransfer()
```

A completed receipt follows both signature verification and acknowledged storage.
An identical retry returns AlreadyCommitted. Keep the same operation ID and input
after a retryable failure. Changed input under an existing ID rejects. The actor
saves a reservation before calling the signer, then saves the signed event before
returning success. If storage acknowledgement fails it reloads; if reloading fails
it stops writing. The app can reopen it after storage is repaired.

One wallet owns each storage location. Coordinate other app processes externally.
The file adapter proves atomic process-restart behavior; choose stronger storage
if your app requires power-loss or rollback resistance. Public imports are
read-only on a fresh wallet because they omit private sequence reservations.
Recovery from an old private backup cannot discover signatures made after it.

Use `grantDevice` and `revokeDevice` with the root signer to manage app-owned device
signers. Revocation is retroactive under Grain v0.1. A signature authenticates the
author; it does not prove that a meal estimate is accurate. This producer supports
estimated/measured kcal entries with one serving. Attested issuer claims, edits,
deletes, root rotation and automatic legacy conversion are outside this path.

## Independently verify a file

Obtain the root key through your own trust policy, independently from the export.
Write its canonical base64 public bytes to `trusted-root.b64`, and the exported
JSON to `transfer.json`. The file contains sensitive food history: protect it.

```bash
npm --prefix core/ts/grain-sdk run build
node core/ts/grain-sdk/dist/scripts/verify-signed-food.js transfer.json trusted-root.b64
```

The verifier checks canonical typed objects, CIDs, Ed25519 signatures, author/key
bindings, genesis and linked profiles before reduction. Its output includes
sorted payload CIDs, count, totals and diagnostics. Large integer values remain
exact decimal strings. A rejected file emits a diagnostic code and exits nonzero.

```ts
import { verifySignedFoodTransfer } from "grain-sdk-ts";
const verified = verifySignedFoodTransfer(fileContents, enrolledRootPubB64);
```

## Reproduce the checks

```bash
npm ci --prefix core/ts/grain-ts-core
npm ci --prefix core/ts/grain-sdk
cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core --test signed_food
npm --prefix core/ts/grain-sdk run test:signed-food
scripts/sdk/check_swift_package.sh
```

The last command needs Rust, Swift and Node. It runs storage/signer fault
injection, real file restart and a Swift-to-Node transfer. Temporary keys are
test-only and never exported. These are local/CI proofs; they do not establish
physical-device deployment or production key custody.

See the [workflow contract](../../../sdk/workflows/contract/signed_food_v1.md)
for limits, recovery, migration and rejection rules, and
[SDK ADR-0013](../../../adr/sdk/0013-signed-food-ledger-v1.md) for the design.
