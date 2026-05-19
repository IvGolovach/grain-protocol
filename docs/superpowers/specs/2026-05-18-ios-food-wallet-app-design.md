# MealMark iOS App Design

## Goal

Build MealMark, the first App Store-oriented iOS app on the Grain Food Wallet
contract: a private, camera-first food tracker where AI creates editable
estimates and Grain stores only user-confirmed food records.

## Product Shape

The app is for normal people who want easier food tracking. It should feel like
a calm Apple-native food notebook, not a protocol console. The core loop is:

1. The user captures food with photo, QR scan, text, or repeat.
2. AI creates a draft with likely food name, portion, calorie range, confidence,
   and assumptions.
3. The user edits assumptions and confirms the draft.
4. Grain records the confirmed entry with explicit source and trust status.

The app must not present estimates as medical advice or verified nutrition.
Photo estimates are advisory and become durable only after user confirmation.

## App Surface

The first product app lives in `apps/ios-food-wallet`. It is a first-party app
surface, separate from `examples`, `templates`, and `sdk/swift`.

The app reuses `sdk/swift` and the `GrainFoodWallet` facade. It does not call
raw FFI, DAG-CBOR, COSE, QR payload internals, snapshots, or private trust
material from app UI.

## Main Screens

- Today: confirmed entries, daily kcal range, and quick add.
- Capture: photo estimate, verified scan placeholder, manual entry, repeat.
- AI Draft: dish label, portion range, kcal range, confidence, assumptions.
- Assumptions Editor: chips and toggles for portion, ingredients, cooking style.
- Confirm: final summary and `Save to MealMark`.
- History: confirmed meals by day with estimated/measured/verified filters.
- Wallet: local-first status, export, privacy, subscriptions, developer proof.

## AI And Nutrition

OpenAI and nutrition-provider keys must not be embedded in the iOS app. The app
owns UI, local state, photo lifecycle, and confirmation UX. A future
FoodAnalysisBroker owns OpenAI Responses calls, nutrition provider lookups,
caching, abuse controls, and no-photo-retention enforcement.

For simple items, such as an apple, the result can be tight:

- label: Fuji apple
- portion: about 170 g
- kcal: 90-115
- confidence: medium or high

For mixed dishes, such as restaurant risotto, the app must return a range and
assumptions:

- label: mushroom risotto
- portion: about 320 g
- kcal: 520-760
- assumptions: rice base, butter or oil, cheese, mushrooms, no visible meat
- confidence: medium-low

Nutrition resolution is layered:

1. Curated dish cache for common meals and aliases.
2. Open Food Facts for packaged and barcode foods.
3. USDA FoodData Central for generic foods and prepared-food references.
4. Model-only fallback with wide ranges and required user review.

## Privacy

The default product promise is no raw photo retention.

- Strip image metadata before remote analysis.
- Do not store raw photos in local database, logs, analytics, exports, or safe
  summaries.
- Store only structured estimate fields, provider evidence, user corrections,
  and confirmed food entries.
- Show explicit consent before third-party AI analysis.
- Keep App Store privacy labels conservative if any food/photo data leaves the
  device.

## Monetization

Use StoreKit 2 subscriptions for premium ongoing digital value. Free features
include manual logging, local history, basic photo drafts, verified scan demo,
and user-owned export. Pro features may include higher photo-estimate limits,
advanced mixed-dish analysis, weekly insights, encrypted sync, and backup.

Do not paywall ownership of user data or basic export.

## App Intents

Expose a small first App Intents surface:

- Open MealMark to a destination.
- Start Food Capture.
- Log a recent quick food estimate.

These intents should be thin and route into app workflows rather than mirroring
the entire app navigation tree.

## Validation

The first implementation must provide:

- Swift package build and tests.
- Food analysis fixtures for apple and risotto.
- Smoke test for photo draft to confirmed MealMark entry.
- Guard checks for no raw protocol/private material in safe summaries.
- App Intents compilation.
- Documentation for App Store privacy and subscription posture.
