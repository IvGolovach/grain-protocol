# Grain Android Food Wallet Starter

This starter shows the app-owned boundary for a local Food Wallet flow:

1. App code owns camera, barcode/photo capture, UI state, Android storage, and account/session policy.
2. App code maps an approved local signal into `dev.grain.food.FoodEstimate`.
3. Grain Kotlin owns the small Food Wallet facade: estimate, draft, confirm, daily totals, and safe summary.
4. UI reads `FoodSafeSummary` or `FoodDailyTotals`; it does not receive raw photos, snapshots, trust keys, private keys, or backend account state.

The starter intentionally has no backend, account setup, raw photo persistence, or platform key management. It is starter material for app teams that want to keep Android-specific choices outside Grain while using the Kotlin Food Wallet contract.

## Facade

Use the Kotlin package:

```kotlin
import dev.grain.food.FoodEstimate
import dev.grain.food.FoodNutritionConfidence
import dev.grain.food.FoodRecordTrust
import dev.grain.food.FoodSourceClass
import dev.grain.food.FoodWallet
```

The app can create a deterministic local flow:

```kotlin
val wallet = FoodWallet()
val estimate = FoodEstimate(
    label = "breakfast bowl",
    meanKcal = 620,
    varianceKcal = 9,
    amountGrams = 250,
    servingGrams = 250,
    servings = 1,
    sourceClass = FoodSourceClass.Estimated,
    recordTrust = FoodRecordTrust.Untrusted,
    nutritionConfidence = FoodNutritionConfidence.Estimated,
)
val draft = wallet.createDraft(estimate, dayKey = "2026-05-17", createdAtMillis = nowMillis)
wallet.confirm(draft, confirmedAtMillis = nowMillis)
val safeSummary = wallet.safeSummary("2026-05-17")
```

## Check

```bash
sdk/kotlin/gradlew -p templates/android-food-wallet-starter check
```
