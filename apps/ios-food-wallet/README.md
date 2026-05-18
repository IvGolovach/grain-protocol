# Grain Food Wallet iOS App

This is the first first-party iOS app surface for the Grain Food Wallet
contract. It is intentionally product-shaped rather than a protocol demo.

The current build is a Swift package app surface with:

- SwiftUI Today, Capture, History, Wallet, and Pro tabs;
- deterministic mock photo analysis for a Fuji apple and mushroom risotto;
- editable assumptions before confirmation;
- `GrainFoodWallet` draft and confirmation flow;
- safe summary checks;
- App Intents for opening capture, today, and quick logging;
- subscription and privacy state stubs for the later StoreKit/App Store lane.

## Product Loop

```text
photo or sample capture
-> food analysis candidate
-> editable assumptions
-> user-confirmed draft
-> Food Wallet entry
-> safe summary
```

AI estimates are never written directly into the wallet. The app records only
what the user confirms.

## Privacy Boundary

The product promise is no raw photo retention by default.

- The iOS app must not store raw photos in local state, logs, safe summaries,
  exports, or support bundles.
- A future FoodAnalysisBroker must strip metadata, avoid request-body logging,
  keep image bytes in memory only for the provider request, and return
  structured estimate candidates.
- Safe summaries must not include raw photos, snapshots, QR payloads, trust
  material, private keys, COSE, CBOR, or GR1 payloads.

## OpenAI Boundary

OpenAI API keys must not be embedded in the iOS app. The production path is a
backend broker:

```text
iOS image bytes
-> FoodAnalysisBroker
-> OpenAI Responses image input with structured output
-> nutrition resolver
-> FoodAnalysisCandidate
```

The app can run without that broker today using `MockFoodAnalysisClient`.

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
- verified scan demo;
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
- review notes with sample QR/demo mode;
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
