package dev.grain.food

enum class FoodTrustStatus(val rawValue: String) {
    Verified("verified"),
    SelfIssued("self_issued"),
    Estimated("estimated"),
    Untrusted("untrusted"),
}

enum class FoodSourceClass(val rawValue: String) {
    Attested("attested"),
    Measured("measured"),
    Estimated("estimated"),
}

enum class FoodDraftStatus {
    Ready,
    Confirmed,
}

data class FoodEstimate(
    val label: String,
    val meanKcal: Long,
    val varianceKcal: Long,
    val amountGrams: Long,
    val servingGrams: Long,
    val servings: Long,
    val sourceClass: FoodSourceClass = FoodSourceClass.Estimated,
    val trustStatus: FoodTrustStatus = FoodTrustStatus.Estimated,
) {
    init {
        require(label.isNotBlank()) { "Food estimate label must not be blank" }
        require(meanKcal >= 0) { "Food estimate mean kcal must be non-negative" }
        require(varianceKcal >= 0) { "Food estimate variance kcal must be non-negative" }
        require(amountGrams >= 0) { "Food estimate amount grams must be non-negative" }
        require(servingGrams >= 0) { "Food estimate serving grams must be non-negative" }
        require(servings >= 0) { "Food estimate servings must be non-negative" }
    }
}

data class FoodDraft(
    val draftId: String,
    val label: String,
    val meanKcal: Long,
    val varianceKcal: Long,
    val amountGrams: Long,
    val servingGrams: Long,
    val servings: Long,
    val sourceClass: FoodSourceClass,
    val trustStatus: FoodTrustStatus,
    val dayKey: String,
    val createdAtMillis: Long,
    val status: FoodDraftStatus = FoodDraftStatus.Ready,
)

data class FoodEntry(
    val entryId: String,
    val label: String,
    val meanKcal: Long,
    val varianceKcal: Long,
    val amountGrams: Long,
    val servingGrams: Long,
    val servings: Long,
    val sourceClass: FoodSourceClass,
    val trustStatus: FoodTrustStatus,
    val dayKey: String,
    val confirmedAtMillis: Long,
)

data class FoodDailyTotals(
    val dayKey: String,
    val entryCount: Int,
    val sumMeanKcal: Long,
    val sumVarianceKcal: Long,
)

data class FoodSafeSummary(
    val dayKey: String,
    val entryCount: Int,
    val sumMeanKcal: Long,
    val sumVarianceKcal: Long,
    val sourceClasses: Set<FoodSourceClass>,
    val trustStatuses: Set<FoodTrustStatus>,
)

class FoodWallet {
    private val entries = mutableListOf<FoodEntry>()
    private var nextDraftNumber = 1
    private var nextEntryNumber = 1

    fun createDraft(
        estimate: FoodEstimate,
        dayKey: String,
        createdAtMillis: Long,
    ): FoodDraft {
        requireValidDayKey(dayKey)

        return FoodDraft(
            draftId = nextId(prefix = "food-draft", dayKey = dayKey, number = nextDraftNumber++),
            label = estimate.label,
            meanKcal = estimate.meanKcal,
            varianceKcal = estimate.varianceKcal,
            amountGrams = estimate.amountGrams,
            servingGrams = estimate.servingGrams,
            servings = estimate.servings,
            sourceClass = estimate.sourceClass,
            trustStatus = estimate.trustStatus,
            dayKey = dayKey,
            createdAtMillis = createdAtMillis,
        )
    }

    fun confirm(
        draft: FoodDraft,
        confirmedAtMillis: Long,
    ): FoodEntry {
        require(draft.status == FoodDraftStatus.Ready) { "Only ready food drafts can be confirmed" }
        requireValidDayKey(draft.dayKey)

        val entry = FoodEntry(
            entryId = nextId(prefix = "food-entry", dayKey = draft.dayKey, number = nextEntryNumber++),
            label = draft.label,
            meanKcal = draft.meanKcal,
            varianceKcal = draft.varianceKcal,
            amountGrams = draft.amountGrams,
            servingGrams = draft.servingGrams,
            servings = draft.servings,
            sourceClass = draft.sourceClass,
            trustStatus = draft.trustStatus,
            dayKey = draft.dayKey,
            confirmedAtMillis = confirmedAtMillis,
        )
        entries += entry
        return entry
    }

    fun dailyTotals(dayKey: String): FoodDailyTotals {
        val dayEntries = entriesForDay(dayKey)
        return FoodDailyTotals(
            dayKey = dayKey,
            entryCount = dayEntries.size,
            sumMeanKcal = dayEntries.sumOf { it.meanKcal },
            sumVarianceKcal = dayEntries.sumOf { it.varianceKcal },
        )
    }

    fun safeSummary(dayKey: String): FoodSafeSummary {
        val dayEntries = entriesForDay(dayKey)
        val totals = dailyTotals(dayKey)
        return FoodSafeSummary(
            dayKey = totals.dayKey,
            entryCount = totals.entryCount,
            sumMeanKcal = totals.sumMeanKcal,
            sumVarianceKcal = totals.sumVarianceKcal,
            sourceClasses = dayEntries.mapTo(linkedSetOf()) { it.sourceClass },
            trustStatuses = dayEntries.mapTo(linkedSetOf()) { it.trustStatus },
        )
    }

    fun entriesForDay(dayKey: String): List<FoodEntry> {
        requireValidDayKey(dayKey)
        return entries.filter { it.dayKey == dayKey }
    }

    private fun nextId(prefix: String, dayKey: String, number: Int): String =
        "$prefix-$dayKey-${number.toString().padStart(4, '0')}"

    private fun requireValidDayKey(dayKey: String) {
        require(DAY_KEY_PATTERN.matches(dayKey)) { "Food day key must use YYYY-MM-DD" }
    }

    private companion object {
        val DAY_KEY_PATTERN = Regex("\\d{4}-\\d{2}-\\d{2}")
    }
}
