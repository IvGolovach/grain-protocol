# Food Wallet Privacy Policy Draft

Food Wallet helps you create a private food history. The app is designed so AI
can help create drafts, while you decide what becomes a saved record.

## Local Food Records

Confirmed food entries are stored locally by default. A confirmed entry can
include food name, estimated calories, portion size, source class, trust label,
and confirmation time.

## Photos

Meal photos are used to create food estimate drafts. Food Wallet does not store raw meal photos by default.
Photos are not included in safe summaries, exports, or protocol proof views.
If you choose remote analysis, the app sends the selected photo to the Food
Wallet backend broker for that analysis request. The photo is treated as
transient request data and is not retained by Food Wallet after the estimate is
created.

## AI Analysis

Production photo analysis will use a backend broker before calling an AI
provider such as OpenAI. The app must ask for consent before sending a selected
photo for analysis. The broker should strip metadata, avoid request-body logs,
keep provider keys out of the app, use nutrition sources such as USDA FoodData
Central only from the backend, and discard image bytes after the analysis
request completes.

## Subscriptions

Food Wallet Pro may use Apple StoreKit subscriptions. Apple processes payments
and subscription management. Food Wallet should use entitlement status only to
unlock Pro features.

## Export

Exports should contain safe food summaries and confirmed records. Exports must
not contain raw photos, raw protocol payloads, private keys, snapshots, trust
bundles, or hidden AI request data.

## Accounts

The first version does not require a Food Wallet account. If account sync is
added later, the app must provide in-app account deletion and delete associated
account data unless retention is legally required.

## No Medical Claims

Food Wallet estimates food and nutrition for personal tracking. It does not
provide medical advice, diagnosis, treatment, or guaranteed nutrition accuracy.
