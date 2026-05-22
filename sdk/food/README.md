# Food Wallet Contract

This directory defines the app-facing Food Wallet contract for Grain clients.
It is intentionally higher level than the protocol: app developers should work
with meal estimates, trusted serving offers, confirmed intake entries, daily
totals, and safe summaries instead of raw CBOR, COSE, QR payloads, snapshots,
or trust material.

The named contract concepts are:

- `FoodIntakeEntry`: a confirmed meal record that can be reduced into totals.
- `MealEstimateCandidate`: transient structured output from a photo or AI
  provider.
- `VerifiedServingOffer`: a serving offer that has passed trust validation.
- `FoodIntakeDraft`: the required user-confirmation boundary before append.
- `TrustStatus`: `verified`, `self_issued`, `estimated`, or `untrusted`.
- `FoodSourceClass`: `attested`, `measured`, or `estimated`.
- `NutritionInsight`: advisory nutrition text derived from confirmed data.
- `SafeFoodSummary`: exportable app summary without raw protocol material.

The first product shape is local-first food tracking:

- The app owns camera UI, photo provider selection, confirmation UX, and local
  display caches.
- Grain owns the typed contract, trust labels, confirmation boundary, reducer
  inputs, and safe export shape.
- Photos are transient provider input. Raw photos are not stored by this
  contract.
- AI advice is advisory. It may produce structured estimates or nutrition
  guidance, but it does not directly append ledger events.

Trust status is deliberately explicit:

- `verified`: the data came from a trusted issuer.
- `self_issued`: the local user created and signed the offer.
- `estimated`: a user-confirmed estimate, often from an AI/photo provider.
- `untrusted`: the app can show a preview, but must not treat it as trusted
  food data without user action.

Run:

```sh
python3 tools/ci/check_food_wallet_contract.py
```

The checker validates schema drift, deterministic fixtures, and safe-summary
redaction boundaries.

Safe summaries and app exports may persist confirmed nutrition entries, totals,
and advisory insights only. They must not include raw photos, raw trust bundles,
raw snapshots, sync bundles, identity bundles, private keys, COSE payloads, or
raw QR payload material.
