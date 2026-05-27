# Food Wallet Developer Contract

Food Wallet is an app integration shape for food-first Grain clients. It is not
a new Grain protocol, account system, backend service, store listing, or model
provider.

## Boundary

App owns camera, photo provider, and UI. The app chooses how a user captures a
meal, confirms an estimate, edits serving details, stores any local app state,
and presents the history.

Grain owns contract, validation, confirm, and export primitives. Grain gives the
app a strict Food Profile event shape, reducer-visible validation, scanner
preview/accept workflows, snapshot and sync primitives, local trust bundle
handling, and safe proof/export summaries.

Raw photos stay app-private. A Food Wallet app may use local camera frames,
photo-library assets, manual entry, barcode data, or a model result, but raw
photo storage is not a Grain SDK output. Grain safe reports must not include raw
photo bytes, raw QR strings, trust material, snapshots, sync bundles, identity
bundles, or COSE payloads.

No account, backend, or App Store claim is made by this page. The local pilot
and SDK checks prove source-level contracts only. Production apps still choose
their own account model, backend, platform signing, distribution channel,
privacy policy, and support process. First-party commercial apps built on this
contract live outside the public Grain protocol repository.

## AI Adapter

OpenAI is not required. AI providers are replaceable adapters that can turn an
app-owned photo, barcode, OCR result, nutrition database row, or manual input
into a candidate serving estimate.

The adapter output should be treated as untrusted app input until the app
confirms it and writes a Food Profile event through Grain. Provider prompts,
model choices, network calls, and retry policy live outside Grain SDK core.

## Food Graph Boundary

Food Graph is an advisory ingredient-intelligence layer. It may suggest related
ingredients, substitutions, category labels, similar meals, and review prompts
from app input or confirmed Food Wallet data, but it must not change
reducer-visible nutrition values, record trust, nutrition confidence, source
class, or confirmation state.

Food Graph output is not Grain protocol truth. It is computed guidance over
existing records. A Food Graph result cannot append ledger events, cannot
promote an untrusted record to trusted, cannot turn estimated nutrition into
confirmed nutrition, and cannot alter `mean.kcal` or `var.kcal`.

Food Graph must not persist raw vectors, embeddings, raw photos, model weights,
provider prompts, provider tokens, or hosted-model runtime artifacts in Food
Wallet records, safe summaries, SDK snapshots, or Grain exports. If an app uses
external or local ML infrastructure, that infrastructure is an app-owned
adapter outside Grain SDK core.

Food Graph has no required network runtime dependency. The SDK and AI sidecar
must remain usable without Hugging Face, model downloads, hosted inference,
OpenAI, or any other provider-specific runtime.

## Local Developer Gates

Use these commands from the repo root:

```bash
scripts/sdk/check_food_wallet_contract.sh
scripts/sdk/run_food_wallet_pilot.sh
scripts/sdk/check_swift_food_wallet.sh
scripts/sdk/check_kotlin_food_wallet.sh
```

`check_food_wallet_contract.sh` is the fast source policy gate. It checks the
Food Profile fixture, SDK safety policy, device/trust boundaries, this document,
and optional pilot reports.

`run_food_wallet_pilot.sh` runs the repo-local Food pilot, validates the safe
report with the Food Wallet contract checker, and writes artifacts under
ignored `artifacts/`.

The Swift and Kotlin gates run the platform package smokes plus Food Wallet
source scans. They prove the public SDK surfaces expose QR/trust/snapshot
workflow primitives without turning the SDK into a camera, photo store, account
backend, app-store package, or model-client wrapper.

## Integration Shape

1. The app captures or receives food evidence.
2. Optional app-owned adapters produce a serving estimate with explicit
   nutrition confidence.
3. The user confirms or edits the serving details in app UI.
4. The app writes a Food Profile event through Grain.
5. Grain validates, reduces, confirms scanner inputs, and exports safe status or
   proof summaries with record trust separate from nutrition confidence.
6. The app owns storage, backup, account, sharing, and distribution decisions.

Start with `scripts/sdk/run_food_wallet_pilot.sh` before wiring a real camera or
photo provider. That gate proves the reducer path and safe report contract
without requiring a phone, camera, backend, external account, or AI provider.
