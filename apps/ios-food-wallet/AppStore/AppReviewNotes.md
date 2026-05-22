# App Review Notes Draft

MealMark is a food logging app. It creates estimated food drafts from user
actions and saves only user-confirmed records.

## Build Access

- Account required: no.
- Login credentials: not applicable.
- Network requirement: manual logging, history, wallet, export, and Plus screens
  open without an account.
- AI/photo analysis: only available when the submitted build is configured with
  an HTTPS analysis broker and the user grants in-app consent. If the review
  build does not include that broker configuration, photo analysis shows a
  clear disabled/unavailable state rather than sending data.
- Payments: MealMark Plus uses StoreKit 2 subscriptions. The app includes
  purchase, restore, manage subscription, and cloud account deletion controls.
  TestFlight builds require matching App Store Connect products and a staging
  broker configured for App Store Server API verification.

## What To Test

1. Open the app.
2. Tap Today, then Add Food.
3. Create a manual food draft from typed food or ingredient-built meal input.
4. Review the draft, adjust the serving if needed, and save it to MealMark.
5. Open History to confirm the saved record appears and can be edited or deleted.
6. Open Wallet to inspect safe-summary language and export flows.
7. Open Plus to see the subscription posture and restore/manage subscription
   entry points.
8. If the build is configured with the review broker, grant AI photo consent,
   capture or choose a meal photo, review the draft, and save only after user
   confirmation.
9. If barcode analysis is enabled, scan a packaged-food barcode or MealMark QR,
   review the returned draft, and save only after user confirmation.

## AI And Photos

The app does not write AI output directly into the wallet. Photo analysis is
user-initiated and requires explicit consent before a selected image is sent to
the backend broker and AI provider.

MealMark does not retain raw meal photos by default. It stores only derived
food estimate fields and user-confirmed MealMark records.

If the review build is not configured with an HTTPS broker and session auth,
photo and barcode remote analysis is intentionally unavailable. The rest of the
food logging flow remains testable through manual entry and deterministic local
review states.

## Data And Privacy Notes

- Raw meal photos are not stored by MealMark.
- Raw photos are not included in exports, safe summaries, or support bundles.
- OpenAI, USDA/data.gov, and nutrition-provider keys are not embedded in the app.
- Local food history stays on device. The backend stores account/session,
  entitlement, usage, and minimal StoreKit transaction metadata for analysis
  quotas and MealMark Plus activation.
- App Store Connect App Privacy answers must match the exact submitted build.

## Subscription

StoreKit product IDs:

- `dev.grain.foodwallet.plus.monthly`
- `dev.grain.foodwallet.plus.yearly`

Local development uses `MealMark.storekit`. TestFlight and App Store builds load
real App Store Connect products, purchase with a StoreKit app account token, and
sync the signed transaction to the backend for server-side entitlement
verification.

## Medical Disclaimer

MealMark provides food estimates for personal tracking. It is not medical advice,
diagnosis, treatment, or a medical nutrition device.

## Review Notes

Deterministic food fixtures are diagnostics-only and are not exposed as normal
user flows. Live StoreKit products and the staging broker must both be configured
before inviting external testers.
