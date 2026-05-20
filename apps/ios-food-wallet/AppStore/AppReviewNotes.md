# App Review Notes Draft

MealMark is a food logging app. It creates estimated food drafts from user
actions and saves only user-confirmed records.

## What To Test

1. Open the app.
2. Tap Today, then Add food.
3. Create a manual food draft, or use Photo/Barcode when the broker is configured.
4. Review the draft and save it to MealMark.
5. Open History and Wallet to see confirmed records, edit/delete behavior, exports, and safe-summary language.
6. Open Pro to see the subscription posture.

## AI And Photos

The current build uses deterministic mock analysis. In production, photo
analysis will be user-initiated and will require explicit consent before a
selected image is sent to a backend broker and AI provider.

MealMark does not retain raw meal photos by default. It stores only derived
food estimate fields and user-confirmed MealMark records.

## Subscription

Planned StoreKit product IDs:

- `dev.grain.foodwallet.plus.monthly`
- `dev.grain.foodwallet.plus.yearly`

The app must provide restore/manage subscription controls before App Store
submission with live products.

## Medical Disclaimer

MealMark provides food estimates for personal tracking. It is not medical advice,
diagnosis, treatment, or a medical nutrition device.

## Review Notes

Deterministic food fixtures are diagnostics-only and are not exposed as normal
user flows. Production StoreKit products are separate release-lane work.
