package dev.grain.templates.androidfoodwallet

import dev.grain.food.FoodDailyTotals
import dev.grain.food.FoodDraft
import dev.grain.food.FoodEntry
import dev.grain.food.FoodEstimate
import dev.grain.food.FoodSafeSummary
import dev.grain.food.FoodSourceClass
import dev.grain.food.FoodTrustStatus
import dev.grain.food.FoodWallet

class AndroidFoodWalletStarter(
    private val wallet: FoodWallet = FoodWallet(),
) {
    fun estimateFromAppSignal(
        label: String,
        meanKcal: Long,
        varianceKcal: Long,
        amountGrams: Long,
        servingGrams: Long,
        servings: Long,
        sourceClass: FoodSourceClass = FoodSourceClass.Estimated,
        trustStatus: FoodTrustStatus = FoodTrustStatus.Estimated,
    ): FoodEstimate =
        FoodEstimate(
            label = label,
            meanKcal = meanKcal,
            varianceKcal = varianceKcal,
            amountGrams = amountGrams,
            servingGrams = servingGrams,
            servings = servings,
            sourceClass = sourceClass,
            trustStatus = trustStatus,
        )

    fun draft(
        estimate: FoodEstimate,
        dayKey: String,
        createdAtMillis: Long,
    ): FoodDraft =
        wallet.createDraft(
            estimate = estimate,
            dayKey = dayKey,
            createdAtMillis = createdAtMillis,
        )

    fun confirm(
        draft: FoodDraft,
        confirmedAtMillis: Long,
    ): FoodEntry =
        wallet.confirm(
            draft = draft,
            confirmedAtMillis = confirmedAtMillis,
        )

    fun dailyTotals(dayKey: String): FoodDailyTotals =
        wallet.dailyTotals(dayKey)

    fun safeSummary(dayKey: String): FoodSafeSummary =
        wallet.safeSummary(dayKey)
}
