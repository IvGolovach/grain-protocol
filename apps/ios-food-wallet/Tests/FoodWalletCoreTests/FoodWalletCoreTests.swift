import FoodWalletCore
import Foundation
import GrainFoodWallet

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
        await run("mockPhotoEstimateCreatesDraftWithoutRetainingPhoto") {
            try await testMockPhotoEstimateCreatesDraftWithoutRetainingPhoto()
        }
        await run("brokerPostsTransientPhotoPayload") {
            try await testBrokerPostsTransientPhotoPayload()
        }
        await run("brokerRejectsUnsafeCandidateWithoutConfirmation") {
            try await testBrokerRejectsUnsafeCandidateWithoutConfirmation()
        }
        await run("brokerRejectsNonSuccessStatus") {
            try await testBrokerRejectsNonSuccessStatus()
        }
        await run("storeConfirmsOnlyAfterDraftReview") {
            try await testStoreConfirmsOnlyAfterDraftReview()
        }
        await run("quickTextDraftCreatesSelfIssuedReviewableMeal") {
            try await testQuickTextDraftCreatesSelfIssuedReviewableMeal()
        }
        await run("portionEditorScalesDraftNutritionRange") {
            try await testPortionEditorScalesDraftNutritionRange()
        }
        await run("templatesRecipesAndRecentEntriesCreateDrafts") {
            try await testTemplatesRecipesAndRecentEntriesCreateDrafts()
        }
        await run("copyDateEntriesRepeatsMealsIntoCurrentDay") {
            try await testCopyDateEntriesRepeatsMealsIntoCurrentDay()
        }
        await run("packagedAndVisibleLabelDraftsExposeProviderEvidence") {
            try await testPackagedAndVisibleLabelDraftsExposeProviderEvidence()
        }
        await run("portableExportIncludesSafeUserDataOnly") {
            try await testPortableExportIncludesSafeUserDataOnly()
        }
        await run("storePublishesAnalysisStateWhilePhotoEstimateRuns") {
            try await testStorePublishesAnalysisStateWhilePhotoEstimateRuns()
        }
        await run("storePublishesFailureStateWhenPhotoAnalysisFails") {
            try await testStorePublishesFailureStateWhenPhotoAnalysisFails()
        }
        await run("storeResetClearsSafeSummary") {
            try await testStoreResetClearsSafeSummary()
        }
        await run("deniedPrivacyBlocksSelectedAnalysis") {
            try await testDeniedPrivacyBlocksSelectedAnalysis()
        }
        await run("safeSummaryDoesNotExposeRawPhotoOrProtocolMaterial") {
            try await testSafeSummaryDoesNotExposeRawPhotoOrProtocolMaterial()
        }
        await run("deviceSmokeConfirmsAppleAndRisotto") {
            try await testDeviceSmokeConfirmsAppleAndRisotto()
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

    private static func expectError<T>(
        _ expected: FoodAnalysisBrokerClientError,
        _ body: () async throws -> T
    ) async throws {
        do {
            _ = try await body()
            throw FoodWalletTestFailure("expected error \(expected)")
        } catch let error as FoodAnalysisBrokerClientError {
            try expect(error == expected, "expected \(expected), got \(error)")
        }
    }

    private static func testMockAppleEstimateCreatesTightDraftCandidate() async throws {
        let client = MockFoodAnalysisClient()
        let candidate = try await client.estimate(example: .fujiApple)

        try expect(candidate.primaryLabel == "Fuji apple", "expected Fuji apple")
        try expect(candidate.portion.gramsMode == 170, "expected 170 g mode")
        try expect(candidate.nutrition.minKcal == 90, "expected 90 kcal min")
        try expect(candidate.nutrition.maxKcal == 115, "expected 115 kcal max")
        try expect(candidate.macronutrients.carbohydrateGrams == 27, "expected apple carbohydrate estimate")
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
        try expect(candidate.macronutrients.proteinGrams == 14, "expected risotto protein estimate")
        try expect(candidate.assumptions.contains { $0.id == "butter-oil" }, "expected butter/oil assumption")
        try expect(candidate.evidence.contains { $0.provider == "usda_fdc" }, "expected USDA evidence")
    }

    @MainActor
    private static func testMockPhotoEstimateCreatesDraftWithoutRetainingPhoto() async throws {
        let client = MockFoodAnalysisClient()
        let candidate = try await client.estimate(photo: .uiTestFujiApple)

        try expect(candidate.primaryLabel == "Fuji apple", "expected photo heuristic apple candidate")
        try expect(candidate.evidence.contains { $0.provider == "on_device_photo_heuristic" }, "expected photo evidence")

        let store = FoodWalletStore()
        await store.analyze(photo: .uiTestFujiApple)
        try expect(store.currentDraft != nil, "expected photo draft")
        try expect(store.currentCandidate?.macronutrients.shortLabel == "P 0.5g • C 27g • F 0.3g", "expected macro label")

        let summary = String(describing: store.safeSummary)
        let forbidden = ["rawPhoto", "photoBytes", "photoBase64", "imageBytes", "cameraFrame"]
        for token in forbidden {
            try expect(!summary.localizedCaseInsensitiveContains(token), "safe summary leaked \(token)")
        }
    }

    private static func testBrokerPostsTransientPhotoPayload() async throws {
        let jpegBytes = Data([0xff, 0xd8, 0xff, 0xdb, 0x00, 0x43])
        let capture = BrokerRequestCapture()
        let client = brokerClient { request in
            capture.method = request.httpMethod
            capture.contentType = request.value(forHTTPHeaderField: "Content-Type")
            capture.body = try request.bodyData()
            return BrokerResponse(statusCode: 200, body: brokerEnvelopeJSON(userConfirmationRequired: true))
        }

        let payload = TransientMealPhotoPayload(photo: .uiTestFujiApple, jpegData: jpegBytes)
        let candidate = try await client.estimate(photoPayload: payload)

        try expect(candidate.primaryLabel == "Fuji apple", "expected decoded broker candidate")
        try expect(!String(describing: payload).contains("255, 216"), "expected payload description to redact bytes")
        try expect(capture.method == "POST", "expected POST request")
        try expect(capture.contentType == "application/json", "expected JSON request")
    }

    private static func testBrokerRejectsUnsafeCandidateWithoutConfirmation() async throws {
        let client = brokerClient { _ in
            BrokerResponse(statusCode: 200, body: brokerEnvelopeJSON(userConfirmationRequired: false))
        }
        let payload = TransientMealPhotoPayload(photo: .uiTestFujiApple, jpegData: Data([0xff, 0xd8]))

        try await expectError(.unsafeCandidate("broker response must require user confirmation")) {
            try await client.estimate(photoPayload: payload)
        }
    }

    private static func testBrokerRejectsNonSuccessStatus() async throws {
        let client = brokerClient { _ in
            BrokerResponse(statusCode: 503, body: Data())
        }
        let payload = TransientMealPhotoPayload(photo: .uiTestFujiApple, jpegData: Data([0xff, 0xd8]))

        try await expectError(.httpStatus(503)) {
            try await client.estimate(photoPayload: payload)
        }
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
        try expect(store.todayEntries.count == 1, "expected one current-day entry")
        try expect(store.safeSummary.totals.entryCount == 1, "expected one summary entry")
        try expect(store.safeSummary.entries.first?.label == "Fuji apple", "expected Fuji apple summary")
        try expect(store.safeSummary.entries.first?.macronutrients?.carbohydrateGrams == 27, "expected macros in safe summary")
    }

    @MainActor
    private static func testQuickTextDraftCreatesSelfIssuedReviewableMeal() async throws {
        let store = FoodWalletStore()

        let created = store.createQuickTextDraft("2 eggs and toast with butter")

        try expect(created, "expected quick text to create a draft")
        try expect(store.currentCandidate?.primaryLabel == "2 eggs and toast with butter", "expected typed label")
        try expect(store.currentCandidate?.confidence == .medium, "expected medium confidence for parsed text")
        try expect(store.currentDraft?.trustStatus == .selfIssued, "expected self-issued quick text draft")
        try expect(store.currentDraft?.sourceClass == .measured, "expected measured source class")
        try expect(store.currentDraft?.meal.amountGrams == 220, "expected default parsed grams")
        try expect(store.currentDraft?.meal.kcal == 330, "expected parsed calories")
        try expect(store.entries.isEmpty, "expected review boundary before save")

        store.confirmDraft()

        try expect(store.entries.count == 1, "expected saved quick text entry")
        try expect(store.entries.first?.trustStatus == .selfIssued, "expected saved entry to remain self-issued")
    }

    @MainActor
    private static func testPortionEditorScalesDraftNutritionRange() async throws {
        let store = FoodWalletStore()
        await store.analyze(example: .fujiApple)

        let updated = store.updateCurrentDraftPortion(gramsMode: 85)

        try expect(updated, "expected portion update to succeed")
        try expect(store.currentCandidate?.portion.gramsMode == 85, "expected candidate grams to update")
        try expect(store.currentCandidate?.nutrition.modeKcal == 51, "expected candidate kcal to scale")
        try expect(store.currentDraft?.meal.amountGrams == 85, "expected draft grams to update")
        try expect(store.currentDraft?.meal.kcal == 51, "expected draft kcal to update")
        try expect(store.currentDraft?.meal.varianceKcal == 6, "expected scaled variance")
    }

    @MainActor
    private static func testTemplatesRecipesAndRecentEntriesCreateDrafts() async throws {
        let store = FoodWalletStore()

        try expect(store.savedTemplates.contains { $0.id == "usual-breakfast" }, "expected default usual breakfast template")
        try expect(store.savedRecipes.contains { $0.id == "tomato-cucumber-salad" }, "expected default salad recipe")

        try expect(store.createTemplateDraft(id: "usual-breakfast"), "expected template draft")
        try expect(store.currentDraft?.meal.label == "Usual breakfast", "expected template label")
        try expect(store.currentDraft?.trustStatus == .selfIssued, "expected template to be self-issued")
        store.confirmDraft()

        try expect(store.createRecipeDraft(id: "tomato-cucumber-salad", consumedFraction: 0.5), "expected recipe draft")
        try expect(store.currentDraft?.meal.label == "Tomato cucumber salad", "expected recipe label")
        try expect(store.currentDraft?.meal.amountGrams == 210, "expected half recipe grams")
        try expect(store.currentDraft?.meal.kcal == 140, "expected half recipe calories")
        store.discardDraft()

        try expect(store.createRecentEntryDraft(entryID: store.entries.first!.entryID), "expected recent entry draft")
        try expect(store.currentDraft?.meal.label == "Usual breakfast", "expected recent entry label")
        try expect(store.currentDraft?.trustStatus == .selfIssued, "expected recent repeat to be self-issued")
    }

    @MainActor
    private static func testCopyDateEntriesRepeatsMealsIntoCurrentDay() async throws {
        let clock = MutableFoodWalletClock(now: Date(timeIntervalSince1970: 1_700_000_000))
        let store = FoodWalletStore(wallet: GrainFoodWallet(clock: clock))

        try expect(store.createTemplateDraft(id: "usual-breakfast"), "expected previous-day template draft")
        store.confirmDraft()
        let sourceDateKey = store.entries.first!.dateKey

        clock.nowDate = clock.nowDate.addingTimeInterval(86_400)
        let copied = store.copyEntries(fromDateKey: sourceDateKey)

        try expect(copied == 1, "expected one copied entry")
        try expect(store.entries.count == 2, "expected original plus copied entry")
        try expect(store.entries.first?.meal.label == "Usual breakfast", "expected copied meal label")
        try expect(store.entries.first?.dateKey != sourceDateKey, "expected copied entry to use current date")
    }

    @MainActor
    private static func testPackagedAndVisibleLabelDraftsExposeProviderEvidence() async throws {
        let store = FoodWalletStore()

        try expect(store.createPackagedFoodDraft(barcode: "fixture-kombucha-80"), "expected packaged draft")
        try expect(store.currentCandidate?.primaryLabel == "Kombucha", "expected kombucha package label")
        try expect(store.currentCandidate?.dishType == .packaged, "expected packaged dish type")
        try expect(store.currentCandidate?.evidence.contains { $0.provider == "open_food_facts_fixture" } == true, "expected barcode evidence")
        store.discardDraft()

        try expect(store.createVisibleLabelDraft(label: "Kombucha", caloriesPerContainer: 80, grams: 473), "expected visible label draft")
        try expect(store.currentCandidate?.nutrition.minKcal == 80, "expected exact label calories")
        try expect(store.currentCandidate?.nutrition.maxKcal == 80, "expected exact label calories")
        try expect(store.currentCandidate?.confidence == .high, "expected high confidence for explicit label")
        try expect(store.currentCandidate?.evidence.contains { $0.provider == "visible_nutrition_label" } == true, "expected visible label evidence")
    }

    @MainActor
    private static func testPortableExportIncludesSafeUserDataOnly() async throws {
        let store = FoodWalletStore()

        try expect(store.createQuickTextDraft("2 eggs and toast"), "expected quick text draft")
        store.confirmDraft()
        try expect(store.createRecipeDraft(id: "tomato-cucumber-salad", consumedFraction: 0.5), "expected recipe draft")
        store.confirmDraft()

        let bundle = try store.exportPortableBundle()
        try expect(bundle.schema == "grain.food-wallet.export.v1", "expected export schema")
        try expect(bundle.entries.count == 2, "expected two exported entries")
        try expect(bundle.templates.contains { $0.id == "usual-breakfast" }, "expected templates in export")
        try expect(bundle.recipes.contains { $0.id == "tomato-cucumber-salad" }, "expected recipes in export")
        try expect(bundle.manifest.sha256.count == 64, "expected SHA-256 checksum")

        let json = String(decoding: try store.exportPortableJSON(), as: UTF8.self)
        let csv = store.exportCSV()
        try expect(csv.contains("date,label,kcal_min,kcal_mode,kcal_max,grams,source_class,trust_status"), "expected CSV header")
        try expect(csv.contains("Tomato cucumber salad"), "expected recipe entry in CSV")

        let forbidden = ["rawPhoto", "photoBytes", "photoBase64", "imageBytes", "snapshotB64", "bundleB64", "privateKey", "trustPub", "COSE", "CBOR", "GR1"]
        for token in forbidden {
            try expect(!json.localizedCaseInsensitiveContains(token), "portable export leaked \(token)")
            try expect(!csv.localizedCaseInsensitiveContains(token), "CSV export leaked \(token)")
        }
    }

    @MainActor
    private static func testStorePublishesAnalysisStateWhilePhotoEstimateRuns() async throws {
        let store = FoodWalletStore(analysisClient: SlowFoodAnalysisClient(delayNanoseconds: 100_000_000))

        let task = Task {
            await store.analyze(photo: .uiTestFujiApple)
        }
        try await Task.sleep(nanoseconds: 20_000_000)

        try expect(store.analysisState.isAnalyzing, "expected store to publish analyzing state")
        try expect(store.analysisState.statusText == "Looking for food", "expected first analysis status")

        await task.value

        try expect(store.analysisState == .draftReady, "expected draft ready state")
        try expect(store.currentDraft != nil, "expected draft after delayed analysis")
    }

    @MainActor
    private static func testStorePublishesFailureStateWhenPhotoAnalysisFails() async throws {
        let store = FoodWalletStore(analysisClient: FailingFoodAnalysisClient())

        await store.analyze(photo: .uiTestFujiApple)

        try expect(store.analysisState.isFailed, "expected failed analysis state")
        try expect(store.analysisState.statusText == "Couldn’t analyze photo", "expected friendly failure status")
        try expect(store.currentDraft == nil, "expected no draft after failed analysis")
    }

    @MainActor
    private static func testStoreResetClearsSafeSummary() async throws {
        let store = FoodWalletStore()

        await store.analyze(example: .fujiApple)
        store.confirmDraft()
        try expect(store.entries.count == 1, "expected one entry before reset")
        try expect(store.safeSummary.totals.entryCount == 1, "expected one summary entry before reset")

        store.resetLocalData()
        try expect(store.entries.isEmpty, "expected reset to clear entries")
        try expect(store.currentDraft == nil, "expected reset to clear draft")
        try expect(store.currentCandidate == nil, "expected reset to clear candidate")
        try expect(store.safeSummary.totals.entryCount == 0, "expected reset to clear safe summary count")
        try expect(store.safeSummary.totals.sumMeanKcal == 0, "expected reset to clear safe summary calories")

        await store.analyze(example: .fujiApple)
        store.confirmDraft()
        try expect(store.safeSummary.totals.entryCount == 1, "expected one summary entry after post-reset confirm")
    }

    @MainActor
    private static func testDeniedPrivacyBlocksSelectedAnalysis() async throws {
        let store = FoodWalletStore(privacy: .denied)

        await store.analyzeSelectedExample()

        try expect(store.privacy == .denied, "expected denied privacy to remain denied")
        try expect(store.analysisState == .blockedPrivacy, "expected denied privacy state")
        try expect(store.currentCandidate == nil, "expected denied privacy to block candidate")
        try expect(store.currentDraft == nil, "expected denied privacy to block draft")
        try expect(store.entries.isEmpty, "expected denied privacy to avoid entries")
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

    @MainActor
    private static func testDeviceSmokeConfirmsAppleAndRisotto() async throws {
        let store = FoodWalletStore()
        let result = await store.runDeviceSmoke()

        try expect(result.passed, "expected device smoke to pass: \(result.reason)")
        try expect(result.entryCount == 2, "expected two smoke entries")
        try expect(result.totalKcal > 0, "expected positive smoke kcal total")
        try expect(store.entries.map { $0.meal.label } == ["Mushroom risotto", "Fuji apple"], "expected latest entry first")
    }
}

private struct FoodWalletTestFailure: Error, CustomStringConvertible {
    var message: String
    var description: String { message }

    init(_ message: String) {
        self.message = message
    }
}

private final class MutableFoodWalletClock: FoodWalletClock, @unchecked Sendable {
    var nowDate: Date

    init(now: Date) {
        self.nowDate = now
    }

    func now() -> Date {
        nowDate
    }

    func confirmedAt() -> Date {
        nowDate
    }
}

private struct BrokerResponse: Sendable {
    var statusCode: Int
    var body: Data
}

private final class BrokerRequestCapture: @unchecked Sendable {
    var method: String?
    var contentType: String?
    var body = Data()
}

private struct SlowFoodAnalysisClient: FoodAnalysisClient {
    var delayNanoseconds: UInt64

    func estimate(example: FoodCaptureExample) async throws -> FoodAnalysisCandidate {
        try await Task.sleep(nanoseconds: delayNanoseconds)
        return try await MockFoodAnalysisClient().estimate(example: example)
    }

    func estimate(photo: CapturedMealPhoto) async throws -> FoodAnalysisCandidate {
        try await Task.sleep(nanoseconds: delayNanoseconds)
        return try await MockFoodAnalysisClient().estimate(photo: photo)
    }

    func estimate(photoPayload: TransientMealPhotoPayload) async throws -> FoodAnalysisCandidate {
        try await Task.sleep(nanoseconds: delayNanoseconds)
        return try await MockFoodAnalysisClient().estimate(photoPayload: photoPayload)
    }
}

private struct FailingFoodAnalysisClient: FoodAnalysisClient {
    func estimate(example: FoodCaptureExample) async throws -> FoodAnalysisCandidate {
        throw FoodWalletTestFailure("analysis unavailable")
    }

    func estimate(photo: CapturedMealPhoto) async throws -> FoodAnalysisCandidate {
        throw FoodWalletTestFailure("analysis unavailable")
    }

    func estimate(photoPayload: TransientMealPhotoPayload) async throws -> FoodAnalysisCandidate {
        throw FoodWalletTestFailure("analysis unavailable")
    }
}

private func brokerClient(
    handler: @escaping @Sendable (URLRequest) throws -> BrokerResponse
) -> FoodAnalysisBrokerClient {
    BrokerURLProtocol.setHandler(handler)
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [BrokerURLProtocol.self]
    return FoodAnalysisBrokerClient(
        endpoint: URL(string: "https://broker.example.test/analyze")!,
        session: URLSession(configuration: configuration)
    )
}

private func brokerEnvelopeJSON(userConfirmationRequired: Bool) -> Data {
    let confirmation = userConfirmationRequired ? "true" : "false"
    return Data(
        """
        {
          "ok": true,
          "candidate": {
            "id": "broker-fuji-apple",
            "primaryLabel": "Fuji apple",
            "genericLabel": "apple",
            "dishType": "single",
            "portion": {"gramsMin": 140, "gramsMode": 170, "gramsMax": 210},
            "nutrition": {"minKcal": 90, "modeKcal": 102, "maxKcal": 115},
            "macronutrients": {
              "proteinGrams": 0.5,
              "carbohydrateGrams": 27,
              "fatGrams": 0.3,
              "fiberGrams": 4.8
            },
            "confidence": "medium",
            "assumptions": [
              {"id": "single-item", "label": "single medium apple", "isEnabled": true}
            ],
            "evidence": [
              {
                "provider": "broker_test",
                "providerID": "fruit.apple.fuji.medium",
                "matchedName": "Fuji apple, medium",
                "servingBasis": "per_100g"
              }
            ],
            "userConfirmationRequired": \(confirmation)
          }
        }
        """.utf8
    )
}

private final class BrokerURLProtocol: URLProtocol, @unchecked Sendable {
    private nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> BrokerResponse)?

    static func setHandler(_ handler: @escaping @Sendable (URLRequest) throws -> BrokerResponse) {
        self.handler = handler
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: FoodWalletTestFailure("missing broker test handler"))
            return
        }

        do {
            let brokerResponse = try handler(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: brokerResponse.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: brokerResponse.body)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private extension Data {
    func contains(_ other: Data) -> Bool {
        guard !other.isEmpty, count >= other.count else {
            return false
        }
        return indices.contains { startIndex in
            let endIndex = startIndex + other.count
            guard endIndex <= count else {
                return false
            }
            return self[startIndex..<endIndex].elementsEqual(other)
        }
    }

    func containsUTF8(_ string: String) -> Bool {
        contains(Data(string.utf8))
    }
}

private extension URLRequest {
    func bodyData() throws -> Data {
        if let httpBody {
            return httpBody
        }
        guard let stream = httpBodyStream else {
            return Data()
        }

        stream.open()
        defer {
            stream.close()
        }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count < 0 {
                throw stream.streamError ?? FoodWalletTestFailure("failed to read request body stream")
            }
            if count == 0 {
                break
            }
            data.append(buffer, count: count)
        }
        return data
    }
}
