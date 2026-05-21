# StoreKit Products Draft

Use these product identifiers for local StoreKit configuration and App Store
Connect setup when the subscription lane is implemented:

- Monthly: `dev.grain.foodwallet.plus.monthly`
- Yearly: `dev.grain.foodwallet.plus.yearly`

Subscription group:

- `MealMark Plus`

Local Xcode configuration:

- `MealMark.storekit`
- Subscription group ID: `MMPLUS01`
- Monthly local product reference: `MealMark Plus Monthly`
- Yearly local product reference: `MealMark Plus Yearly`
- Monthly period: `P1M`
- Yearly period: `P1Y`
- Local prices are placeholders for testing. App Store Connect is the source of
  truth for real storefront pricing, tax category, availability, and localized
  subscription metadata.

Free features:

- manual logging;
- basic photo drafts;
- local history;
- verified scan proof;
- basic export.

Plus features:

- higher photo-estimate limits;
- advanced mixed-dish analysis;
- weekly insights;
- future encrypted sync and backup.

Before submission:

- load StoreKit products from App Store Connect;
- show real localized price and term;
- provide restore purchases;
- provide manage subscription entry point;
- configure App Store Server API credentials on the broker;
- verify a sandbox/TestFlight purchase updates `/v1/account/me` to a `pro`
  entitlement;
- include subscription review notes;
- confirm the paid apps agreement, banking, tax, product availability, and
  subscription group are complete in App Store Connect;
- verify sandbox/TestFlight subscriptions after App Store Connect products
  exist;
- keep the local `.storekit` file selected only for Xcode Run testing. Archive
  and TestFlight builds must use App Store Connect product data.

Release blocker:

- Do not submit a build with visible Plus purchase buttons until restore
  purchases, manage subscription controls, broker verification, and App Store
  Connect products are implemented and verified.
