import FoodWalletCore
import Foundation

@main
struct FoodWalletCoreTests {
    @MainActor
    static func main() async {
        await run("mockAppleEstimateCreatesTightDraftCandidate") {
            try await testMockAppleEstimateCreatesTightDraftCandidate()
        }
        await run("mockRisottoEstimateUsesMixedDishRangeAndAssumptions") {
            try await testMockRisottoEstimateUsesMixedDishRangeAndAssumptions()
        }
        await run("storeConfirmsOnlyAfterDraftReview") {
            try await testStoreConfirmsOnlyAfterDraftReview()
        }
        await run("safeSummaryDoesNotExposeRawPhotoOrProtocolMaterial") {
            try await testSafeSummaryDoesNotExposeRawPhotoOrProtocolMaterial()
        }
        print("IOS_FOOD_WALLET_TESTS: PASS")
    }

    @MainActor
    private static func run(_ name: String, _ body: @MainActor () async throws -> Void) async {
        do {
            try await body()
            print("PASS \(name)")
        } catch {
            fputs("FAIL \(name): \(error)\n", stderr)
            Foundation.exit(1)
        }
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() {
            throw FoodWalletTestFailure(message)
        }
    }

    private static func testMockAppleEstimateCreatesTightDraftCandidate() async throws {
        let client = MockFoodAnalysisClient()
        let candidate = try await client.estimate(example: .fujiApple)

        try expect(candidate.primaryLabel == "Fuji apple", "expected Fuji apple")
        try expect(candidate.portion.gramsMode == 170, "expected 170 g mode")
        try expect(candidate.nutrition.minKcal == 90, "expected 90 kcal min")
        try expect(candidate.nutrition.maxKcal == 115, "expected 115 kcal max")
        try expect(candidate.confidence == .medium, "expected medium confidence")
        try expect(candidate.userConfirmationRequired, "expected confirmation boundary")
    }

    private static func testMockRisottoEstimateUsesMixedDishRangeAndAssumptions() async throws {
        let client = MockFoodAnalysisClient()
        let candidate = try await client.estimate(example: .mushroomRisotto)

        try expect(candidate.dishType == .mixed, "expected mixed dish")
        try expect(candidate.nutrition.minKcal == 520, "expected 520 kcal min")
        try expect(candidate.nutrition.modeKcal == 640, "expected 640 kcal mode")
        try expect(candidate.nutrition.maxKcal == 760, "expected 760 kcal max")
        try expect(candidate.assumptions.contains { $0.id == "butter-oil" }, "expected butter/oil assumption")
        try expect(candidate.evidence.contains { $0.provider == "usda_fdc" }, "expected USDA evidence")
    }

    @MainActor
    private static func testStoreConfirmsOnlyAfterDraftReview() async throws {
        let store = FoodWalletStore()

        try expect(store.entries.isEmpty, "expected empty entries before analysis")
        await store.analyze(example: .fujiApple)
        try expect(store.currentDraft != nil, "expected draft after analysis")
        try expect(store.entries.isEmpty, "expected no entry before confirmation")

        store.confirmDraft()
        try expect(store.entries.count == 1, "expected one confirmed entry")
        try expect(store.safeSummary.totals.entryCount == 1, "expected one summary entry")
        try expect(store.safeSummary.entries.first?.label == "Fuji apple", "expected Fuji apple summary")
    }

    @MainActor
    private static func testSafeSummaryDoesNotExposeRawPhotoOrProtocolMaterial() async throws {
        let store = FoodWalletStore()
        await store.analyze(example: .mushroomRisotto)
        store.confirmDraft()

        let summary = String(describing: store.safeSummary)
        let forbidden = ["rawPhoto", "photoBytes", "COSE", "CBOR", "snapshot", "privateKey", "trustPub", "GR1"]
        for token in forbidden {
            try expect(!summary.localizedCaseInsensitiveContains(token), "safe summary leaked \(token)")
        }
    }
}

private struct FoodWalletTestFailure: Error, CustomStringConvertible {
    var message: String
    var description: String { message }

    init(_ message: String) {
        self.message = message
    }
}
