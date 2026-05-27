package dev.grain.food

fun main() {
    statusAxesMatchContract()
    fakeEstimateCanDraftConfirmAndSummarizeSafely()
    foodWalletTypesDoNotExposeRawCustodyOrPhotoFields()
    println("Kotlin Food Wallet smoke: PASS")
}

private fun statusAxesMatchContract() {
    requireSmoke(FoodRecordTrust.VerifiedSource.rawValue == "verified_source", "verified source raw value mismatch")
    requireSmoke(FoodRecordTrust.SelfIssued.rawValue == "self_issued", "self-issued raw value mismatch")
    requireSmoke(FoodRecordTrust.Untrusted.rawValue == "untrusted", "untrusted raw value mismatch")
    requireSmoke(FoodNutritionConfidence.Confirmed.rawValue == "confirmed", "confirmed raw value mismatch")
    requireSmoke(FoodNutritionConfidence.Estimated.rawValue == "estimated", "estimated raw value mismatch")
    requireSmoke(FoodNutritionConfidence.Incomplete.rawValue == "incomplete", "incomplete raw value mismatch")
    requireSmoke(FoodNutritionConfidence.Unknown.rawValue == "unknown", "unknown raw value mismatch")
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
        recordTrust = FoodRecordTrust.Untrusted,
        nutritionConfidence = FoodNutritionConfidence.Estimated,
    )

    val draft = wallet.createDraft(
        estimate = estimate,
        dayKey = "2026-05-17",
        createdAtMillis = 1_779_000_000_000,
    )
    requireSmoke(draft.status == FoodDraftStatus.Ready, "draft was not ready")
    requireSmoke(draft.sourceClass == FoodSourceClass.Estimated, "draft source class mismatch")
    requireSmoke(draft.recordTrust == FoodRecordTrust.Untrusted, "draft record trust mismatch")
    requireSmoke(draft.nutritionConfidence == FoodNutritionConfidence.Estimated, "draft confidence mismatch")

    val entry = wallet.confirm(
        draft = draft,
        confirmedAtMillis = 1_779_000_060_000,
    )
    requireSmoke(entry.entryId == "food-entry-2026-05-17-0001", "entry id was not deterministic")
    requireSmoke(entry.meanKcal == 620L, "entry mean kcal mismatch")
    requireSmoke(entry.varianceKcal == 9L, "entry variance kcal mismatch")
    requireSmoke(entry.recordTrust == FoodRecordTrust.Untrusted, "entry record trust mismatch")
    requireSmoke(entry.nutritionConfidence == FoodNutritionConfidence.Estimated, "entry confidence mismatch")

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
    requireSmoke(summary.recordTrusts == setOf(FoodRecordTrust.Untrusted), "summary trust mismatch")
    requireSmoke(
        summary.nutritionConfidences == setOf(FoodNutritionConfidence.Estimated),
        "summary confidence mismatch",
    )
    requireSmoke(summary.sourceClasses == setOf(FoodSourceClass.Estimated), "summary source mismatch")

    assertNoUnsafeWords(summary.toString())
}

private fun foodWalletTypesDoNotExposeRawCustodyOrPhotoFields() {
    val publicTypes = listOf(
        FoodRecordTrust::class.java,
        FoodNutritionConfidence::class.java,
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
