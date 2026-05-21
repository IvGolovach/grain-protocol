# App Privacy Answers Draft

This draft is conservative for the first MealMark app surface. Update it
before App Store submission if production analytics, sync, crash reporting,
third-party SDKs, or new account fields are added.

## Current App Surface

- Tracking: no.
- Ads: no.
- Account required: no user-created login; the app creates a lightweight server
  account for quotas and subscription entitlement sync.
- Raw photo retention: no.
- Local food history: yes, stored on device.
- Third-party AI photo analysis: planned through a backend broker, only after
  explicit user consent. The app sends the selected photo to the broker as
  transient request data; the app does not store the raw photo and the broker
  should not retain it.
- Provider keys in app: no. OpenAI, USDA/data.gov, and other provider keys stay
  server-side.
- Payment: StoreKit subscription for MealMark Plus. The backend stores minimal
  transaction identifiers and entitlement state after Apple verification.

## App Store Connect Answer For Current Local-First Build

If the app ships exactly as the current local-first mock build:

- Data collection: No, we do not collect data from this app.
- User content collected by developer: no.
- Photos or Videos collected by developer: no.
- Health & Fitness data collected by developer: no.
- Other User Content collected by developer: no.
- Purchase history: handled by Apple StoreKit when subscriptions are enabled.
- Tracking: no.

This answer is not valid for a TestFlight/App Store build that uses the
production broker account, usage, remote analysis, or StoreKit entitlement sync.

## If Remote Analysis Ships

If the submitted build sends a user-selected meal photo to the MealMark backend
broker, OpenAI, or another provider, answer "Yes, we collect data from this app"
and disclose the remote-analysis data flow for the exact binary.

Recommended draft classifications for that build:

- Photos or Videos: collected for App Functionality, not used for tracking, not
  linked to identity if the broker does not associate the request with an
  account, advertising identifier, or other identity.
- Health & Fitness: disclose if derived nutrition records, calories, food logs,
  macros, or similar health/fitness-style records leave the device.
- Other User Content: disclose if typed free-form food descriptions,
  ingredients, recipes, notes, or support text leave the device.
- Diagnostics: disclose if crash reports, performance data, or support logs are
  collected by MealMark or a third-party SDK.
- Purchases: StoreKit purchase history is processed by Apple. Disclose purchase
  data only if MealMark or a third-party service also collects entitlement,
  receipt, transaction, or account-level purchase data.
- Identifiers: disclose account identifiers if App Store Connect classifies the
  generated MealMark account ID or StoreKit app account token as collected
  identifiers for the submitted build.

For remote photo analysis, state in App Review notes that raw photos are
transient request data, not retained by MealMark, not used for advertising, and
not included in exports, safe summaries, support bundles, or logs.

Keep the App Store privacy label consistent with the production backend, not the
mock build.

## Promises That Must Stay True

- No raw meal photos in safe summaries.
- No raw meal photos in exports.
- No raw meal photos in support bundles.
- No advertising use of photos, nutrition records, or food history.
- No medical, diagnosis, treatment, or guaranteed-accuracy claims.
- No provider keys, bearer tokens, private URLs, or local broker credentials in
  the iOS app bundle.
