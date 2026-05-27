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
- `RecordTrust`: `verified_source`, `self_issued`, or `untrusted`.
- `NutritionConfidence`: `confirmed`, `estimated`, `incomplete`, or `unknown`.
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
- Grain signatures and trust checks attest the source path. They do not claim
  calories or macros are objectively true.

Record trust and nutrition confidence are deliberately separate. Record trust
answers whether the source/signature path can be trusted. Nutrition confidence
answers how reliable the nutrition values are after review. A record can be
self-issued and unchanged while still carrying estimated calories.

- `verified_source`: the data came from a trusted issuer.
- `self_issued`: the local user created and signed the record.
- `untrusted`: the app can show a preview, but must not treat it as trusted
  food data without user action.
- `confirmed`: the user explicitly reviewed and accepted the nutrition values.
- `estimated`: values came from rough input, barcode, AI, or approximation.
- `incomplete`: important nutrition fields are missing.
- `unknown`: confidence cannot be determined.

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
