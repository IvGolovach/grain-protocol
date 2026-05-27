package dev.grain.templates.androidfoodwallet

import dev.grain.food.FoodNutritionConfidence
import dev.grain.food.FoodRecordTrust
import dev.grain.food.FoodSourceClass

fun main() {
    val starter = AndroidFoodWalletStarter()
    val estimate = starter.estimateFromAppSignal(
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

    val draft = starter.draft(
        estimate = estimate,
        dayKey = "2026-05-17",
        createdAtMillis = 1_779_000_000_000,
    )
    val entry = starter.confirm(
        draft = draft,
        confirmedAtMillis = 1_779_000_060_000,
    )
    val summary = starter.safeSummary("2026-05-17")

    requireStarter(entry.entryId == "food-entry-2026-05-17-0001", "entry id mismatch")
    requireStarter(summary.entryCount == 1, "summary count mismatch")
    requireStarter(summary.sumMeanKcal == 620L, "summary mean mismatch")
    requireStarter(summary.sourceClasses == setOf(FoodSourceClass.Estimated), "summary source mismatch")
    requireStarter(summary.recordTrusts == setOf(FoodRecordTrust.Untrusted), "summary trust mismatch")
    requireStarter(
        summary.nutritionConfidences == setOf(FoodNutritionConfidence.Estimated),
        "summary confidence mismatch",
    )
    requireStarter(!summary.toString().contains("photo", ignoreCase = true), "summary exposed photo wording")
    requireStarter(!summary.toString().contains("snapshot", ignoreCase = true), "summary exposed snapshot wording")

    println("Android Food Wallet starter smoke: PASS")
}

private fun requireStarter(condition: Boolean, message: String) {
    if (!condition) {
        throw IllegalStateException(message)
    }
}
