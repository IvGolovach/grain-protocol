import Foundation

public enum FoodTrustStatus: String, Equatable, Sendable {
    case verified
    case selfIssued = "self_issued"
    case estimated
    case untrusted

    public var label: String {
        switch self {
        case .verified:
            return "Verified"
        case .selfIssued:
            return "Self-issued"
        case .estimated:
            return "Estimated"
        case .untrusted:
            return "Untrusted"
        }
    }
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

    public init(
        label: String,
        kcal: Int64,
        varianceKcal: Int64,
        amountGrams: Int64,
        servingGrams: Int64? = nil,
        servings: Int64 = 1
    ) {
        self.label = label
        self.kcal = kcal
        self.varianceKcal = varianceKcal
        self.amountGrams = amountGrams
        self.servingGrams = servingGrams
        self.servings = servings
    }
}

public struct FoodIntakeDraft: Equatable, Sendable {
    public let draftID: String
    public let meal: MealEstimate
    public let sourceClass: FoodSourceClass
    public let trustStatus: FoodTrustStatus
    public let createdAt: Date
    public let dateKey: String
}

public struct FoodIntakeEntry: Equatable, Sendable {
    public let entryID: String
    public let draftID: String
    public let meal: MealEstimate
    public let sourceClass: FoodSourceClass
    public let trustStatus: FoodTrustStatus
    public let confirmedAt: Date
    public let dateKey: String
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
        public let sourceClass: FoodSourceClass
        public let trustLabel: String
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

    public func makeEstimatedDraft(meal: MealEstimate) -> FoodIntakeDraft {
        makeDraft(meal: meal, sourceClass: .estimated, trustStatus: .estimated)
    }

    public func makeVerifiedDraft(meal: MealEstimate) -> FoodIntakeDraft {
        makeDraft(meal: meal, sourceClass: .attested, trustStatus: .verified)
    }

    public func makeSelfIssuedDraft(meal: MealEstimate) -> FoodIntakeDraft {
        makeDraft(meal: meal, sourceClass: .measured, trustStatus: .selfIssued)
    }

    public func confirmDraft(_ draft: FoodIntakeDraft) -> FoodIntakeEntry {
        let confirmedAt = clock.confirmedAt()
        let entry = FoodIntakeEntry(
            entryID: "food-entry-\(nextEntryNumber)",
            draftID: draft.draftID,
            meal: draft.meal,
            sourceClass: draft.sourceClass,
            trustStatus: draft.trustStatus,
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
                    sourceClass: entry.sourceClass,
                    trustLabel: entry.trustStatus.label,
                    dateKey: entry.dateKey
                )
            }
        )
    }

    private func makeDraft(
        meal: MealEstimate,
        sourceClass: FoodSourceClass,
        trustStatus: FoodTrustStatus
    ) -> FoodIntakeDraft {
        let createdAt = clock.now()
        let draft = FoodIntakeDraft(
            draftID: "food-draft-\(nextDraftNumber)",
            meal: meal,
            sourceClass: sourceClass,
            trustStatus: trustStatus,
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
}

extension FoodTrustStatus: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String { label }
    public var debugDescription: String { description }
}

extension FoodSourceClass: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String { rawValue }
    public var debugDescription: String { description }
}

extension MealEstimate: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        "MealEstimate(label: \(label), kcal: \(kcal), varianceKcal: \(varianceKcal), amountGrams: \(amountGrams), " +
            "servingGrams: \(String(describing: servingGrams)), servings: \(servings))"
    }

    public var debugDescription: String { description }
}

extension FoodIntakeDraft: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        "FoodIntakeDraft(id: \(draftID), meal: \(meal), sourceClass: \(sourceClass), " +
            "status: \(trustStatus), dateKey: \(dateKey))"
    }

    public var debugDescription: String { description }
}

extension FoodIntakeEntry: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        "FoodIntakeEntry(id: \(entryID), meal: \(meal), sourceClass: \(sourceClass), " +
            "status: \(trustStatus), dateKey: \(dateKey))"
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
            "sourceClass: \(sourceClass), trustLabel: \(trustLabel), dateKey: \(dateKey))"
    }

    public var debugDescription: String { description }
}
