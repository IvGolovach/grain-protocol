# MealMark iOS App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a working SwiftUI MealMark app surface that turns mock photo analysis into user-confirmed Grain Food Wallet records.

**Architecture:** The first app is a Swift package in `apps/ios-food-wallet`. `FoodWalletCore` owns analysis models, local app state, Grain Food Wallet integration, privacy, and subscription state. `FoodWalletApp` owns SwiftUI screens. `FoodWalletAppIntents` exposes a narrow Shortcuts/Siri surface.

**Tech Stack:** Swift 6 package, SwiftUI, Combine, AppIntents, StoreKit-shaped entitlement stubs, Grain `sdk/swift` `GrainFoodWallet`.

---

### Task 1: App Package And Core Domain

**Files:**
- Create: `apps/ios-food-wallet/Package.swift`
- Create: `apps/ios-food-wallet/Sources/FoodWalletCore/FoodAnalysis.swift`
- Create: `apps/ios-food-wallet/Sources/FoodWalletCore/FoodWalletStore.swift`
- Create: `apps/ios-food-wallet/Sources/FoodWalletCore/PrivacyAndSubscription.swift`
- Test harness: `apps/ios-food-wallet/Tests/FoodWalletCoreTests/FoodWalletCoreTests.swift`

- [ ] Add a Swift package with app, core, intents, smoke, and tests.
- [ ] Add analysis models for apple and mixed-dish risotto estimates.
- [ ] Add a mock analysis client that returns deterministic candidates.
- [ ] Add `FoodWalletStore` that creates Grain drafts and confirms entries.
- [ ] Run `swift run --package-path apps/ios-food-wallet FoodWalletCoreTests`.

### Task 2: SwiftUI App Screens

**Files:**
- Create: `apps/ios-food-wallet/Sources/FoodWalletApp/FoodWalletApp.swift`
- Create: `apps/ios-food-wallet/Sources/FoodWalletApp/Views.swift`

- [ ] Add Today, Capture, Draft, History, Wallet, and Pro tabs.
- [ ] Add photo estimate buttons for Fuji apple and mushroom risotto.
- [ ] Add assumptions editor with simple toggles and portion controls.
- [ ] Add confirmation flow that saves to MealMark.
- [ ] Run `swift build --package-path apps/ios-food-wallet`.

### Task 3: App Intents

**Files:**
- Create: `apps/ios-food-wallet/Sources/FoodWalletAppIntents/FoodWalletIntents.swift`

- [ ] Add destination enum for Today, Capture, History, Wallet.
- [ ] Add `OpenFoodWalletIntent`.
- [ ] Add `StartFoodCaptureIntent`.
- [ ] Add a small `AppShortcutsProvider`.
- [ ] Ensure package builds with AppIntents imported.

### Task 4: Smoke, Policy, And SDK Verification Hook

**Files:**
- Create: `apps/ios-food-wallet/Sources/FoodWalletSmoke/main.swift`
- Create: `scripts/sdk/check_ios_food_wallet_app.sh`
- Modify: `scripts/sdk/verify_all_sdks.sh`

- [ ] Add smoke test for risotto analysis to confirmed entry.
- [ ] Add policy checks that reject raw protocol/private material and raw photo retention in app safe summaries.
- [ ] Add the new check to `verify_all_sdks.sh` when Swift is available.
- [ ] Run `scripts/sdk/check_ios_food_wallet_app.sh`.

### Task 5: App Store Readiness Notes

**Files:**
- Create: `apps/ios-food-wallet/README.md`

- [ ] Document no-photo-retention, AI broker boundary, StoreKit subscription posture, App Review notes, and TestFlight checklist.
- [ ] Keep the README clear that this first PR is a working app surface, not final App Store signing/release automation.

### Self-Review

- Spec coverage: package, core, UI, App Intents, AI estimate fixtures, privacy, subscription posture, and verification are covered.
- Placeholder scan: no placeholder tasks remain.
- Scope check: backend broker and production StoreKit/App Store Connect setup are intentionally later; this plan builds the local runnable app surface first.
