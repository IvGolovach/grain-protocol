import Foundation

public enum FoodRecordTrust: String, Equatable, Sendable {
    case verifiedSource = "verified_source"
    case selfIssued = "self_issued"
    case untrusted

    public var label: String {
        switch self {
        case .verifiedSource:
            return "Verified source"
        case .selfIssued:
            return "Self-issued"
        case .untrusted:
            return "Untrusted"
        }
    }
}

@available(*, deprecated, renamed: "FoodRecordTrust")
public typealias FoodTrustStatus = FoodRecordTrust

public enum FoodNutritionConfidence: String, Equatable, Sendable {
    case confirmed
    case estimated
    case incomplete
    case unknown
}

public enum FoodSourceClass: String, Equatable, Sendable {
    case attested
    case measured
    case estimated
}

public struct MealEstimate: Equatable, Sendable {
    public let label: String
    public let kcal: Int64
    public let varianceKcal: Int64
    public let amountGrams: Int64
    public let servingGrams: Int64?
    public let servings: Int64
    public let macronutrients: MealMacronutrients?

    public init(
        label: String,
        kcal: Int64,
        varianceKcal: Int64,
        amountGrams: Int64,
        servingGrams: Int64? = nil,
        servings: Int64 = 1,
        macronutrients: MealMacronutrients? = nil
    ) {
        self.label = label
        self.kcal = kcal
        self.varianceKcal = varianceKcal
        self.amountGrams = amountGrams
        self.servingGrams = servingGrams
        self.servings = servings
        self.macronutrients = macronutrients
    }
}

public struct MealMacronutrients: Codable, Equatable, Sendable {
    public let proteinGrams: Double
    public let carbohydrateGrams: Double
    public let fatGrams: Double
    public let fiberGrams: Double?

    public init(
        proteinGrams: Double,
        carbohydrateGrams: Double,
        fatGrams: Double,
        fiberGrams: Double? = nil
    ) {
        self.proteinGrams = proteinGrams
        self.carbohydrateGrams = carbohydrateGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
    }

    public var shortLabel: String {
        "P \(Self.format(proteinGrams))g • C \(Self.format(carbohydrateGrams))g • F \(Self.format(fatGrams))g"
    }

    private static func format(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}

public struct FoodIntakeDraft: Equatable, Sendable {
    public let draftID: String
    public let meal: MealEstimate
    public let sourceClass: FoodSourceClass
    public let recordTrust: FoodRecordTrust
    public let nutritionConfidence: FoodNutritionConfidence
    public let createdAt: Date
    public let dateKey: String

    public init(
        draftID: String,
        meal: MealEstimate,
        sourceClass: FoodSourceClass,
        recordTrust: FoodRecordTrust,
        nutritionConfidence: FoodNutritionConfidence,
        createdAt: Date,
        dateKey: String
    ) {
        self.draftID = draftID
        self.meal = meal
        self.sourceClass = sourceClass
        self.recordTrust = recordTrust
        self.nutritionConfidence = nutritionConfidence
        self.createdAt = createdAt
        self.dateKey = dateKey
    }
}

public struct FoodIntakeEntry: Equatable, Sendable {
    public let entryID: String
    public let draftID: String
    public let meal: MealEstimate
    public let sourceClass: FoodSourceClass
    public let recordTrust: FoodRecordTrust
    public let nutritionConfidence: FoodNutritionConfidence
    public let confirmedAt: Date
    public let dateKey: String

    public init(
        entryID: String,
        draftID: String,
        meal: MealEstimate,
        sourceClass: FoodSourceClass,
        recordTrust: FoodRecordTrust,
        nutritionConfidence: FoodNutritionConfidence,
        confirmedAt: Date,
        dateKey: String
    ) {
        self.entryID = entryID
        self.draftID = draftID
        self.meal = meal
        self.sourceClass = sourceClass
        self.recordTrust = recordTrust
        self.nutritionConfidence = nutritionConfidence
        self.confirmedAt = confirmedAt
        self.dateKey = dateKey
    }
}

public struct FoodDailyTotals: Equatable, Sendable {
    public let dateKey: String?
    public let sumMeanKcal: Int64
    public let sumVarianceKcal: Int64
    public let entryCount: Int
}

public struct SafeFoodSummary: Equatable, Sendable {
    public struct Entry: Equatable, Sendable {
        public let label: String
        public let kcal: Int64
        public let varianceKcal: Int64
        public let amountGrams: Int64
        public let macronutrients: MealMacronutrients?
        public let sourceClass: FoodSourceClass
        public let recordTrustLabel: String
        public let nutritionConfidence: FoodNutritionConfidence
        public let dateKey: String
    }

    public let dateKey: String?
    public let totals: FoodDailyTotals
    public let entries: [Entry]
}

public protocol FoodWalletClock: Sendable {
    func now() -> Date
    func confirmedAt() -> Date
}

public struct SystemFoodWalletClock: FoodWalletClock {
    public init() {}

    public func now() -> Date {
        Date()
    }

    public func confirmedAt() -> Date {
        Date()
    }
}

public final class GrainFoodWallet {
    private let clock: any FoodWalletClock
    private var nextDraftNumber = 1
    private var nextEntryNumber = 1
    private var entries: [FoodIntakeEntry] = []

    public init(clock: any FoodWalletClock = SystemFoodWalletClock()) {
        self.clock = clock
    }

    public func replaceEntries(_ entries: [FoodIntakeEntry]) {
        self.entries = entries
        nextEntryNumber = Self.nextSequence(after: entries.map(\.entryID), prefix: "food-entry-")
        nextDraftNumber = Self.nextSequence(after: entries.map(\.draftID), prefix: "food-draft-")
    }

    @discardableResult
    public func updateEntry(
        entryID: String,
        meal: MealEstimate,
        sourceClass: FoodSourceClass,
        recordTrust: FoodRecordTrust,
        nutritionConfidence: FoodNutritionConfidence
    ) -> FoodIntakeEntry? {
        guard let index = entries.firstIndex(where: { $0.entryID == entryID }) else {
            return nil
        }
        let current = entries[index]
        let updated = FoodIntakeEntry(
            entryID: current.entryID,
            draftID: current.draftID,
            meal: meal,
            sourceClass: sourceClass,
            recordTrust: recordTrust,
            nutritionConfidence: nutritionConfidence,
            confirmedAt: current.confirmedAt,
            dateKey: current.dateKey
        )
        entries[index] = updated
        return updated
    }

    @discardableResult
    public func deleteEntry(entryID: String) -> FoodIntakeEntry? {
        guard let index = entries.firstIndex(where: { $0.entryID == entryID }) else {
            return nil
        }
        return entries.remove(at: index)
    }

    public func makeEstimatedDraft(meal: MealEstimate) -> FoodIntakeDraft {
        makeDraft(meal: meal, sourceClass: .estimated, recordTrust: .untrusted, nutritionConfidence: .estimated)
    }

    public func makeVerifiedDraft(meal: MealEstimate) -> FoodIntakeDraft {
        makeDraft(meal: meal, sourceClass: .attested, recordTrust: .verifiedSource, nutritionConfidence: .confirmed)
    }

    public func makeSelfIssuedDraft(meal: MealEstimate) -> FoodIntakeDraft {
        makeDraft(meal: meal, sourceClass: .measured, recordTrust: .selfIssued, nutritionConfidence: .confirmed)
    }

    public func confirmDraft(_ draft: FoodIntakeDraft) -> FoodIntakeEntry {
        let confirmedAt = clock.confirmedAt()
        let entry = FoodIntakeEntry(
            entryID: "food-entry-\(nextEntryNumber)",
            draftID: draft.draftID,
            meal: draft.meal,
            sourceClass: draft.sourceClass,
            recordTrust: draft.recordTrust,
            nutritionConfidence: draft.nutritionConfidence,
            confirmedAt: confirmedAt,
            dateKey: Self.dateKey(for: confirmedAt)
        )
        nextEntryNumber += 1
        entries.append(entry)
        return entry
    }

    public func dailyTotals(on dateKey: String? = nil) -> FoodDailyTotals {
        let selected = filteredEntries(on: dateKey)
        return FoodDailyTotals(
            dateKey: dateKey,
            sumMeanKcal: selected.reduce(0) { $0 + $1.meal.kcal },
            sumVarianceKcal: selected.reduce(0) { $0 + $1.meal.varianceKcal },
            entryCount: selected.count
        )
    }

    public func exportSafeSummary(on dateKey: String? = nil) -> SafeFoodSummary {
        let selected = filteredEntries(on: dateKey)
        return SafeFoodSummary(
            dateKey: dateKey,
            totals: dailyTotals(on: dateKey),
            entries: selected.map { entry in
                SafeFoodSummary.Entry(
                    label: entry.meal.label,
                    kcal: entry.meal.kcal,
                    varianceKcal: entry.meal.varianceKcal,
                    amountGrams: entry.meal.amountGrams,
                    macronutrients: entry.meal.macronutrients,
                    sourceClass: entry.sourceClass,
                    recordTrustLabel: entry.recordTrust.label,
                    nutritionConfidence: entry.nutritionConfidence,
                    dateKey: entry.dateKey
                )
            }
        )
    }

    private func makeDraft(
        meal: MealEstimate,
        sourceClass: FoodSourceClass,
        recordTrust: FoodRecordTrust,
        nutritionConfidence: FoodNutritionConfidence
    ) -> FoodIntakeDraft {
        let createdAt = clock.now()
        let draft = FoodIntakeDraft(
            draftID: "food-draft-\(nextDraftNumber)",
            meal: meal,
            sourceClass: sourceClass,
            recordTrust: recordTrust,
            nutritionConfidence: nutritionConfidence,
            createdAt: createdAt,
            dateKey: Self.dateKey(for: createdAt)
        )
        nextDraftNumber += 1
        return draft
    }

    private func filteredEntries(on dateKey: String?) -> [FoodIntakeEntry] {
        guard let dateKey else {
            return entries
        }
        return entries.filter { $0.dateKey == dateKey }
    }

    private static func dateKey(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private static func nextSequence(after values: [String], prefix: String) -> Int {
        let maxNumber = values.compactMap { value -> Int? in
            guard value.hasPrefix(prefix) else {
                return nil
            }
            return Int(value.dropFirst(prefix.count))
        }.max() ?? 0
        return maxNumber + 1
    }
}

extension FoodRecordTrust: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String { label }
    public var debugDescription: String { description }
}

extension FoodNutritionConfidence: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String { rawValue }
    public var debugDescription: String { description }
}

extension FoodSourceClass: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String { rawValue }
    public var debugDescription: String { description }
}

extension MealEstimate: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        "MealEstimate(label: \(label), kcal: \(kcal), varianceKcal: \(varianceKcal), amountGrams: \(amountGrams), " +
            "servingGrams: \(String(describing: servingGrams)), servings: \(servings), " +
            "macronutrients: \(String(describing: macronutrients)))"
    }

    public var debugDescription: String { description }
}

extension MealMacronutrients: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        "MealMacronutrients(proteinGrams: \(proteinGrams), carbohydrateGrams: \(carbohydrateGrams), " +
            "fatGrams: \(fatGrams), fiberGrams: \(String(describing: fiberGrams)))"
    }

    public var debugDescription: String { description }
}

extension FoodIntakeDraft: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        "FoodIntakeDraft(id: \(draftID), meal: \(meal), sourceClass: \(sourceClass), " +
            "recordTrust: \(recordTrust), nutritionConfidence: \(nutritionConfidence), dateKey: \(dateKey))"
    }

    public var debugDescription: String { description }
}

extension FoodIntakeEntry: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        "FoodIntakeEntry(id: \(entryID), meal: \(meal), sourceClass: \(sourceClass), " +
            "recordTrust: \(recordTrust), nutritionConfidence: \(nutritionConfidence), dateKey: \(dateKey))"
    }

    public var debugDescription: String { description }
}

extension FoodDailyTotals: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        "FoodDailyTotals(dateKey: \(String(describing: dateKey)), sumMeanKcal: \(sumMeanKcal), " +
            "sumVarianceKcal: \(sumVarianceKcal), entryCount: \(entryCount))"
    }

    public var debugDescription: String { description }
}

extension SafeFoodSummary: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        "SafeFoodSummary(dateKey: \(String(describing: dateKey)), totals: \(totals), entries: \(entries))"
    }

    public var debugDescription: String { description }
}

extension SafeFoodSummary.Entry: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        "Entry(label: \(label), kcal: \(kcal), varianceKcal: \(varianceKcal), amountGrams: \(amountGrams), " +
            "sourceClass: \(sourceClass), recordTrustLabel: \(recordTrustLabel), nutritionConfidence: \(nutritionConfidence), dateKey: \(dateKey))"
    }

    public var debugDescription: String { description }
}
