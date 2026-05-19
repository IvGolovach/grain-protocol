# App Privacy Answers Draft

This draft is conservative for the first Food Wallet app surface. Update it
before App Store submission if production analytics, sync, crash reporting,
accounts, or third-party SDKs are added.

## Current App Surface

- Tracking: no.
- Ads: no.
- Account required: no.
- Raw photo retention: no.
- Local food history: yes, stored on device.
- Third-party AI photo analysis: planned through a backend broker, only after
  explicit user consent. The app sends the selected photo to the broker as
  transient request data; the app does not store the raw photo and the broker
  should not retain it.
- Provider keys in app: no. OpenAI, USDA/data.gov, and other provider keys stay
  server-side.
- Payment: StoreKit subscription planned for Pro features.

## Data Types

If the app ships exactly as the current local-first mock build:

- User content collected by developer: no.
- Photos or videos collected by developer: no.
- Health and fitness data collected by developer: no.
- Purchase history: handled by Apple StoreKit when subscriptions are enabled.

If the production broker sends a user-selected meal photo to OpenAI or another
AI provider:

- Disclose photo transfer according to the provider retention and processing
  terms.
- Disclose derived nutrition or food-log data if it leaves the device.
- Disclose that remote analysis uses backend processing and does not retain raw
  photos unless the production behavior changes.
- Keep the App Store privacy label consistent with the production backend, not
  the mock build.

## Promises That Must Stay True

- No raw meal photos in safe summaries.
- No raw meal photos in exports.
- No raw meal photos in support bundles.
- No advertising use of photos, nutrition records, or food history.
- No medical, diagnosis, treatment, or guaranteed-accuracy claims.
