# App Review Notes Draft

Food Wallet is a food logging app. It creates estimated food drafts from user
actions and saves only user-confirmed records.

## What To Test

1. Open the app.
2. Tap Capture.
3. Analyze the Fuji apple sample.
4. Save the draft to Food Wallet.
5. Analyze the mushroom risotto sample.
6. Review assumptions and save.
7. Open History and Wallet to see confirmed records and safe-summary language.
8. Open Pro to see the subscription posture.

## AI And Photos

The current build uses deterministic mock analysis. In production, photo
analysis will be user-initiated and will require explicit consent before a
selected image is sent to a backend broker and AI provider.

Food Wallet does not retain raw meal photos by default. It stores only derived
food estimate fields and user-confirmed Food Wallet records.

## Subscription

Planned StoreKit product IDs:

- `dev.grain.foodwallet.plus.monthly`
- `dev.grain.foodwallet.plus.yearly`

The app must provide restore/manage subscription controls before App Store
submission with live products.

## Medical Disclaimer

Food Wallet provides food estimates for personal tracking. It is not medical advice,
diagnosis, treatment, or a medical nutrition device.

## Demo Notes

The first app build includes sample apple and risotto analysis flows. Verified
QR/code demo and production StoreKit products are separate release-lane work.
