# MealMark Privacy Policy Draft

MealMark helps you create a private food history. The app is designed so AI
can help create drafts, while you decide what becomes a saved record.

## Local Food Records

Confirmed food entries are stored locally by default. A confirmed entry can
include food name, estimated calories, portion size, source class, trust label,
and confirmation time.

## Photos

Meal photos are used to create food estimate drafts. MealMark does not store raw meal photos by default.
Photos are not included in safe summaries, exports, or protocol proof views.
If you choose remote analysis, the app sends the selected photo to the Food
Wallet backend broker for that analysis request. The photo is treated as
transient request data and is not retained by MealMark after the estimate is
created.

## AI Analysis

Production photo analysis will use a backend broker before calling an AI
provider such as OpenAI. The app must ask for consent before sending a selected
photo for analysis. The broker should strip metadata, avoid request-body logs,
keep provider keys out of the app, use nutrition sources such as USDA FoodData
Central only from the backend, and discard image bytes after the analysis
request completes.

If a submitted build does not include a configured remote analysis broker, the
photo analysis path is unavailable and selected photos do not leave the device.
If a submitted build enables remote analysis, the App Store privacy answers must
disclose the exact remote data flow for selected photos, typed food content, and
derived nutrition data that leaves the device.

## Subscriptions

MealMark Plus uses Apple StoreKit subscriptions. Apple processes payments and
subscription management. MealMark sends the Apple signed transaction identifier
to the MealMark backend so the backend can verify the purchase with Apple's App
Store Server API and unlock the server-side entitlement for that MealMark
account.

MealMark does not receive card numbers or Apple ID credentials. It stores only
the account entitlement state and minimal StoreKit transaction identifiers
needed to unlock and restore MealMark Plus.

## Export

Exports should contain safe food summaries and confirmed records. Exports must
not contain raw photos, raw protocol payloads, private keys, snapshots, trust
bundles, or hidden AI request data.

## Accounts

MealMark creates a lightweight app account for server-side analysis quotas and
MealMark Plus entitlement sync. The account is not a password login and does not
require an email address. The app provides in-app cloud account deletion, which
revokes active sessions and marks the server account deleted unless retention is
legally required.

## App Privacy Updates

The published privacy policy URL and App Store Connect App Privacy answers must
match the exact submitted binary. Add new disclosures before shipping analytics,
crash reporting, account sync, cloud backup, remote photo analysis, support-log
upload, or third-party SDK collection.

## No Medical Claims

MealMark estimates food and nutrition for personal tracking. It does not
provide medical advice, diagnosis, treatment, or guaranteed nutrition accuracy.
