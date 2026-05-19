import Foundation
import GrainFoodWallet

@main
struct GrainFoodWalletSmoke {
    static func main() throws {
        try trustStatusesMatchContract()
        try estimatedDraftConfirmsIntoSafeSummary()
        try verifiedAndSelfIssuedDraftsExposeSafeTrustLabels()
        print("swift food wallet smoke: PASS")
    }
}

private func trustStatusesMatchContract() throws {
    try require(
        FoodTrustStatus.verified.rawValue == "verified",
        "verified raw value mismatch"
    )
    try require(
        FoodTrustStatus.selfIssued.rawValue == "self_issued",
        "self-issued raw value mismatch"
    )
    try require(
        FoodTrustStatus.estimated.rawValue == "estimated",
        "estimated raw value mismatch"
    )
    try require(
        FoodTrustStatus.untrusted.rawValue == "untrusted",
        "untrusted raw value mismatch"
    )
}

private func estimatedDraftConfirmsIntoSafeSummary() throws {
    let clock = StaticClock(
        draftTime: Date(timeIntervalSince1970: 1_717_200_000),
        confirmationTime: Date(timeIntervalSince1970: 1_717_200_060)
    )
    let wallet = GrainFoodWallet(clock: clock)

    let draft = wallet.makeEstimatedDraft(
        meal: MealEstimate(
            label: "oatmeal breakfast",
            kcal: 420,
            varianceKcal: 16,
            amountGrams: 275,
            servingGrams: 275,
            servings: 1
        )
    )
    try require(draft.sourceClass == .estimated, "estimated draft source mismatch")
    try require(draft.trustStatus == .estimated, "estimated draft trust mismatch")

    let entry = wallet.confirmDraft(draft)
    try require(entry.entryID == "food-entry-1", "entry id should be deterministic")

    let totals = wallet.dailyTotals(on: "2024-06-01")
    try require(totals.sumMeanKcal == 420, "daily sum_mean mismatch")
    try require(totals.sumVarianceKcal == 16, "daily sum_var mismatch")
    try require(totals.entryCount == 1, "daily entry count mismatch")

    let summary = wallet.exportSafeSummary(on: "2024-06-01")
    try require(summary.dateKey == "2024-06-01", "summary date mismatch")
    try require(summary.entries.map(\.trustLabel) == ["Estimated"], "summary trust label mismatch")
    try requireSafeDescription(String(describing: summary), "summary description")
    try requireSafeDescription(String(reflecting: summary), "summary debug description")
}

private func verifiedAndSelfIssuedDraftsExposeSafeTrustLabels() throws {
    let wallet = GrainFoodWallet(clock: StaticClock())

    let verified = wallet.makeVerifiedDraft(
        meal: MealEstimate(label: "sealed lunch", kcal: 620, varianceKcal: 9, amountGrams: 250)
    )
    let selfIssued = wallet.makeSelfIssuedDraft(
        meal: MealEstimate(label: "manual snack", kcal: 180, varianceKcal: 25, amountGrams: 90)
    )

    _ = wallet.confirmDraft(verified)
    _ = wallet.confirmDraft(selfIssued)

    let summary = wallet.exportSafeSummary()
    try require(summary.entries.map(\.trustLabel) == ["Verified", "Self-issued"], "trust labels mismatch")
    try require(summary.entries.map(\.sourceClass) == [.attested, .measured], "source class mismatch")
}

private struct StaticClock: FoodWalletClock {
    var draftTime = Date(timeIntervalSince1970: 1_717_200_000)
    var confirmationTime = Date(timeIntervalSince1970: 1_717_200_060)

    func now() -> Date {
        draftTime
    }

    func confirmedAt() -> Date {
        confirmationTime
    }
}

private func requireSafeDescription(_ description: String, _ label: String) throws {
    let forbidden = [
        "COSE", "CBOR", "CID", "snapshot", "trustPub",
        "privateKey", "private-key", "B64", "base64", "GR1",
    ]
    for token in forbidden {
        try require(!description.localizedCaseInsensitiveContains(token), "\(label) leaked \(token)")
    }
}

private func require(_ condition: Bool, _ message: String) throws {
    if !condition {
        throw SmokeError.assertion(message)
    }
}

private enum SmokeError: Error {
    case assertion(String)
}
