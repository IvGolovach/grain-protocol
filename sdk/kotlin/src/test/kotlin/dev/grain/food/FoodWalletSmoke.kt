package dev.grain.food

fun main() {
    trustStatusesMatchContract()
    fakeEstimateCanDraftConfirmAndSummarizeSafely()
    foodWalletTypesDoNotExposeRawCustodyOrPhotoFields()
    println("Kotlin Food Wallet smoke: PASS")
}

private fun trustStatusesMatchContract() {
    requireSmoke(FoodTrustStatus.Verified.rawValue == "verified", "verified raw value mismatch")
    requireSmoke(FoodTrustStatus.SelfIssued.rawValue == "self_issued", "self-issued raw value mismatch")
    requireSmoke(FoodTrustStatus.Estimated.rawValue == "estimated", "estimated raw value mismatch")
    requireSmoke(FoodTrustStatus.Untrusted.rawValue == "untrusted", "untrusted raw value mismatch")
}

private fun fakeEstimateCanDraftConfirmAndSummarizeSafely() {
    val wallet = FoodWallet()
    val estimate = FoodEstimate(
        label = "breakfast bowl",
        meanKcal = 620,
        varianceKcal = 9,
        amountGrams = 250,
        servingGrams = 250,
        servings = 1,
        sourceClass = FoodSourceClass.Estimated,
        trustStatus = FoodTrustStatus.Estimated,
    )

    val draft = wallet.createDraft(
        estimate = estimate,
        dayKey = "2026-05-17",
        createdAtMillis = 1_779_000_000_000,
    )
    requireSmoke(draft.status == FoodDraftStatus.Ready, "draft was not ready")
    requireSmoke(draft.sourceClass == FoodSourceClass.Estimated, "draft source class mismatch")
    requireSmoke(draft.trustStatus == FoodTrustStatus.Estimated, "draft trust status mismatch")

    val entry = wallet.confirm(
        draft = draft,
        confirmedAtMillis = 1_779_000_060_000,
    )
    requireSmoke(entry.entryId == "food-entry-2026-05-17-0001", "entry id was not deterministic")
    requireSmoke(entry.meanKcal == 620L, "entry mean kcal mismatch")
    requireSmoke(entry.varianceKcal == 9L, "entry variance kcal mismatch")

    val totals = wallet.dailyTotals("2026-05-17")
    requireSmoke(
        totals == FoodDailyTotals(
            dayKey = "2026-05-17",
            entryCount = 1,
            sumMeanKcal = 620,
            sumVarianceKcal = 9,
        ),
        "daily totals mismatch: $totals",
    )

    val summary = wallet.safeSummary("2026-05-17")
    requireSmoke(summary.dayKey == "2026-05-17", "summary day mismatch")
    requireSmoke(summary.entryCount == 1, "summary entry count mismatch")
    requireSmoke(summary.sumMeanKcal == 620L, "summary mean mismatch")
    requireSmoke(summary.sumVarianceKcal == 9L, "summary variance mismatch")
    requireSmoke(summary.trustStatuses == setOf(FoodTrustStatus.Estimated), "summary trust mismatch")
    requireSmoke(summary.sourceClasses == setOf(FoodSourceClass.Estimated), "summary source mismatch")

    assertNoUnsafeWords(summary.toString())
}

private fun foodWalletTypesDoNotExposeRawCustodyOrPhotoFields() {
    val publicTypes = listOf(
        FoodTrustStatus::class.java,
        FoodSourceClass::class.java,
        FoodEstimate::class.java,
        FoodDraft::class.java,
        FoodEntry::class.java,
        FoodDailyTotals::class.java,
        FoodSafeSummary::class.java,
    )

    publicTypes.forEach { type ->
        assertNoUnsafeWords(type.simpleName)
        type.declaredFields.forEach { field ->
            assertNoUnsafeWords("${type.simpleName}.${field.name}")
        }
        type.declaredMethods.forEach { method ->
            assertNoUnsafeWords("${type.simpleName}.${method.name}")
        }
    }
}

private fun assertNoUnsafeWords(value: String) {
    val lower = value.lowercase()
    val forbidden = listOf("rawphoto", "photo", "snapshot", "trustpub", "privatekey", "private_key", "account")
    forbidden.forEach { word ->
        requireSmoke(!lower.contains(word), "unsafe Food Wallet API word '$word' leaked through '$value'")
    }
}

private fun requireSmoke(condition: Boolean, message: String) {
    if (!condition) {
        throw IllegalStateException(message)
    }
}
