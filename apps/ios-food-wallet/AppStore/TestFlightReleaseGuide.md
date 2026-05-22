# MealMark TestFlight And Archive Guide

This guide is the release lane for the first MealMark TestFlight build. It keeps
signing, archive, privacy, and App Review evidence separate from core app logic.

## Release Inputs

- App name: MealMark
- Bundle ID: `dev.grain.foodwallet`
- Version: `0.1.0`
- Build: increment `CURRENT_PROJECT_VERSION` for every App Store Connect upload.
- Xcode project source: `project.yml`
- Generated project: `FoodWallet.xcodeproj`
- StoreKit local config: `AppStore/MealMark.storekit`
- Privacy manifest: `AppStore/PrivacyInfo.xcprivacy`
- Review notes draft: `AppStore/AppReviewNotes.md`
- Privacy answers draft: `AppStore/AppPrivacyAnswers.md`
- Staging backend: Cloudflare Worker with D1 account/session/entitlement state
  and App Store Server API transaction verification.

## App Store Connect Setup

1. Confirm the Apple Developer team owns `dev.grain.foodwallet`.
2. Create the iOS app record before uploading the first archive.
3. Enter the privacy policy URL from the hosted version of `PrivacyPolicy.md`.
4. Answer App Privacy from `AppPrivacyAnswers.md` for the exact build being
   submitted.
5. Create the `MealMark Plus` subscription group before inviting testers to a
   build with visible purchase buttons.
6. Create products with these IDs:
   - `dev.grain.foodwallet.plus.monthly`
   - `dev.grain.foodwallet.plus.yearly`
7. Keep local `MealMark.storekit` prices and names aligned with the App Store
   Connect products after the products exist.

## Backend Setup

The TestFlight broker must run over HTTPS and use session auth. Apply all D1
migrations, then set Cloudflare secrets for:

- `MEALMARK_SESSION_HMAC_SECRET`
- `OPENAI_API_KEY`
- `FOODDATA_CENTRAL_API_KEY`
- `APP_STORE_BUNDLE_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_PRIVATE_KEY_P8`
- `APP_STORE_SERVER_ENVIRONMENT` (`Sandbox` for TestFlight)

The broker verifies StoreKit transactions by calling Apple's App Store Server
API and then binding the result to the StoreKit `appAccountToken` created by the
app. Do not invite external testers until a sandbox purchase activates MealMark
Plus on the staging broker.

## Local StoreKit

`MealMark.storekit` is for Xcode local testing only. It lets the Plus screen load
the same product IDs without App Store Connect or sandbox setup.

After regenerating the project, XcodeGen wires the `FoodWallet` scheme Run action
to `AppStore/MealMark.storekit`. App Store/TestFlight archives still use App
Store Connect product data, not the local test file.

Regenerate the project:

```sh
cd apps/ios-food-wallet
xcodegen generate
```

## Pre-Archive Checks

Run from the repository root:

```sh
python3 tools/ci/check_ios_food_wallet_app_store.py
scripts/sdk/check_ios_food_wallet_app.sh
scripts/sdk/check_food_analysis_broker_staging.sh --require-cloudflare
git diff --check
```

Then generate and inspect the Xcode project:

```sh
cd apps/ios-food-wallet
xcodegen generate
```

Open `FoodWallet.xcodeproj` and confirm:

- the `FoodWallet` scheme exists;
- Run uses `AppStore/MealMark.storekit`;
- Archive uses Release;
- signing uses the App Store distribution team;
- bundle ID is `dev.grain.foodwallet`;
- no local broker token is embedded in the app bundle.

## Archive

Use the repository-owned archive script before any Organizer upload. It fails
early if the build is missing a public HTTPS broker URL, has a broker dev token,
or is not signed by an App Store distribution identity.

```sh
GRAIN_IOS_DISTRIBUTION_TEAM="$APPLE_TEAM_ID" \
GRAIN_IOS_BUILD_NUMBER="$NEXT_APP_STORE_CONNECT_BUILD" \
GRAIN_FOOD_ANALYSIS_BROKER_URL="https://mealmark-food-analysis-broker-staging.ivan-f7b.workers.dev" \
scripts/sdk/archive_ios_food_wallet_testflight.sh
```

The script runs `xcodegen generate`, selected local checks, `xcodebuild archive`,
and:

```sh
python3 tools/ci/check_ios_food_wallet_testflight_archive.py artifacts/ios-food-wallet/MealMark.xcarchive
```

Do not pass `GRAIN_FOOD_BROKER_DEV_TOKEN` or a local `http://` broker URL into an
archive meant for TestFlight or App Store review.

For a local `.ipa` export after a checked archive:

```sh
GRAIN_IOS_DISTRIBUTION_TEAM="$APPLE_TEAM_ID" \
scripts/sdk/export_ios_food_wallet_testflight.sh
```

For command-line App Store Connect upload, also set the App Store Connect API key
environment variables documented by the script and use:

```sh
GRAIN_IOS_EXPORT_DESTINATION=upload \
GRAIN_IOS_DISTRIBUTION_TEAM="$APPLE_TEAM_ID" \
scripts/sdk/export_ios_food_wallet_testflight.sh
```

Use Xcode Organizer for the first upload so signing, capabilities, export
compliance, and App Store Connect processing are visible to the release owner.

## TestFlight Review

Before external TestFlight:

- upload one archive and wait for App Store Connect processing;
- attach the notes from `AppReviewNotes.md`;
- verify the app opens without an account;
- verify manual Add Food, history, wallet export, and Plus restore/manage UI;
- open Shortcuts, confirm MealMark exposes only truthful release shortcuts, and
  run each shortcut once;
- verify a sandbox StoreKit purchase syncs to the broker and survives app
  restart through `/v1/account/me`;
- verify account deletion revokes the current broker session;
- if photo or barcode analysis is enabled, verify the staging broker is reachable
  over HTTPS and the review notes explain the flow;
- verify no raw photos appear in logs, exports, safe summaries, or support files;
- verify the privacy answers match the exact remote-analysis behavior in the
  submitted build.

## Release Blockers

Do not submit the build if any of these are true:

- the App Store Connect privacy answers describe a different data flow than the
  binary;
- Plus products are visible but restore/manage subscription controls are missing;
- StoreKit products are visible but the staging broker cannot verify App Store
  Server API transactions;
- remote photo analysis runs without explicit consent;
- raw photos are retained in app storage, exports, logs, or support material;
- a local broker token, provider key, or private URL is embedded in the app;
- the archive was not built from a freshly generated project.
