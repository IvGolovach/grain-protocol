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
        await run("providerEvidenceNormalizesSourceLabels") {
            try await testProviderEvidenceNormalizesSourceLabels()
        }
        await run("mealMarkProvenanceSnapshotPreservesCandidateEvidence") {
            try await testMealMarkProvenanceSnapshotPreservesCandidateEvidence()
        }
        await run("addFoodSuggestionRowNormalizesSearchText") {
            try await testAddFoodSuggestionRowNormalizesSearchText()
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
        await run("brokerMapsNoFoodError") {
            try await testBrokerMapsNoFoodError()
        }
        await run("brokerSearchPostsBarcodeEnvelope") {
            try await testBrokerSearchPostsBarcodeEnvelope()
        }
        await run("brokerSearchRejectsInvalidBarcodeInput") {
            try testBrokerSearchRejectsInvalidBarcodeInput()
        }
        await run("barcodeNormalizationMatchesBrokerContract") {
            try testBarcodeNormalizationMatchesBrokerContract()
        }
        await run("cameraBarcodeSelectionPrefersStableRetailCodes") {
            try testCameraBarcodeSelectionPrefersStableRetailCodes()
        }
        await run("storeCreatesReviewableDraftFromBrokerBarcodeSearch") {
            try await testStoreCreatesReviewableDraftFromBrokerBarcodeSearch()
        }
        await run("storeReportsUnavailableBarcodeLookupWithoutBroker") {
            try await testStoreReportsUnavailableBarcodeLookupWithoutBroker()
        }
        await run("storeConfirmsOnlyAfterDraftReview") {
            try await testStoreConfirmsOnlyAfterDraftReview()
        }
        await run("quickTextDraftCreatesSelfIssuedReviewableMeal") {
            try await testQuickTextDraftCreatesSelfIssuedReviewableMeal()
        }
        await run("addFoodSearchSuggestionsPreferCatalogMatches") {
            try await testAddFoodSearchSuggestionsPreferCatalogMatches()
        }
        await run("portionEditorScalesDraftNutritionRange") {
            try await testPortionEditorScalesDraftNutritionRange()
        }
        await run("portionEditorPreservesProviderEvidenceAndDraftProvenance") {
            try await testPortionEditorPreservesProviderEvidenceAndDraftProvenance()
        }
        await run("portionEditorRejectsNonPositiveGrams") {
            try await testPortionEditorRejectsNonPositiveGrams()
        }
        await run("startsWithoutDemoSavedMealsOrRecipes") {
            try await testStartsWithoutDemoSavedMealsOrRecipes()
        }
        await run("ingredientMealBuilderCreatesReviewableDraft") {
            try await testIngredientMealBuilderCreatesReviewableDraft()
        }
        await run("ingredientSuggestionsIncludeMilkVariants") {
            try await testIngredientSuggestionsIncludeMilkVariants()
        }
        await run("ingredientSuggestionsIncludeCommonProteins") {
            try await testIngredientSuggestionsIncludeCommonProteins()
        }
        await run("brokerSearchResultCanBecomeReusableIngredient") {
            try await testBrokerSearchResultCanBecomeReusableIngredient()
        }
        await run("buildMealSavesReusableRecipeAndQRCode") {
            try await testBuildMealSavesReusableRecipeAndQRCode()
        }
        await run("qrPayloadImportCreatesReviewableDraft") {
            try await testQRCodePayloadImportCreatesReviewableDraft()
        }
        await run("caseinProteinResolvesAsCuratedPowder") {
            try await testCaseinProteinResolvesAsCuratedPowder()
        }
        await run("customIngredientCanResolveUnknownFood") {
            try await testCustomIngredientCanResolveUnknownFood()
        }
        await run("explicitTemplatesAndRecentEntriesCreateDrafts") {
            try await testTemplatesRecipesAndRecentEntriesCreateDrafts()
        }
        await run("copyDateEntriesRepeatsMealsIntoCurrentDay") {
            try await testCopyDateEntriesRepeatsMealsIntoCurrentDay()
        }
        await run("visibleLabelDraftExposesProviderEvidence") {
            try await testVisibleLabelDraftExposesProviderEvidence()
        }
        await run("storeRestoresInjectedEntries") {
            try await testStoreRestoresInjectedEntries()
        }
        await run("entryChangeCallbackFiresForDurableMutations") {
            try await testEntryChangeCallbackFiresForDurableMutations()
        }
        await run("storeEditsConfirmedEntryAndPublishesDerivedState") {
            try await testStoreEditsConfirmedEntryAndPublishesDerivedState()
        }
        await run("storeDeletesConfirmedEntryAndPublishesDerivedState") {
            try await testStoreDeletesConfirmedEntryAndPublishesDerivedState()
        }
        await run("portableBundleHasDeterministicIntegrityMetadataAndSummaries") {
            try await testPortableBundleHasDeterministicIntegrityMetadataAndSummaries()
        }
        await run("importPreviewValidatesAndMergeIsIdempotent") {
            try await testImportPreviewValidatesAndMergeIsIdempotent()
        }
        await run("portableExportIncludesSafeUserDataOnly") {
            try await testPortableExportIncludesSafeUserDataOnly()
        }
        await run("portableExportIncludesUserLibraryEvidenceMetadata") {
            try await testPortableExportIncludesUserLibraryEvidenceMetadata()
        }
        await run("userLibraryCodecMigratesLegacyPersonalIngredients") {
            try testUserLibraryCodecMigratesLegacyPersonalIngredients()
        }
        await run("userLibraryCodecDefaultsMissingCollections") {
            try testUserLibraryCodecDefaultsMissingCollections()
        }
        await run("storeRestoresDurableEntriesAndPublishesLedgerChanges") {
            try await testStoreRestoresDurableEntriesAndPublishesLedgerChanges()
        }
        await run("localLedgerCodecRoundTripsEntries") {
            try await testLocalLedgerCodecRoundTripsEntries()
        }
        await run("portableBundleHasVerifiableIntegrityAndProvenance") {
            try await testPortableBundleHasVerifiableIntegrityAndProvenance()
        }
        await run("portableImportPreviewsAndMergesIdempotently") {
            try await testPortableImportPreviewsAndMergesIdempotently()
        }
        await run("portableImportRejectsTamperedBundle") {
            try await testPortableImportRejectsTamperedBundle()
        }
        await run("storePublishesAnalysisStateWhilePhotoEstimateRuns") {
            try await testStorePublishesAnalysisStateWhilePhotoEstimateRuns()
        }
        await run("storePublishesFailureStateWhenPhotoAnalysisFails") {
            try await testStorePublishesFailureStateWhenPhotoAnalysisFails()
        }
        await run("storePublishesNoFoodStateWithoutDraft") {
            try await testStorePublishesNoFoodStateWithoutDraft()
        }
        await run("storePublishesTimeoutStateWithoutDraft") {
            try await testStorePublishesTimeoutStateWithoutDraft()
        }
        await run("storeResetClearsSafeSummary") {
            try await testStoreResetClearsSafeSummary()
        }
        await run("storeRefreshesLocalEntriesWithoutPublishingWriteback") {
            try await testStoreRefreshesLocalEntriesWithoutPublishingWriteback()
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

    private static func expectImportError<T>(
        _ expected: FoodWalletImportError,
        _ body: () throws -> T
    ) throws {
        do {
            _ = try body()
            throw FoodWalletTestFailure("expected import error \(expected)")
        } catch let error as FoodWalletImportError {
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

    private static func testProviderEvidenceNormalizesSourceLabels() async throws {
        let evidence = ProviderEvidence(
            provider: "USDA FDC",
            providerID: "generic-apple",
            matchedName: "Apple, raw",
            servingBasis: "per_100g"
        )

        try expect(evidence.normalizedProvider == "usda_fdc", "expected normalized provider id")
        try expect(evidence.sourceLabel == "USDA estimate", "expected USDA source label")
        try expect(FoodEvidenceSource(id: "open-food-facts").label == "Barcode match", "expected barcode source label")
    }

    private static func testMealMarkProvenanceSnapshotPreservesCandidateEvidence() async throws {
        let candidate = try await MockFoodAnalysisClient().estimate(example: .mushroomRisotto)
        let wallet = GrainFoodWallet()
        let draft = wallet.makeEstimatedDraft(meal: candidate.mealEstimate())

        let snapshot = MealMarkProvenanceSnapshot(candidate: candidate, draft: draft)

        try expect(snapshot.id == "food-draft-1", "expected draft-backed snapshot id")
        try expect(snapshot.candidateID == candidate.id, "expected candidate id in provenance")
        try expect(snapshot.sourceClass == "estimated", "expected estimated source class")
        try expect(snapshot.trustStatus == "estimated", "expected estimated trust status")
        try expect(snapshot.primarySourceLabel == "USDA estimate", "expected prioritized source label")
        try expect(snapshot.sourceLabels == ["Curated estimate", "USDA estimate"], "expected all source labels")
        try expect(snapshot.evidence == candidate.evidence, "expected provider evidence to be preserved")
    }

    private static func testAddFoodSuggestionRowNormalizesSearchText() async throws {
        let candidate = try await MockFoodAnalysisClient().estimate(example: .mushroomRisotto)
        let row = candidate.addFoodSuggestionRow(kind: .providerMatch)

        try expect(row.title == "Mushroom risotto", "expected candidate title")
        try expect(row.subtitle == "about 320 g | 520-760 kcal", "expected compact nutrition subtitle")
        try expect(row.sourceLabel == "USDA estimate", "expected source label on search row")
        try expect(row.matches(AddFoodSearchQuery("mushroom usda")), "expected title and source search to match")
        try expect(row.matches(AddFoodSearchQuery("rice cheese")), "expected evidence search to match")
        try expect(!row.matches(AddFoodSearchQuery("banana")), "expected unrelated search to miss")
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

    private static func testBrokerMapsNoFoodError() async throws {
        let client = brokerClient { _ in
            BrokerResponse(statusCode: 422, body: brokerErrorJSON(
                code: "NO_FOOD_DETECTED",
                message: "A tabletop is visible, but no food or nutrition label is visible."
            ))
        }
        let payload = TransientMealPhotoPayload(photo: .uiTestFujiApple, jpegData: Data([0xff, 0xd8]))

        try await expectError(.brokerError(
            code: "NO_FOOD_DETECTED",
            message: "A tabletop is visible, but no food or nutrition label is visible.",
            status: 422
        )) {
            try await client.estimate(photoPayload: payload)
        }
    }

    private static func testBrokerSearchPostsBarcodeEnvelope() async throws {
        let capture = BrokerRequestCapture()
        let client = brokerClient { request in
            capture.method = request.httpMethod
            capture.contentType = request.value(forHTTPHeaderField: "Content-Type")
            capture.path = request.url?.path
            capture.body = try request.bodyData()
            return BrokerResponse(statusCode: 200, body: brokerSearchEnvelopeJSON())
        }

        let results = try await client.searchFood(BrokerFoodSearchRequest(barcode: "0 12345-67890 5"))

        try expect(results.count == 1, "expected one broker search result")
        try expect(results[0].primaryLabel == "Ginger lemon kombucha", "expected decoded barcode product")
        try expect(capture.method == "POST", "expected POST request")
        try expect(capture.contentType == "application/json", "expected JSON request")
        try expect(capture.path == "/v1/food/search", "expected search endpoint, got \(capture.path ?? "nil")")
        let body = try JSONSerialization.jsonObject(with: capture.body) as? [String: Any]
        try expect(body?["barcode"] as? String == "012345678905", "expected normalized barcode in request")
        try expect(body?["limit"] as? Int == 8, "expected default search limit")
    }

    private static func testBrokerSearchRejectsInvalidBarcodeInput() throws {
        try expect(BrokerFoodSearchRequest.normalizeBarcode("abc 123") == nil, "expected short barcode to be rejected")
        try expect(BrokerFoodSearchRequest.normalizeBarcode("0 12345-67890 5") == "012345678905", "expected UPC digits")
        do {
            _ = try BrokerFoodSearchRequest(barcode: "abc 123")
            throw FoodWalletTestFailure("expected invalid barcode error")
        } catch let error as BrokerFoodSearchError {
            try expect(
                error == .invalidRequest("query or barcode is required"),
                "expected invalid barcode error, got \(error)"
            )
        }
    }

    private static func testBarcodeNormalizationMatchesBrokerContract() throws {
        try expect(BrokerFoodSearchRequest.normalizeBarcode("4860019001346") == "4860019001346", "expected EAN-13 digits")
        try expect(BrokerFoodSearchRequest.normalizeBarcode("0 12345 67890 5") == "012345678905", "expected spaced UPC-A digits")
        try expect(BrokerFoodSearchRequest.normalizeBarcode("00-123456-789012") == "00123456789012", "expected GTIN-14 digits")
        try expect(BrokerFoodSearchRequest.normalizeBarcode("１２３４５６７８") == nil, "expected non-ASCII digits to be rejected")
        try expect(BrokerFoodSearchRequest.normalizeBarcode("abc4860019001346") == "4860019001346", "expected scanner text payload to strip labels")
    }

    private static func testCameraBarcodeSelectionPrefersStableRetailCodes() throws {
        try expect(
            BrokerFoodSearchRequest.preferredCameraBarcode(from: ["00513166"]) == nil,
            "expected automatic scanner flow to wait instead of emitting a short EAN-8 candidate"
        )
        try expect(
            BrokerFoodSearchRequest.preferredCameraBarcode(from: ["00513166"], allowsShortBarcode: true) == "00513166",
            "expected tapped short barcode to remain usable"
        )
        try expect(
            BrokerFoodSearchRequest.preferredCameraBarcode(from: ["00513166", "0 33617 00002 6"]) == "033617000026",
            "expected scanner flow to prefer full UPC-A over short secondary code"
        )
        try expect(
            BrokerFoodSearchRequest.preferredCameraBarcode(from: ["033617000026", "0033617000026"]) == "0033617000026",
            "expected EAN-13 provider form to win when both UPC-A and EAN-13 are visible"
        )
    }

    @MainActor
    private static func testStoreCreatesReviewableDraftFromBrokerBarcodeSearch() async throws {
        let result = try JSONDecoder().decode(BrokerFoodSearchEnvelope.self, from: brokerSearchEnvelopeJSON()).results[0]
        let client = StaticFoodSearchClient(results: [result])
        let store = FoodWalletStore(searchClient: client)

        await store.searchBrokerFood(barcode: "012345678905")

        try expect(store.foodSearchState == .ready(resultCount: 1), "expected ready search state")
        try expect(store.brokerFoodSearchRows.count == 1, "expected one cached search row")
        try expect(store.brokerFoodSearchRows.first?.sourceLabel == "Barcode match", "expected barcode source label")
        try expect(store.createBrokerFoodSearchDraft(id: "food-search:fixture-kombucha-bottle"), "expected barcode result draft")
        try expect(store.currentCandidate?.primaryLabel == "Ginger lemon kombucha", "expected barcode candidate")
        try expect(store.currentCandidate?.dishType == .packaged, "expected packaged candidate")
        try expect(store.currentCandidate?.userConfirmationRequired == true, "expected review boundary")
        try expect(store.currentDraft?.sourceClass == .estimated, "expected estimated source class")
        try expect(store.currentDraft?.trustStatus == .estimated, "expected estimated trust")
        try expect(store.currentDraft?.meal.amountGrams == 473, "expected bottle grams")
        try expect(store.currentDraft?.meal.kcal == 80, "expected serving kcal from per-100g data")
        try expect(store.currentCandidate?.primarySourceLabel() == "Barcode match", "expected barcode provenance")
    }

    @MainActor
    private static func testStoreReportsUnavailableBarcodeLookupWithoutBroker() async throws {
        let store = FoodWalletStore(searchClient: nil)

        await store.searchBrokerFood(barcode: "012345678905")

        try expect(store.brokerFoodSearchRows.isEmpty, "expected no broker rows")
        try expect(
            store.foodSearchState == .failed("Food lookup is unavailable. Try photo or enter the food manually."),
            "expected unavailable lookup state"
        )
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
    private static func testAddFoodSearchSuggestionsPreferCatalogMatches() async throws {
        let store = FoodWalletStore()
        let rows = store.addFoodSearchSuggestions(for: "casein protein")

        guard let first = rows.first else {
            throw FoodWalletTestFailure("expected casein protein search result")
        }
        try expect(first.title == "Casein protein powder", "expected catalog-backed casein result")
        try expect(first.sourceLabel == "Ingredient catalog", "expected provenance label")
        try expect(first.subtitle == "1 scoop (30 g) | 108 kcal", "expected serving kcal summary")
        try expect(first.evidence.contains { $0.providerID == "protein-powder.casein" }, "expected ingredient evidence")

        try expect(store.createFoodSearchSuggestionDraft(id: first.id), "expected catalog result draft")
        try expect(store.currentCandidate?.primaryLabel == "Casein protein powder", "expected matched draft label")
        try expect(store.currentDraft?.meal.kcal == 108, "expected catalog serving kcal")
        try expect(store.currentCandidate?.macronutrients.shortLabel == "P 24g • C 3g • F 0.9g", "expected serving macros")
    }

    @MainActor
    private static func testPortionEditorScalesDraftNutritionRange() async throws {
        let store = FoodWalletStore()
        await store.analyze(example: .fujiApple)

        let updated = store.updateCurrentDraftPortion(gramsMode: 85)

        try expect(updated, "expected portion update to succeed")
        try expect(store.currentCandidate?.portion.gramsMin == 70, "expected candidate min grams to scale")
        try expect(store.currentCandidate?.portion.gramsMode == 85, "expected candidate grams to update")
        try expect(store.currentCandidate?.portion.gramsMax == 105, "expected candidate max grams to scale")
        try expect(store.currentCandidate?.nutrition.minKcal == 45, "expected candidate min kcal to scale")
        try expect(store.currentCandidate?.nutrition.modeKcal == 51, "expected candidate kcal to scale")
        try expect(store.currentCandidate?.nutrition.maxKcal == 58, "expected candidate max kcal to scale")
        try expect(store.currentCandidate?.macronutrients.proteinGrams == 0.25, "expected protein to scale")
        try expect(store.currentCandidate?.macronutrients.carbohydrateGrams == 13.5, "expected carbs to scale")
        try expect(abs((store.currentCandidate?.macronutrients.fatGrams ?? 0) - 0.15) < 0.0001, "expected fat to scale")
        try expect(store.currentCandidate?.assumptions.filter { $0.id == "user-portion" }.count == 1, "expected one user portion assumption")
        try expect(store.currentDraft?.meal.amountGrams == 85, "expected draft grams to update")
        try expect(store.currentDraft?.meal.kcal == 51, "expected draft kcal to update")
        try expect(store.currentDraft?.meal.varianceKcal == 6, "expected scaled variance")
    }

    @MainActor
    private static func testPortionEditorPreservesProviderEvidenceAndDraftProvenance() async throws {
        let clock = MutableFoodWalletClock(now: Date(timeIntervalSince1970: 1_700_000_000))
        let store = FoodWalletStore(wallet: GrainFoodWallet(clock: clock))
        await store.analyze(photo: .uiTestFujiApple)

        guard let originalEvidence = store.currentCandidate?.evidence else {
            throw FoodWalletTestFailure("expected provider evidence before portion edit")
        }
        guard let originalDraft = store.currentDraft else {
            throw FoodWalletTestFailure("expected draft before portion edit")
        }
        clock.nowDate = clock.nowDate.addingTimeInterval(86_400)
        let originalSourceClass = store.currentDraft?.sourceClass
        let originalTrustStatus = store.currentDraft?.trustStatus

        let updated = store.updateCurrentDraftPortion(gramsMode: 255)

        try expect(updated, "expected portion update to succeed")
        try expect(store.currentCandidate?.evidence == originalEvidence, "expected portion edit to preserve provider evidence")
        try expect(store.currentCandidate?.assumptions.contains { $0.id == "user-portion" } == true, "expected user portion assumption")
        try expect(store.currentDraft?.draftID == originalDraft.draftID, "expected draft id to be preserved")
        try expect(store.currentDraft?.createdAt == originalDraft.createdAt, "expected draft createdAt to be preserved")
        try expect(store.currentDraft?.dateKey == originalDraft.dateKey, "expected draft dateKey to be preserved")
        try expect(store.currentDraft?.sourceClass == originalSourceClass, "expected draft source class to be preserved")
        try expect(store.currentDraft?.trustStatus == originalTrustStatus, "expected draft trust status to be preserved")
        store.confirmDraft()
        try expect(store.entries.first?.draftID == originalDraft.draftID, "expected saved entry draft id to be preserved")
        try expect(store.entries.first?.meal.amountGrams == 255, "expected saved entry grams to preserve portion edit")
        try expect(store.entries.first?.meal.kcal == 153, "expected saved entry kcal to preserve portion edit")
        try expect(store.entries.first?.sourceClass == originalSourceClass, "expected saved entry source class to be preserved")
        try expect(store.entries.first?.trustStatus == originalTrustStatus, "expected saved entry trust status to be preserved")
    }

    @MainActor
    private static func testPortionEditorRejectsNonPositiveGrams() async throws {
        let store = FoodWalletStore()
        await store.analyze(example: .fujiApple)

        let originalCandidate = store.currentCandidate
        let originalDraft = store.currentDraft

        try expect(!store.updateCurrentDraftPortion(gramsMode: 0), "expected zero grams to be rejected")
        try expect(store.currentCandidate == originalCandidate, "expected candidate to remain unchanged after zero grams")
        try expect(store.currentDraft == originalDraft, "expected draft to remain unchanged after zero grams")
        try expect(!store.updateCurrentDraftPortion(gramsMode: -10), "expected negative grams to be rejected")
        try expect(store.currentCandidate == originalCandidate, "expected candidate to remain unchanged after negative grams")
        try expect(store.currentDraft == originalDraft, "expected draft to remain unchanged after negative grams")
    }

    @MainActor
    private static func testStartsWithoutDemoSavedMealsOrRecipes() async throws {
        let store = FoodWalletStore()

        try expect(store.savedTemplates.isEmpty, "expected no fake saved meal templates")
        try expect(store.savedRecipes.isEmpty, "expected no fake saved recipes")
    }

    @MainActor
    private static func testIngredientMealBuilderCreatesReviewableDraft() async throws {
        let store = FoodWalletStore()

        let result = store.createIngredientMealDraft(
            title: "Breakfast",
            ingredients: [
                FoodMealIngredientInput(name: "eggs", grams: 100),
                FoodMealIngredientInput(name: "toast", grams: 40),
                FoodMealIngredientInput(name: "butter", grams: 10),
            ]
        )

        try expect(result == .created, "expected ingredient meal draft to be created, got \(result)")
        try expect(store.currentDraft?.meal.label == "Breakfast", "expected custom meal label")
        try expect(store.currentDraft?.meal.amountGrams == 150, "expected summed grams")
        try expect(store.currentDraft?.meal.kcal == 321, "expected nutrition from ingredient grams")
        try expect(store.currentDraft?.meal.varianceKcal == 32, "expected honest estimate variance")
        try expect(store.currentDraft?.sourceClass == .measured, "expected measured self-issued draft")
        try expect(store.currentDraft?.trustStatus == .selfIssued, "expected self-issued ingredient draft")
        try expect(store.currentCandidate?.evidence.count == 3, "expected one evidence item per ingredient")
        try expect(store.currentCandidate?.assumptions.contains { $0.id == "ingredient-catalog" } == true, "expected catalog assumption")
        try expect(store.entries.isEmpty, "expected review boundary before save")
        store.confirmDraft()

        try expect(store.entries.count == 1, "expected confirmed custom meal")
        try expect(store.entries.first?.meal.label == "Breakfast", "expected saved custom meal")
    }

    @MainActor
    private static func testIngredientSuggestionsIncludeMilkVariants() async throws {
        let store = FoodWalletStore()

        let rows = store.ingredientSuggestions(for: "MIL")
        let titles = rows.map(\.title)

        try expect(titles.contains("Whole milk"), "expected whole milk suggestion")
        try expect(titles.contains("2% milk"), "expected 2% milk suggestion")
        try expect(titles.contains("Skim milk"), "expected skim milk suggestion")

        let result = store.createIngredientMealDraft(
            title: "Cereal",
            ingredients: [
                FoodMealIngredientInput(name: "2% milk", grams: 240),
            ]
        )
        try expect(result == .created, "expected selected 2% milk to resolve, got \(result)")
        try expect(store.currentCandidate?.evidence.first?.providerID == "milk.2-percent", "expected 2% milk catalog provider")
    }

    @MainActor
    private static func testIngredientSuggestionsIncludeCommonProteins() async throws {
        let store = FoodWalletStore()

        let beefTitles = store.ingredientSuggestions(for: "beef", limit: 8).map(\.title)
        try expect(beefTitles.contains("Cooked ground beef"), "expected ground beef suggestion")
        try expect(beefTitles.contains("Cooked beef steak"), "expected beef steak suggestion")

        let porkTitles = store.ingredientSuggestions(for: "pork", limit: 8).map(\.title)
        try expect(porkTitles.contains("Cooked pork tenderloin"), "expected pork tenderloin suggestion")
        try expect(porkTitles.contains("Cooked pork chop"), "expected pork chop suggestion")

        let eggTitles = store.ingredientSuggestions(for: "egg", limit: 8).map(\.title)
        try expect(eggTitles.first == "Whole egg", "expected whole egg to rank first for egg, got \(eggTitles)")
        try expect(eggTitles.contains("Egg whites"), "expected egg whites suggestion")
        try expect(eggTitles.contains("Boiled egg"), "expected boiled egg suggestion")

        let result = store.createIngredientMealDraft(
            title: "Protein plate",
            ingredients: [
                FoodMealIngredientInput(name: "beef", grams: 100),
                FoodMealIngredientInput(name: "pork", grams: 100),
                FoodMealIngredientInput(name: "egg whites", grams: 100),
            ]
        )
        try expect(result == .created, "expected common proteins to resolve, got \(result)")
    }

    @MainActor
    private static func testBrokerSearchResultCanBecomeReusableIngredient() async throws {
        let store = FoodWalletStore(searchClient: MockBrokerFoodSearchClient())

        await store.searchBrokerFood(query: "beef")
        guard let result = store.brokerFoodSearchRows.first else {
            throw FoodWalletTestFailure("expected broker beef search result")
        }
        let ingredient = store.saveBrokerFoodSearchResultAsPersonalIngredient(id: result.id)
        try expect(ingredient?.name == "Cooked ground beef", "expected broker result to save as personal ingredient")

        let draftResult = store.createIngredientMealDraft(
            title: "Beef bowl",
            ingredients: [
                FoodMealIngredientInput(name: "Cooked ground beef", grams: 100),
            ]
        )
        try expect(draftResult == .created, "expected saved broker ingredient to resolve, got \(draftResult)")
        try expect(store.currentDraft?.meal.label == "Beef bowl", "expected reusable broker-backed draft")
    }

    @MainActor
    private static func testBuildMealSavesReusableRecipeAndQRCode() async throws {
        var publishedLibrary: FoodWalletUserLibraryState?
        let store = FoodWalletStore(
            onUserLibraryChange: { state in
                publishedLibrary = state
            }
        )

        let result = store.createIngredientMealDraft(
            title: "Breakfast",
            ingredients: [
                FoodMealIngredientInput(name: "eggs", grams: 100),
                FoodMealIngredientInput(name: "toast", grams: 40),
                FoodMealIngredientInput(name: "butter", grams: 10),
            ]
        )

        try expect(result == .created, "expected reusable recipe draft, got \(result)")
        try expect(store.savedRecipes.count == 1, "expected build meal to save one recipe")
        guard let recipe = store.savedRecipes.first else {
            throw FoodWalletTestFailure("expected saved recipe")
        }
        try expect(recipe.title == "Breakfast", "expected saved recipe title")
        try expect(publishedLibrary?.recipes.count == 1, "expected user library publish")

        store.discardDraft()
        try expect(store.createRecipeDraft(id: recipe.id, consumedFraction: 1), "expected saved recipe to create later draft")
        try expect(store.currentDraft?.meal.label == "Breakfast", "expected reusable recipe draft label")

        guard let qrText = store.qrPayloadTextForRecipe(id: recipe.id) else {
            throw FoodWalletTestFailure("expected recipe QR payload")
        }
        try expect(qrText.hasPrefix("GR1:"), "expected saved recipe QR to use Grain GR1 transport")
        let decoded = try FoodWalletProtocolQRCodeFactory.payload(fromGR1: qrText)
        try expect(FoodWalletQRFactory.verify(decoded), "expected recipe QR payload to verify")
        try expect(decoded.kind == .recipe, "expected recipe QR payload kind")
        try expect(decoded.issuer?.label == "MealMark self-issued", "expected QR issuer label")
        try expect(decoded.issuer?.keyID.hasPrefix("p256:") == true, "expected QR issuer key fingerprint")
        try expect(decoded.signature?.algorithm == "p256-sha256", "expected QR signature algorithm")
        try expect(decoded.signature?.publicKeyX963Base64.isEmpty == false, "expected QR public key")
        try expect(!qrText.localizedCaseInsensitiveContains("rawPhoto"), "QR payload must not contain raw photo data")
        try expect(!qrText.localizedCaseInsensitiveContains("privateKey"), "QR payload must not contain private key material")

        let updateResult = store.updateSavedRecipe(
            id: recipe.id,
            title: "Breakfast v2",
            ingredients: [
                FoodMealIngredientInput(name: "eggs", grams: 120),
                FoodMealIngredientInput(name: "toast", grams: 40),
            ]
        )
        try expect(updateResult == .created, "expected saved recipe update, got \(updateResult)")
        try expect(store.savedRecipes.first?.title == "Breakfast v2", "expected updated recipe title")
        try expect(store.deleteSavedRecipe(id: recipe.id), "expected saved recipe delete")
        try expect(store.savedRecipes.isEmpty, "expected saved recipe to be removed")
    }

    @MainActor
    private static func testQRCodePayloadImportCreatesReviewableDraft() async throws {
        let sourceStore = FoodWalletStore()
        let createResult = sourceStore.createIngredientMealDraft(
            title: "Breakfast QR",
            ingredients: [
                FoodMealIngredientInput(name: "eggs", grams: 100),
                FoodMealIngredientInput(name: "toast", grams: 40),
            ]
        )
        try expect(createResult == .created, "expected source recipe creation")
        guard let recipe = sourceStore.savedRecipes.first,
              let qrText = sourceStore.qrPayloadTextForRecipe(id: recipe.id) else {
            throw FoodWalletTestFailure("expected QR payload")
        }

        let importStore = FoodWalletStore()
        let preview = try importStore.previewQRCodePayload(qrText)
        try expect(preview.title == "Breakfast QR", "expected QR preview title")
        try expect(preview.signedByLabel.hasPrefix("MealMark self-issued • p256:"), "expected signed QR signer label")
        try expect(preview.sourceLabel == "Signed Grain GR1 serving offer", "expected protocol QR preview label")
        try expect(preview.ingredients.contains { $0.contains("Whole egg") }, "expected QR ingredient preview")

        try importStore.createQRCodeDraft(payloadText: qrText)
        try expect(importStore.savedRecipes.count == 1, "expected QR recipe to be saved into library")
        try expect(importStore.currentDraft?.meal.label == "Breakfast QR", "expected QR draft label")
        try expect(importStore.currentDraft?.trustStatus == .selfIssued, "expected self-issued QR draft")
        try expect(importStore.currentCandidate?.evidence.contains { $0.provider == "mealmark_qr" } == true, "expected QR evidence")

        let replacement: Character = qrText.last == "0" ? "1" : "0"
        let tampered = String(qrText.dropLast()) + String(replacement)
        do {
            _ = try importStore.previewQRCodePayload(tampered)
            throw FoodWalletTestFailure("expected tampered QR to fail")
        } catch is FoodWalletQRImportError {
            // Expected.
        }

        let localPayload = try FoodWalletQRFactory.payload(recipe: recipe)
        let localText = try FoodWalletQRFactory.payloadText(localPayload)
        var signatureTampered = localText.replacingOccurrences(of: "\"signature_der_base64\":\"", with: "\"signature_der_base64\":\"AA")
        if signatureTampered == localText {
            signatureTampered = localText.replacingOccurrences(of: "\"signatureDerBase64\":\"", with: "\"signatureDerBase64\":\"AA")
        }
        do {
            _ = try importStore.previewQRCodePayload(signatureTampered)
            throw FoodWalletTestFailure("expected tampered QR signature to fail")
        } catch FoodWalletQRImportError.integrityMismatch {
            // Expected.
        }

        let protocolOnlyQR = "GR1:6BF-NDJ%B0BD1H2 R2346ATPP*QZOCE+T37W9*R%UD2+OS$CYV4WLOZY84IJ7QTUED/HLSGH-ZHS$C9Y8KKAVQI*RE273Z%J8LA3E2HUS9*K$CJQH30LI0THM68/+6%1H7NG%-VQ+QVQ7P9JQQO% II+QWT7K-5A7EW9HME9R-0CZ7%OEE22AP472BT 2JP51WJCMVRN5%FN%T6.35ZL7ZW01%IY$139QUDTOLBPAD7.8MOORAL%:AZ VSCL$/AMUB5JN:/N0:I: HVQMF*F1PJEKE$9RB19-4O-.NF0N00VH.SC*DPUPHIIMNUJTF7Z0B10BF3Q5"
        do {
            _ = try importStore.previewQRCodePayload(protocolOnlyQR)
            throw FoodWalletTestFailure("expected non-MealMark protocol GR1 QR to require trust material")
        } catch FoodWalletQRImportError.protocolServingOfferRequiresTrust {
            // Expected.
        } catch FoodWalletQRImportError.invalidPayload {
            // Older protocol vectors may use fields MealMark does not import, but they still must not enter the app-local QR path.
        }
    }

    @MainActor
    private static func testCaseinProteinResolvesAsCuratedPowder() async throws {
        let store = FoodWalletStore()

        let result = store.createIngredientMealDraft(
            title: "Casein shake",
            ingredients: [
                FoodMealIngredientInput(name: "casein protein", grams: 30),
            ]
        )

        try expect(result == .created, "expected casein protein to resolve, got \(result)")
        try expect(store.currentDraft?.meal.label == "Casein shake", "expected custom shake label")
        try expect(store.currentDraft?.meal.amountGrams == 30, "expected entered casein grams")
        try expect(store.currentDraft?.meal.kcal == 108, "expected curated casein calories")
        try expect(store.currentDraft?.meal.macronutrients?.proteinGrams == 24, "expected high-protein casein macros")
        try expect(store.currentCandidate?.evidence.contains { $0.providerID == "protein-powder.casein" } == true, "expected curated casein evidence")
        try expect(store.currentCandidate?.assumptions.contains { $0.id == "review-portion" } == true, "expected review boundary")
    }

    @MainActor
    private static func testCustomIngredientCanResolveUnknownFood() async throws {
        let store = FoodWalletStore()

        let firstResult = store.createIngredientMealDraft(
            title: "Granola bowl",
            ingredients: [
                FoodMealIngredientInput(name: "house granola", grams: 40),
            ]
        )
        try expect(firstResult == .unknownIngredient("house granola"), "expected unknown custom ingredient before saving")

        let saveResult = store.savePersonalIngredient(
            name: "House granola",
            servingGrams: 40,
            servingKcal: 180,
            proteinGrams: 5,
            carbohydrateGrams: 24,
            fatGrams: 7,
            fiberGrams: 3
        )
        try expect(saveResult == .saved, "expected personal ingredient save, got \(saveResult)")
        try expect(store.personalIngredients.count == 1, "expected one personal ingredient")

        let secondResult = store.createIngredientMealDraft(
            title: "Granola bowl",
            ingredients: [
                FoodMealIngredientInput(name: "house granola", grams: 40),
                FoodMealIngredientInput(name: "greek yogurt", grams: 150),
            ]
        )

        try expect(secondResult == .created, "expected saved personal ingredient to resolve, got \(secondResult)")
        try expect(store.currentDraft?.meal.amountGrams == 190, "expected summed custom meal grams")
        try expect(store.currentDraft?.meal.kcal == 326, "expected personal plus catalog calories")
        try expect(store.currentDraft?.meal.macronutrients?.proteinGrams == 18.5, "expected personal plus catalog protein")
        try expect(store.currentCandidate?.evidence.contains { $0.provider == "food_wallet_personal_ingredient" } == true, "expected personal ingredient evidence")
        try expect(store.entries.isEmpty, "expected review boundary before save")
    }

    @MainActor
    private static func testTemplatesRecipesAndRecentEntriesCreateDrafts() async throws {
        let store = FoodWalletStore(
            savedTemplates: [
                SavedFoodTemplate(
                    id: "usual-breakfast",
                    title: "Usual breakfast",
                    subtitle: "Greek yogurt, oats, berries, coffee",
                    kcal: 420,
                    varianceKcal: 35,
                    amountGrams: 360,
                    servingGrams: 360,
                    macronutrients: MealMacronutrients(
                        proteinGrams: 31,
                        carbohydrateGrams: 54,
                        fatGrams: 10,
                        fiberGrams: 8
                    )
                ),
            ],
            savedRecipes: []
        )

        try expect(store.createTemplateDraft(id: "usual-breakfast"), "expected explicit template draft")
        try expect(store.currentDraft?.meal.label == "Usual breakfast", "expected template label")
        try expect(store.currentDraft?.trustStatus == .selfIssued, "expected template to be self-issued")
        store.confirmDraft()
        try expect(store.createRecentEntryDraft(entryID: store.entries.first!.entryID), "expected recent entry draft")
        try expect(store.currentDraft?.meal.label == "Usual breakfast", "expected recent entry label")
        try expect(store.currentDraft?.trustStatus == .selfIssued, "expected recent repeat to be self-issued")
    }

    @MainActor
    private static func testCopyDateEntriesRepeatsMealsIntoCurrentDay() async throws {
        let clock = MutableFoodWalletClock(now: Date(timeIntervalSince1970: 1_700_000_000))
        let store = FoodWalletStore(
            wallet: GrainFoodWallet(clock: clock),
            savedTemplates: [
                SavedFoodTemplate(
                    id: "usual-breakfast",
                    title: "Usual breakfast",
                    subtitle: "Greek yogurt, oats, berries, coffee",
                    kcal: 420,
                    varianceKcal: 35,
                    amountGrams: 360,
                    servingGrams: 360,
                    macronutrients: MealMacronutrients(
                        proteinGrams: 31,
                        carbohydrateGrams: 54,
                        fatGrams: 10,
                        fiberGrams: 8
                    )
                ),
            ],
            savedRecipes: []
        )

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
    private static func testVisibleLabelDraftExposesProviderEvidence() async throws {
        let store = FoodWalletStore()

        try expect(store.createVisibleLabelDraft(label: "Bottle label", caloriesPerContainer: 80, grams: 473), "expected visible label draft")
        try expect(store.currentCandidate?.nutrition.minKcal == 80, "expected exact label calories")
        try expect(store.currentCandidate?.nutrition.maxKcal == 80, "expected exact label calories")
        try expect(store.currentCandidate?.confidence == .high, "expected high confidence for explicit label")
        try expect(store.currentCandidate?.evidence.contains { $0.provider == "visible_nutrition_label" } == true, "expected visible label evidence")
    }

    @MainActor
    private static func testStoreRestoresInjectedEntries() async throws {
        let source = FoodWalletStore()
        try expect(source.createQuickTextDraft("2 eggs and toast"), "expected source draft")
        source.confirmDraft()

        let restored = FoodWalletStore(entries: source.entries)

        try expect(restored.entries.count == 1, "expected restored entry")
        try expect(restored.entries.first?.entryID == source.entries.first?.entryID, "expected stable restored entry id")
        try expect(restored.safeSummary.totals.entryCount == 1, "expected restored safe summary")
        try expect(restored.safeSummary.entries.first?.label == "2 eggs and toast", "expected restored safe summary label")
    }

    @MainActor
    private static func testEntryChangeCallbackFiresForDurableMutations() async throws {
        let clock = MutableFoodWalletClock(now: Date(timeIntervalSince1970: 1_700_000_000))
        var snapshots: [[String]] = []
        let store = FoodWalletStore(
            wallet: GrainFoodWallet(clock: clock),
            onEntriesChange: { entries in
                snapshots.append(entries.map(\.entryID))
            }
        )

        try expect(store.createQuickTextDraft("apple"), "expected draft")
        store.confirmDraft()
        let sourceDateKey = store.entries.first!.dateKey

        clock.nowDate = clock.nowDate.addingTimeInterval(86_400)
        _ = store.copyEntries(fromDateKey: sourceDateKey)

        let bundle = try store.exportPortableBundle(generatedAt: Date(timeIntervalSince1970: 10))
        let imported = FoodWalletStore()
        try imported.importPortableBundle(bundle)
        store.resetLocalData()

        try expect(snapshots.count == 3, "expected confirm, copy, reset callbacks")
        try expect(snapshots[0].count == 1, "expected confirm callback with one entry")
        try expect(snapshots[1].count == 2, "expected copy callback with two entries")
        try expect(snapshots[2].isEmpty, "expected reset callback with no entries")
    }

    @MainActor
    private static func testStoreEditsConfirmedEntryAndPublishesDerivedState() async throws {
        var snapshots: [[FoodIntakeEntry]] = []
        let store = FoodWalletStore(onEntriesChange: { entries in
            snapshots.append(entries)
        })

        try expect(store.createVisibleLabelDraft(label: "Bottle label", caloriesPerContainer: 80, grams: 473), "expected label draft")
        store.confirmDraft()
        let original = store.entries.first!

        try expect(store.updateEntry(entryID: original.entryID, label: "Bottle label", gramsMode: 946), "expected edit")

        let edited = store.entries.first!
        try expect(edited.entryID == original.entryID, "expected stable entry id")
        try expect(edited.draftID == original.draftID, "expected stable draft id")
        try expect(edited.confirmedAt == original.confirmedAt, "expected stable confirmation date")
        try expect(edited.dateKey == original.dateKey, "expected stable date key")
        try expect(edited.sourceClass == original.sourceClass, "expected source class to be preserved")
        try expect(edited.trustStatus == original.trustStatus, "expected trust status to be preserved")
        try expect(edited.meal.amountGrams == 946, "expected edited grams")
        try expect(edited.meal.kcal == 160, "expected edited kcal")
        try expect(store.safeSummary.totals.sumMeanKcal == 160, "expected safe summary to update")
        try expect(store.todayTotalLabel == "160 kcal", "expected today label to update")
        try expect(store.exportCSV().contains("946"), "expected CSV to include edited grams")
        try expect(snapshots.count == 2, "expected confirm and edit callbacks")
        try expect(snapshots.last?.first?.meal.amountGrams == 946, "expected edit callback with updated grams")
    }

    @MainActor
    private static func testStoreDeletesConfirmedEntryAndPublishesDerivedState() async throws {
        var snapshots: [[FoodIntakeEntry]] = []
        let store = FoodWalletStore(onEntriesChange: { entries in
            snapshots.append(entries)
        })

        try expect(store.createQuickTextDraft("apple"), "expected first draft")
        store.confirmDraft()
        let deletedID = store.entries.first!.entryID
        try expect(store.createQuickTextDraft("toast"), "expected second draft")
        store.confirmDraft()

        try expect(store.deleteEntry(entryID: deletedID), "expected delete")
        try expect(store.entries.count == 1, "expected one entry after delete")
        try expect(!store.entries.contains { $0.entryID == deletedID }, "expected deleted id to be absent")
        try expect(store.safeSummary.totals.entryCount == 1, "expected safe summary count to update")
        try expect(!store.exportCSV().contains("apple"), "expected CSV to omit deleted label")
        try expect(snapshots.count == 3, "expected two confirm callbacks and one delete callback")
        try expect(snapshots.last?.count == 1, "expected delete callback with one entry")
        try expect(!store.deleteEntry(entryID: "missing-entry"), "expected missing delete to fail")
    }

    @MainActor
    private static func testPortableBundleHasDeterministicIntegrityMetadataAndSummaries() async throws {
        let store = FoodWalletStore()
        try expect(store.createQuickTextDraft("apple"), "expected quick text draft")
        store.confirmDraft()
        try expect(store.createVisibleLabelDraft(label: "Bottle label", caloriesPerContainer: 80, grams: 473), "expected label draft")
        store.confirmDraft()

        let generatedAt = Date(timeIntervalSince1970: 1_700_000_123)
        let first = try store.exportPortableBundle(generatedAt: generatedAt)
        let second = try store.exportPortableBundle(generatedAt: generatedAt)

        try expect(first.manifest.contentSha256 == second.manifest.contentSha256, "expected deterministic content hash")
        try expect(first.manifest.contentDigestID == second.manifest.contentDigestID, "expected deterministic digest id")
        try expect(first.manifest.contentSha256.count == 64, "expected content SHA-256")
        try expect(FoodWalletExportFactory.verifyIntegrity(first), "expected first bundle integrity")
        try expect(FoodWalletExportFactory.verifyIntegrity(second), "expected second bundle integrity")
        try expect(first.summary.sourceClassCounts["measured"] == 2, "expected measured source summary")
        try expect(first.summary.trustStatusCounts["self_issued"] == 2, "expected self-issued trust summary")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let json = String(decoding: try encoder.encode(first), as: UTF8.self)
        let forbidden = ["rawPhoto", "photoBytes", "photoBase64", "imageBytes", "snapshotB64", "bundleB64", "privateKey", "trustPub", "COSE", "CBOR", "GR1"]
        for token in forbidden {
            try expect(!json.localizedCaseInsensitiveContains(token), "portable bundle leaked \(token)")
        }
    }

    @MainActor
    private static func testImportPreviewValidatesAndMergeIsIdempotent() async throws {
        let source = FoodWalletStore()
        try expect(source.createQuickTextDraft("apple"), "expected source draft")
        source.confirmDraft()
        let bundle = try source.exportPortableBundle(generatedAt: Date(timeIntervalSince1970: 42))

        let target = FoodWalletStore()
        let preview = try target.previewPortableImport(bundle)

        try expect(preview.integrityVerified, "expected import preview to be valid")
        try expect(preview.entryCount == 1, "expected one preview entry")
        try expect(preview.newEntryCount == 1, "expected one new preview entry")
        try expect(preview.duplicateEntryCount == 0, "expected no duplicate before import")
        try expect(preview.sourceClassSummary["measured"] == 1, "expected measured preview summary")

        let firstImport = try target.importPortableBundle(bundle)
        let secondImport = try target.importPortableBundle(bundle)

        try expect(firstImport.importedEntryCount == 1, "expected first import to merge one entry")
        try expect(secondImport.importedEntryCount == 0, "expected second import to be idempotent")
        try expect(secondImport.duplicateEntryCount == 1, "expected second import to report duplicate")
        try expect(target.entries.count == 1, "expected target to keep one imported entry")
        try expect(target.entries.first?.entryID == source.entries.first?.entryID, "expected imported entry id")
    }

    @MainActor
    private static func testPortableExportIncludesSafeUserDataOnly() async throws {
        let store = FoodWalletStore()

        try expect(store.createQuickTextDraft("2 eggs and toast"), "expected quick text draft")
        store.confirmDraft()
        try expect(store.createIngredientMealDraft(
            title: "Tomato cucumber salad",
            ingredients: [
                FoodMealIngredientInput(name: "tomato", grams: 180),
                FoodMealIngredientInput(name: "cucumber", grams: 160),
                FoodMealIngredientInput(name: "olive oil", grams: 24),
                FoodMealIngredientInput(name: "herbs", grams: 56),
            ]
        ) == .created, "expected custom salad draft")
        store.confirmDraft()

        let bundle = try store.exportPortableBundle()
        try expect(bundle.schema == "grain.food-wallet.bundle.v1", "expected portable bundle schema")
        try expect(bundle.entries.count == 2, "expected two exported entries")
        try expect(bundle.templates.isEmpty, "expected no fake templates in export")
        try expect(bundle.recipes.count == 1, "expected build meal recipe metadata in export")
        try expect(bundle.recipes.first?.title == "Tomato cucumber salad", "expected saved recipe title in export")
        try expect(bundle.manifest.contentSha256.count == 64, "expected SHA-256 checksum")
        try expect(FoodWalletExportFactory.verifyIntegrity(bundle), "expected export integrity")

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
    private static func testPortableExportIncludesUserLibraryEvidenceMetadata() async throws {
        let store = FoodWalletStore(
            savedTemplates: [sampleSavedTemplate()],
            savedRecipes: [sampleSavedRecipe()]
        )
        try expect(store.savePersonalIngredient(
            name: "House granola",
            servingGrams: 40,
            servingKcal: 180,
            proteinGrams: 5,
            carbohydrateGrams: 24,
            fatGrams: 7,
            fiberGrams: 3
        ) == .saved, "expected personal ingredient save")

        try expect(store.createTemplateDraft(id: "usual-breakfast"), "expected template draft")
        store.confirmDraft()

        let bundle = try store.exportPortableBundle(generatedAt: Date(timeIntervalSince1970: 1_700_001_000))
        try expect(bundle.templates.count == 1, "expected template metadata")
        try expect(bundle.recipes.count == 1, "expected recipe metadata")
        try expect(bundle.personalFoods?.count == 1, "expected personal food metadata")
        try expect(bundle.manifest.templateCount == 1, "expected template manifest count")
        try expect(bundle.manifest.recipeCount == 1, "expected recipe manifest count")
        try expect(bundle.manifest.personalFoodCount == 1, "expected personal food manifest count")
        try expect(bundle.templates.first?.evidenceProvider == "food_wallet_template", "expected template evidence provider")
        try expect(bundle.recipes.first?.ingredientDetails?.first?.label == "Plain Greek yogurt", "expected recipe ingredient details")
        try expect(bundle.personalFoods?.first?.evidenceProvider == "food_wallet_personal_ingredient", "expected personal food evidence provider")
        try expect(bundle.personalFoods?.first?.servingBasis == "user_entered_nutrition_label", "expected personal food serving basis")
        try expect(FoodWalletExportFactory.verifyIntegrity(bundle), "expected user-library bundle integrity")

        let json = String(decoding: try FoodWalletExportFactory.jsonData(bundle), as: UTF8.self)
        for token in ["rawPhoto", "photoBytes", "photoBase64", "imageBytes", "snapshotB64", "bundleB64", "privateKey", "trustPub", "COSE", "CBOR", "GR1"] {
            try expect(!json.localizedCaseInsensitiveContains(token), "user library export leaked \(token)")
        }
    }

    private static func testUserLibraryCodecMigratesLegacyPersonalIngredients() throws {
        let legacyIngredient = PersonalFoodIngredient(
            id: "personal-house-granola",
            name: "House granola",
            sourceServingGrams: 40,
            sourceServingKcal: 180,
            kcalPer100Grams: 450,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 12.5,
                carbohydrateGrams: 60,
                fatGrams: 17.5,
                fiberGrams: 7.5
            )
        )
        let legacyData = try JSONEncoder().encode([legacyIngredient])
        let decoded = try FoodWalletUserLibraryCodec.decode(legacyData)

        try expect(decoded.schema == "grain.food-wallet.user-library.v1", "expected migrated library schema")
        try expect(decoded.version == 1, "expected migrated library version")
        try expect(decoded.templates.isEmpty, "expected empty migrated templates")
        try expect(decoded.recipes.isEmpty, "expected empty migrated recipes")
        try expect(decoded.personalIngredients == [legacyIngredient], "expected migrated personal ingredients")
    }

    private static func testUserLibraryCodecDefaultsMissingCollections() throws {
        let data = Data(
            """
            {
              "schema": "grain.food-wallet.user-library.v1",
              "version": 1,
              "personal_ingredients": []
            }
            """.utf8
        )
        let decoded = try FoodWalletUserLibraryCodec.decode(data)

        try expect(decoded.templates.isEmpty, "expected missing templates to default empty")
        try expect(decoded.recipes.isEmpty, "expected missing recipes to default empty")
        try expect(decoded.personalIngredients.isEmpty, "expected explicit empty personal ingredients")
        try expect(decoded.isEmpty, "expected defaulted user library to be empty")
    }

    @MainActor
    private static func testStoreRestoresDurableEntriesAndPublishesLedgerChanges() async throws {
        let seed = FoodWalletStore()
        try expect(seed.createQuickTextDraft("2 eggs and toast"), "expected seed draft")
        seed.confirmDraft()
        let restoredEntries = seed.entries

        var publishedCounts: [Int] = []
        let restored = FoodWalletStore(
            entries: restoredEntries,
            onEntriesChange: { entries in
                publishedCounts.append(entries.count)
            }
        )

        try expect(restored.entries.count == 1, "expected restored entry")
        try expect(restored.safeSummary.totals.entryCount == 1, "expected restored safe summary")
        try expect(restored.todayTotalLabel != "No meals saved yet", "expected restored total label")

        try expect(restored.createQuickTextDraft("apple"), "expected second draft")
        restored.confirmDraft()
        try expect(restored.entries.count == 2, "expected restored store to append entries")
        try expect(publishedCounts == [2], "expected one entry-change publication after append")

        restored.resetLocalData()
        try expect(restored.entries.isEmpty, "expected reset to clear restored entries")
        try expect(publishedCounts == [2, 0], "expected reset to publish empty ledger")
    }

    @MainActor
    private static func testLocalLedgerCodecRoundTripsEntries() async throws {
        let store = FoodWalletStore()
        try expect(store.createQuickTextDraft("apple"), "expected draft")
        store.confirmDraft()

        let data = try FoodWalletLocalLedgerCodec.encodeEntries(store.entries)
        let decoded = try FoodWalletLocalLedgerCodec.decodeEntries(data)

        try expect(decoded == store.entries, "expected local ledger codec to preserve entries")
        let text = String(decoding: data, as: UTF8.self)
        for token in ["rawPhoto", "photoBytes", "snapshotB64", "bundleB64", "privateKey", "trustPub", "GR1"] {
            try expect(!text.localizedCaseInsensitiveContains(token), "local ledger leaked \(token)")
        }
    }

    @MainActor
    private static func testPortableBundleHasVerifiableIntegrityAndProvenance() async throws {
        let store = FoodWalletStore()
        try expect(store.createQuickTextDraft("apple"), "expected estimated draft")
        store.confirmDraft()
        try expect(store.createVerifiedServingOfferDraft(), "expected verified draft")
        store.confirmDraft()

        let bundle = try store.exportPortableBundle()

        try expect(bundle.schema == "grain.food-wallet.bundle.v1", "expected Grain portable bundle schema")
        try expect(bundle.manifest.contentSha256.count == 64, "expected content hash")
        try expect(bundle.manifest.contentDigestID == "sha256:\(bundle.manifest.contentSha256)", "expected digest id to bind hash")
        try expect(bundle.manifest.signature?.algorithm == "p256-sha256", "expected self-issued signature")
        try expect(bundle.manifest.trustStatusSummary["verified"] == 1, "expected verified provenance count")
        try expect(bundle.manifest.trustStatusSummary["self_issued"] == 1, "expected self-issued provenance count")
        try expect(bundle.manifest.sourceClassSummary["attested"] == 1, "expected attested source count")
        try expect(bundle.manifest.sourceClassSummary["measured"] == 1, "expected measured source count")
        try expect(FoodWalletExportFactory.verifyIntegrity(bundle), "expected bundle integrity to verify")
    }

    @MainActor
    private static func testPortableImportPreviewsAndMergesIdempotently() async throws {
        let source = FoodWalletStore()
        try expect(source.createQuickTextDraft("apple"), "expected source draft")
        source.confirmDraft()
        let data = try source.exportPortableJSON()

        var publishedCounts: [Int] = []
        let target = FoodWalletStore(onEntriesChange: { entries in
            publishedCounts.append(entries.count)
        })

        let preview = try target.previewPortableImport(data)
        try expect(preview.entryCount == 1, "expected one import entry")
        try expect(preview.newEntryCount == 1, "expected one new entry")
        try expect(preview.duplicateEntryCount == 0, "expected no duplicates")
        try expect(preview.integrityVerified, "expected verified bundle integrity")
        try expect(preview.dateRange != nil, "expected date range")

        let firstImport = try target.importPortableBundle(data)
        try expect(firstImport.importedEntryCount == 1, "expected one imported entry")
        try expect(firstImport.duplicateEntryCount == 0, "expected no duplicate on first import")
        try expect(target.entries == source.entries, "expected imported entries to match source")

        let secondPreview = try target.previewPortableImport(data)
        try expect(secondPreview.newEntryCount == 0, "expected no new entries after import")
        try expect(secondPreview.duplicateEntryCount == 1, "expected duplicate preview after import")

        let secondImport = try target.importPortableBundle(data)
        try expect(secondImport.importedEntryCount == 0, "expected idempotent re-import")
        try expect(secondImport.duplicateEntryCount == 1, "expected duplicate count on re-import")
        try expect(publishedCounts == [1], "expected only first import to publish a ledger change")
    }

    @MainActor
    private static func testPortableImportRejectsTamperedBundle() async throws {
        let source = FoodWalletStore()
        try expect(source.createQuickTextDraft("apple"), "expected source draft")
        source.confirmDraft()
        let original = String(decoding: try source.exportPortableJSON(), as: UTF8.self)
        let tampered = original.replacingOccurrences(of: "apple", with: "pear")

        let target = FoodWalletStore()
        try expectImportError(.integrityMismatch) {
            try target.previewPortableImport(Data(tampered.utf8))
        }
        try expect(target.entries.isEmpty, "expected tampered import to write nothing")
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
    private static func testStorePublishesNoFoodStateWithoutDraft() async throws {
        let store = FoodWalletStore(analysisClient: NoFoodFoodAnalysisClient())

        await store.analyze(photo: .uiTestFujiApple)

        try expect(store.analysisState.isFailed, "expected no-food to use recoverable failed state")
        try expect(store.analysisState.statusText == "No food found", "expected no-food status")
        try expect(store.analysisState.errorMessage?.localizedCaseInsensitiveContains("tabletop") == true, "expected no-food reason")
        try expect(store.currentDraft == nil, "expected no draft after no-food analysis")
        try expect(store.currentCandidate == nil, "expected no candidate after no-food analysis")
        try expect(!store.canSaveDraft, "expected no-food state to disable saving")
    }

    @MainActor
    private static func testStorePublishesTimeoutStateWithoutDraft() async throws {
        let store = FoodWalletStore(
            analysisClient: SlowFoodAnalysisClient(delayNanoseconds: 200_000_000),
            slowAnalysisThresholdNanoseconds: 20_000_000,
            analysisTimeoutNanoseconds: 60_000_000
        )

        let task = Task {
            await store.analyze(photo: .uiTestFujiApple)
        }
        try await Task.sleep(nanoseconds: 90_000_000)

        try expect(store.analysisState.isFailed, "expected timeout to publish failed state")
        try expect(store.analysisState.errorMessage?.localizedCaseInsensitiveContains("too long") == true, "expected timeout message")
        try expect(store.currentDraft == nil, "expected no draft after timeout")
        try expect(store.currentCandidate == nil, "expected no candidate after timeout")

        await task.value
        try expect(store.analysisState.isFailed, "expected late result to be ignored after timeout")
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
    private static func testStoreRefreshesLocalEntriesWithoutPublishingWriteback() async throws {
        let source = FoodWalletStore()
        try expect(source.createQuickTextDraft("apple"), "expected source draft")
        source.confirmDraft()
        let restoredEntries = source.entries
        var writebackCount = 0
        let store = FoodWalletStore(
            onEntriesChange: { _ in
                writebackCount += 1
            },
            onEntriesReload: {
                restoredEntries
            }
        )

        await store.refreshLocalState()

        try expect(store.entries.count == 1, "expected refresh to load durable entries")
        try expect(store.safeSummary.totals.entryCount == 1, "expected refresh to rebuild safe summary")
        try expect(writebackCount == 0, "expected refresh to avoid writeback callback")
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

private func sampleSavedTemplate() -> SavedFoodTemplate {
    SavedFoodTemplate(
        id: "usual-breakfast",
        title: "Usual breakfast",
        subtitle: "Greek yogurt, oats, berries, coffee",
        kcal: 420,
        varianceKcal: 35,
        amountGrams: 360,
        servingGrams: 360,
        macronutrients: MealMacronutrients(
            proteinGrams: 31,
            carbohydrateGrams: 54,
            fatGrams: 10,
            fiberGrams: 8
        )
    )
}

private func sampleSavedRecipe() -> SavedFoodRecipe {
    SavedFoodRecipe(
        id: "granola-bowl",
        title: "Granola bowl",
        subtitle: "Batch recipe",
        totalGrams: 520,
        totalKcal: 720,
        macronutrients: MealMacronutrients(
            proteinGrams: 35,
            carbohydrateGrams: 92,
            fatGrams: 24,
            fiberGrams: 18
        ),
        ingredients: [
            SavedFoodRecipeIngredient(id: "greek-yogurt", label: "Plain Greek yogurt", grams: 300, kcal: 291),
            SavedFoodRecipeIngredient(id: "oats", label: "Rolled oats", grams: 80, kcal: 311),
        ]
    )
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
    var path: String?
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

private struct NoFoodFoodAnalysisClient: FoodAnalysisClient {
    func estimate(example: FoodCaptureExample) async throws -> FoodAnalysisCandidate {
        throw noFoodError()
    }

    func estimate(photo: CapturedMealPhoto) async throws -> FoodAnalysisCandidate {
        throw noFoodError()
    }

    func estimate(photoPayload: TransientMealPhotoPayload) async throws -> FoodAnalysisCandidate {
        throw noFoodError()
    }

    private func noFoodError() -> FoodAnalysisBrokerClientError {
        .brokerError(
            code: "NO_FOOD_DETECTED",
            message: "A tabletop is visible, but no food or nutrition label is visible.",
            status: 422
        )
    }
}

private struct StaticFoodSearchClient: BrokerFoodSearchClient {
    var results: [BrokerFoodSearchResult]

    func searchFood(_ request: BrokerFoodSearchRequest) async throws -> [BrokerFoodSearchResult] {
        results
    }
}

private func brokerClient(
    handler: @escaping @Sendable (URLRequest) throws -> BrokerResponse
) -> FoodAnalysisBrokerClient {
    BrokerURLProtocol.setHandler(handler)
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [BrokerURLProtocol.self]
    return FoodAnalysisBrokerClient(
        endpoint: URL(string: "https://broker.example.test/v1/food/analyze-photo")!,
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

private func brokerSearchEnvelopeJSON() -> Data {
    Data(
        """
        {
          "ok": true,
          "request_id": "barcode-fixture-001",
          "barcode": "012345678905",
          "results": [
            {
              "result_id": "food-search:fixture-kombucha-bottle",
              "primary_label": "Ginger lemon kombucha",
              "generic_label": "kombucha",
              "brand_label": "Grain Fixture Kitchen",
              "category": "packaged_beverage",
              "source_label": "deterministic_fixture",
              "trust_label": "barcode_fixture",
              "match": {
                "type": "barcode",
                "score": 1
              },
              "serving": {
                "basis": "per_100g",
                "serving_size_g": 473,
                "serving_label": "1 bottle (473 ml)"
              },
              "nutrition": {
                "per_100g": {
                  "kcal": 17,
                  "protein_g": 0,
                  "carbohydrate_g": 4.2,
                  "fat_g": 0,
                  "fiber_g": 0
                }
              },
              "provider_evidence": [
                {
                  "provider": "deterministic_fixture",
                  "provider_id": "012345678905",
                  "matched_name": "Ginger lemon kombucha",
                  "match_type": "barcode",
                  "source_label": "curated_fixture",
                  "trust_label": "barcode_fixture"
                }
              ],
              "user_confirmation_required": true
            }
          ]
        }
        """.utf8
    )
}

private func brokerErrorJSON(code: String, message: String) -> Data {
    Data(
        """
        {
          "ok": false,
          "error": {
            "code": "\(code)",
            "message": "\(message)",
            "request_id": "broker-error-fixture"
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
