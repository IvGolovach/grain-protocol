# MealMark iOS App

This is the first first-party iOS app surface built on the Grain Food Wallet
contract. It is intentionally product-shaped rather than a protocol demo, and
the consumer-facing app name is MealMark.

The current build is a Swift package app surface with:

- SwiftUI Today, Capture, History, Wallet, and Pro tabs;
- real iPhone camera capture with transient in-memory photo analysis input;
- deterministic mock analysis fixtures for local tests and device smoke;
- calorie, portion, and macro estimates before confirmation;
- numeric portion review before confirmation;
- edit/delete gestures for confirmed meals;
- `GrainFoodWallet` draft and confirmation flow;
- safe summary checks;
- App Intents for opening capture, today, and quick logging;
- subscription and privacy state stubs for the later StoreKit/App Store lane.

## Product Loop

```text
camera photo, barcode, ingredient-built meal, or typed food
-> food analysis candidate
-> reviewable draft
-> user-confirmed draft
-> MealMark entry
-> safe summary
```

AI estimates are never written directly into the wallet. The app records only
what the user confirms.

## Privacy Boundary

The product promise is no raw photo retention by default.

- The iOS app must not store raw photos in local state, logs, safe summaries,
  exports, or support bundles.
- The FoodAnalysisBroker strips the app-facing contract down to structured
  estimates, avoids request-body logging, keeps image bytes in memory only for
  the provider request, and returns structured estimate candidates.
- Safe summaries must not include raw photos, snapshots, QR payloads, trust
  material, private keys, COSE, CBOR, or GR1 payloads.

## OpenAI Boundary

OpenAI API keys must not be embedded in the iOS app. The production path is a
backend broker:

```text
iOS transient meal photo
-> FoodAnalysisBroker
-> OpenAI Responses image input with structured output, if configured
-> USDA FoodData Central nutrition resolver, if configured
-> FoodAnalysisCandidate
```

The iOS app sends a selected photo only to the broker, over the app's backend
contract. Raw image bytes are transient request material: the app must not
persist them, the broker must not store them, and neither side should log request
bodies, base64 image payloads, or provider responses that include image bytes.

All OpenAI, USDA, and commercial nutrition-provider credentials live on the
broker. The app must not call `api.openai.com` directly, ship `OPENAI_API_KEY`,
ship USDA/data.gov keys, or read provider keys from the iOS bundle.

Deterministic mocks are reserved for tests and smoke runs. Device verification
for a live flow should point the app at a non-production broker with test
provider credentials, capture one meal photo, confirm that the result requires
user review, and then verify logs/storage contain no raw image bytes.

## Live API Setup

The iOS app can keep using mocks for deterministic local and CI runs. Configure
live providers on the broker, not in the app:

- OpenAI Responses API: create an OpenAI API key and use vision input with
  Structured Outputs to produce the `FoodAnalysisCandidate` schema.
- USDA FoodData Central: create a data.gov API key for generic food and
  prepared-food nutrition lookup.
- Open Food Facts: enabled by default for public packaged-food barcode reads
  with a clear application `User-Agent`; account/auth is only needed for
  contribution flows.
- Optional commercial providers: Edamam, Nutritionix, FatSecret, LogMeal,
  Passio, or Spoonacular can improve packaged, restaurant, barcode, recipe, or
  food-image coverage. Keep their keys server-side and gate each provider by
  environment configuration.

The broker returns structured estimates with calorie range, portion range,
macros, assumptions, evidence, confidence, and a mandatory confirmation flag. If
no keyed provider is configured, public Open Food Facts barcode lookup and
deterministic local development fixtures still require user confirmation.

Run the broker guard after touching the backend service:

```sh
scripts/sdk/check_food_analysis_broker.sh
```

The guard does not require provider accounts; live credentials stay in the local
environment or a deployment secret manager.

For local iPhone testing, start the broker on the LAN with public barcode lookup
enabled and optional Keychain-backed OpenAI/USDA credentials:

```sh
scripts/sdk/run_food_analysis_broker_local.sh
```

## Nutrition Resolver Plan

Simple foods use a tight estimate. Mixed dishes use ranges and visible
assumptions.

Resolution order for the broker:

1. curated dish cache;
2. Open Food Facts for packaged or barcode foods;
3. USDA FoodData Central for generic foods and prepared-food references;
4. model-only fallback with a wide range and required confirmation.

## Subscription Posture

The app should use StoreKit 2 subscriptions for premium ongoing digital value.

Free:

- manual logging;
- basic photo drafts;
- local history;
- verified scan proof;
- basic export.

Pro:

- higher photo-estimate limits;
- advanced mixed-dish analysis;
- weekly insights;
- future encrypted sync and backup.

Do not paywall ownership of user data or basic export.

## App Store Notes

Before TestFlight/App Store submission, add:

- Xcode project or workspace release lane;
- signing, bundle id, entitlements, and privacy strings;
- StoreKit products and sandbox verification;
- privacy policy URL and App Privacy details;
- review notes for real user flows and diagnostics-only fixture behavior;
- explicit AI/photo consent copy;
- no medical claims.

This package is the working app surface that future App Store packaging should
wrap, not the final signed release artifact.

Draft App Store artifacts live in `AppStore/`:

- `Info.plist`
- `PrivacyInfo.xcprivacy`
- `AppPrivacyAnswers.md`
- `AppReviewNotes.md`
- `PrivacyPolicy.md`
- `StoreKitProducts.md`

## Real iPhone Run

The package build proves the Swift app code. A physical iPhone needs a signed
`.app` bundle, so the repo includes an XcodeGen project definition for local
device runs:

```sh
scripts/sdk/run_ios_food_wallet_device.sh
```

The script detects the first connected developer-mode iPhone, detects the first
local Apple Development team, generates `FoodWallet.xcodeproj`, builds and
installs `FoodWallet.app` with the MealMark display name, runs
`--grain-device-smoke`, and then launches the app normally.

Useful overrides:

```sh
GRAIN_IOS_DEVICE_ID=<device-id> \
GRAIN_IOS_DEVELOPMENT_TEAM=<team-id> \
GRAIN_IOS_BUNDLE_ID=dev.grain.foodwallet \
GRAIN_FOOD_ANALYSIS_BROKER_URL=http://<mac-lan-ip>:8788 \
scripts/sdk/run_ios_food_wallet_device.sh
```
