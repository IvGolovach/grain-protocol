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
        await run("mealMarkPlusEntitlementUsageModels") {
            try testMealMarkPlusEntitlementUsageModels()
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
        await run("brokerClientAddsBearerToken") {
            try await testBrokerClientAddsBearerToken()
        }
        await run("brokerClientUsesSessionTokenProvider") {
            try await testBrokerClientUsesSessionTokenProvider()
        }
        await run("accountClientRequestsBuildBootstrapMeAndStoreKitRequests") {
            try testAccountClientRequestsBuildBootstrapMeAndStoreKitRequests()
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
        await run("brokerDecodesEntitlementRequired429") {
            try await testBrokerDecodesEntitlementRequired429()
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
        await run("storeBarcodeSearchRequestsSingleExactResult") {
            try await testStoreBarcodeSearchRequestsSingleExactResult()
        }
        await run("todaySummaryPrimaryLabelUsesLoggedCalories") {
            try testTodaySummaryPrimaryLabelUsesLoggedCalories()
        }
        await run("brokerNameSearchDoesNotClaimBarcodeAssumption") {
            try testBrokerNameSearchDoesNotClaimBarcodeAssumption()
        }
        await run("storeReportsUnavailableBarcodeLookupWithoutBroker") {
            try await testStoreReportsUnavailableBarcodeLookupWithoutBroker()
        }
        await run("storeConfirmsOnlyAfterDraftReview") {
            try await testStoreConfirmsOnlyAfterDraftReview()
        }
        await run("typedFoodDraftCreatesFromKnownSearchResult") {
            try await testTypedFoodDraftCreatesFromKnownSearchResult()
        }
        await run("typedFoodDraftRejectsUnknownFoodWithoutFakeNutrition") {
            try await testTypedFoodDraftRejectsUnknownFoodWithoutFakeNutrition()
        }
        await run("addFoodSearchSuggestionsPreferCatalogMatches") {
            try await testAddFoodSearchSuggestionsPreferCatalogMatches()
        }
        await run("addFoodSearchSuggestionsIncludeMacadamiaNuts") {
            try await testAddFoodSearchSuggestionsIncludeMacadamiaNuts()
        }
        await run("ingredientLookupDoesNotResolveSubstringMatches") {
            try await testIngredientLookupDoesNotResolveSubstringMatches()
        }
        await run("ingredientSuggestionsDoNotMatchInsideWords") {
            try await testIngredientSuggestionsDoNotMatchInsideWords()
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
        await run("customQRCodeIssuerLabelIsSignedInsideGR1") {
            try await testCustomQRCodeIssuerLabelIsSignedInsideGR1()
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
        await run("storeSanitizesProviderConfigurationFailure") {
            try await testStoreSanitizesProviderConfigurationFailure()
        }
        await run("storePublishesEntitlementRequiredFailure") {
            try await testStorePublishesEntitlementRequiredFailure()
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
        await run("notRequestedPrivacyRequiresExplicitConsent") {
            try await testNotRequestedPrivacyRequiresExplicitConsent()
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

    private static func testMealMarkPlusEntitlementUsageModels() throws {
        let decoder = JSONDecoder()
        let legacyTier = try decoder.decode(SubscriptionTier.self, from: Data(#""pro""#.utf8))
        let plusTier = try decoder.decode(SubscriptionTier.self, from: Data(#""plus""#.utf8))

        try expect(legacyTier == .plus, "expected legacy pro tier to decode as MealMark Plus")
        try expect(plusTier == .plus, "expected plus tier alias to decode")
        try expect(SubscriptionTier.plus.rawValue == "pro", "expected broker-compatible tier wire value")
        try expect(SubscriptionTier.plus.label == "MealMark Plus", "expected consumer-facing Plus label")
        try expect(MealMarkPlusProductID.recognizes("dev.grain.foodwallet.plus.monthly"), "expected monthly product")
        try expect(MealMarkPlusProductID.recognizes("dev.grain.foodwallet.plus.yearly"), "expected yearly product")

        let usage = MealMarkUsageSnapshot(
            feature: .photoAnalysis,
            limit: 500,
            used: 37,
            resetAtMs: 1_800_000_000_000
        )
        let entitlement = MealMarkEntitlement.storeKitPlus(
            productID: .monthly,
            originalTransactionID: "orig-transaction-1",
            effectiveAtMs: 1_700_000_000_000,
            expiresAtMs: 1_900_000_000_000,
            updatedAtMs: 1_750_000_000_000
        )
        let subscription = SubscriptionState(entitlement: entitlement, usage: [usage])

        try expect(entitlement.isPlus, "expected plus entitlement")
        try expect(entitlement.isActive(nowMs: 1_800_000_000_000), "expected active entitlement")
        try expect(subscription.tier == .plus, "expected subscription tier from entitlement")
        try expect(subscription.monthlyPhotoEstimateLimit == 500, "expected photo limit from usage")
        try expect(subscription.usedPhotoEstimates == 37, "expected used count from usage")
        try expect(subscription.remainingPhotoEstimates == 463, "expected remaining photo estimates")
        try expect(subscription.summary == "MealMark Plus: 463 photo estimates left", "expected Plus summary")
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

        let store = FoodWalletStore(privacy: .granted)
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

    private static func testBrokerClientAddsBearerToken() async throws {
        let jpegBytes = Data([0xff, 0xd8])
        let capture = BrokerRequestCapture()
        let client = brokerClient(bearerToken: "dev-token") { request in
            capture.authorization = request.value(forHTTPHeaderField: "Authorization")
            return BrokerResponse(statusCode: 200, body: brokerEnvelopeJSON(userConfirmationRequired: true))
        }

        _ = try await client.estimate(photoPayload: TransientMealPhotoPayload(photo: .uiTestFujiApple, jpegData: jpegBytes))

        try expect(capture.authorization == "Bearer dev-token", "expected broker bearer token header")
    }

    private static func testBrokerClientUsesSessionTokenProvider() async throws {
        let tokenStore = InMemoryFoodWalletSessionTokenStore(token: "session-token")
        let provider = FoodWalletSessionAuthorizationProvider(tokenStore: tokenStore)
        let capture = BrokerRequestCapture()
        let client = brokerClient(authorizationProvider: provider) { request in
            capture.authorization = request.value(forHTTPHeaderField: "Authorization")
            return BrokerResponse(statusCode: 200, body: brokerSearchEnvelopeJSON())
        }

        _ = try await client.searchFood(BrokerFoodSearchRequest(query: "apple"))

        try expect(capture.authorization == "Bearer session-token", "expected broker session token header")
    }

    private static func testAccountClientRequestsBuildBootstrapMeAndStoreKitRequests() throws {
        let baseURL = URL(string: "https://mealmark.example.test/api")!
        let bootstrap = FoodWalletAccountBootstrapRequest(
            deviceIDHash: "device-abc",
            appAccountToken: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
            appVersion: "1.2.3",
            buildNumber: "45",
            localeIdentifier: "en_US",
            storefrontCountryCode: "US",
            clientGeneratedAtMs: 1_800_000_000_000
        )
        let bootstrapClientRequest = try bootstrap.clientRequest()
        let bootstrapURLRequest = try bootstrapClientRequest.urlRequest(baseURL: baseURL)
        let bootstrapBody = try JSONSerialization.jsonObject(
            with: bootstrapClientRequest.body ?? Data()
        ) as? [String: Any]

        try expect(bootstrapClientRequest.method == "POST", "expected bootstrap POST")
        try expect(bootstrapClientRequest.path == "/v1/auth/bootstrap", "expected bootstrap path")
        try expect(!bootstrapClientRequest.requiresSessionToken, "expected bootstrap without session token")
        try expect(bootstrapURLRequest.url?.path == "/api/v1/auth/bootstrap", "expected base path preservation")
        try expect(bootstrapURLRequest.value(forHTTPHeaderField: "Content-Type") == "application/json", "expected JSON content type")
        try expect(bootstrapBody?["device_id_hash"] as? String == "device-abc", "expected device id hash in bootstrap body")
        try expect(bootstrapBody?["app_account_token"] as? String == "11111111-1111-4111-8111-111111111111", "expected app account token")
        try expect(bootstrapBody?["app_bundle_id"] as? String == "dev.grain.foodwallet", "expected bundle id")
        try expect(bootstrapBody?["client_generated_at_ms"] as? Int == 1_800_000_000_000, "expected client timestamp")

        let meClientRequest = FoodWalletAccountMeRequest().clientRequest()
        do {
            _ = try meClientRequest.urlRequest(baseURL: baseURL)
            throw FoodWalletTestFailure("expected missing session token error")
        } catch let error as FoodWalletAccountClientError {
            try expect(error == .missingSessionToken, "expected missing token error")
        }
        let meURLRequest = try meClientRequest.urlRequest(baseURL: baseURL, sessionToken: " session-token ")
        try expect(meClientRequest.method == "GET", "expected me GET")
        try expect(meClientRequest.path == "/v1/account/me", "expected me path")
        try expect(meClientRequest.requiresSessionToken, "expected me to require session")
        try expect(meURLRequest.value(forHTTPHeaderField: "Authorization") == "Bearer session-token", "expected trimmed bearer token")

        let transaction = FoodWalletStoreKitTransactionRequest(signedTransactionInfo: "signed-storekit-jws")
        let transactionClientRequest = try transaction.clientRequest()
        let transactionURLRequest = try transactionClientRequest.urlRequest(baseURL: baseURL, sessionToken: "session-token")
        let transactionBody = try JSONSerialization.jsonObject(
            with: transactionClientRequest.body ?? Data()
        ) as? [String: Any]

        try expect(transactionClientRequest.method == "POST", "expected transaction POST")
        try expect(transactionClientRequest.path == "/v1/storekit/transactions", "expected transaction path")
        try expect(transactionClientRequest.requiresSessionToken, "expected transaction to require session")
        try expect(transactionURLRequest.url?.path == "/api/v1/storekit/transactions", "expected transaction URL")
        try expect(transactionBody?["signed_transaction_info"] as? String == "signed-storekit-jws", "expected signed transaction")
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

    private static func testBrokerDecodesEntitlementRequired429() async throws {
        let client = brokerClient { _ in
            BrokerResponse(statusCode: 429, body: brokerRateLimitErrorJSON(
                feature: "photo_analysis",
                limit: 10,
                used: 11,
                resetAtMs: 1_800_000_000_000,
                entitlementRequired: true
            ))
        }
        let payload = TransientMealPhotoPayload(photo: .uiTestFujiApple, jpegData: Data([0xff, 0xd8]))

        do {
            _ = try await client.estimate(photoPayload: payload)
            throw FoodWalletTestFailure("expected entitlement required error")
        } catch let error as FoodAnalysisBrokerClientError {
            guard case let .entitlementRequired(usage, message, status) = error else {
                throw FoodWalletTestFailure("expected entitlement error, got \(error)")
            }
            try expect(status == 429, "expected 429 status")
            try expect(message == "MealMark usage limit reached", "expected broker message")
            try expect(usage.feature == .photoAnalysis, "expected photo usage feature")
            try expect(usage.limit == 10, "expected free photo limit")
            try expect(usage.used == 11, "expected over-limit usage")
            try expect(usage.remaining == 0, "expected zero remaining")
            try expect(usage.resetAtMs == 1_800_000_000_000, "expected reset time")
            try expect(usage.entitlementRequired, "expected entitlement flag")
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

        var tracker = CameraBarcodeStabilityTracker()
        try expect(
            tracker.observe(["071537001822"]) == nil,
            "expected automatic scan to wait for a second stable observation before lookup"
        )
        try expect(
            tracker.observe(["071537001839"]) == nil,
            "expected a different barcode observation not to inherit the first candidate's count"
        )
        try expect(
            tracker.observe(["071537001839"]) == "071537001839",
            "expected repeated stable barcode to be emitted"
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
        try expect(store.currentCandidate?.nutrition.minKcal == 80, "expected barcode nutrition to be exact")
        try expect(store.currentCandidate?.nutrition.maxKcal == 80, "expected barcode nutrition to be exact")
        try expect(store.currentDraft?.meal.varianceKcal == 0, "expected exact barcode calories to avoid artificial range")
        try expect(store.currentCandidate?.primarySourceLabel() == "Barcode match", "expected barcode provenance")

        store.confirmDraft()

        try expect(store.todayNutritionSummary.kcalRangeLabel == "80 kcal", "expected exact barcode total, got \(store.todayNutritionSummary.kcalRangeLabel)")
    }

    @MainActor
    private static func testStoreBarcodeSearchRequestsSingleExactResult() async throws {
        let result = try JSONDecoder().decode(BrokerFoodSearchEnvelope.self, from: brokerSearchEnvelopeJSON()).results[0]
        let client = CapturingFoodSearchClient(results: [result])
        let store = FoodWalletStore(searchClient: client)

        await store.searchBrokerFood(barcode: "0 12345-67890 5")

        try expect(client.requests.count == 1, "expected one barcode lookup request")
        try expect(client.requests[0].barcode == "012345678905", "expected normalized barcode")
        try expect(client.requests[0].limit == 1, "expected barcode lookup to request only the exact best match")
    }

    private static func testBrokerNameSearchDoesNotClaimBarcodeAssumption() throws {
        let result = try JSONDecoder().decode(BrokerFoodSearchEnvelope.self, from: brokerGroundBeefSearchEnvelopeJSON()).results[0]
        let candidate = try result.candidate()

        try expect(!candidate.assumptions.contains { $0.id == "barcode-match" }, "expected name search not to claim barcode")
        try expect(candidate.assumptions.contains { $0.id == "provider-name-match" }, "expected provider name provenance")
        try expect(candidate.primarySourceLabel() == "USDA estimate", "expected name search to keep USDA source label")
    }

    private static func testTodaySummaryPrimaryLabelUsesLoggedCalories() throws {
        let entry = FoodIntakeEntry(
            entryID: "food-entry-test",
            draftID: "food-draft-test",
            meal: MealEstimate(
                label: "Ranch tortilla style protein chips",
                kcal: 140,
                varianceKcal: 14,
                amountGrams: 32,
                macronutrients: MealMacronutrients(
                    proteinGrams: 19,
                    carbohydrateGrams: 5,
                    fatGrams: 4.5,
                    fiberGrams: nil
                )
            ),
            sourceClass: .estimated,
            trustStatus: .estimated,
            confirmedAt: Date(),
            dateKey: "2026-05-21"
        )
        let summary = FoodWalletDailyNutritionSummary(entries: [entry])

        try expect(summary.kcalTotalLabel == "140 kcal", "expected primary total to show logged kcal")
        try expect(summary.kcalRangeLabel == "126-154 kcal", "expected range to remain available separately")
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
    private static func testTypedFoodDraftCreatesFromKnownSearchResult() async throws {
        let store = FoodWalletStore()

        let created = store.createTypedFoodDraft("apple")

        try expect(created, "expected typed food to create a draft from a known source")
        try expect(store.currentCandidate?.primaryLabel == "Apple", "expected catalog label")
        try expect(store.currentCandidate?.confidence == .medium, "expected medium confidence for catalog source")
        try expect(store.currentDraft?.trustStatus == .selfIssued, "expected self-issued catalog draft")
        try expect(store.currentDraft?.sourceClass == .measured, "expected measured source class")
        try expect(store.currentDraft?.meal.amountGrams == 100, "expected default catalog grams")
        try expect(store.currentDraft?.meal.kcal == 52, "expected catalog calories")
        try expect(store.entries.isEmpty, "expected review boundary before save")

        store.confirmDraft()

        try expect(store.entries.count == 1, "expected saved typed food entry")
        try expect(store.entries.first?.trustStatus == .selfIssued, "expected saved entry to remain self-issued")
    }

    @MainActor
    private static func testTypedFoodDraftRejectsUnknownFoodWithoutFakeNutrition() async throws {
        let store = FoodWalletStore()

        let created = store.createTypedFoodDraft("JAANA")

        try expect(!created, "expected unknown typed food to be unresolved")
        try expect(store.currentCandidate == nil, "expected no fake candidate for unknown typed food")
        try expect(store.currentDraft == nil, "expected no fake draft for unknown typed food")
        try expect(store.entries.isEmpty, "expected no saved entry for unknown typed food")
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
    private static func testAddFoodSearchSuggestionsIncludeMacadamiaNuts() async throws {
        let store = FoodWalletStore()
        let rows = store.addFoodSearchSuggestions(for: "macadamia")

        guard let first = rows.first else {
            throw FoodWalletTestFailure("expected macadamia search result")
        }
        try expect(first.title == "Macadamia nuts", "expected catalog-backed macadamia result")
        try expect(first.sourceLabel == "Ingredient catalog", "expected provenance label")
        try expect(first.subtitle == "1 oz (28 g) | 201 kcal", "expected serving kcal summary")
        try expect(first.evidence.contains { $0.providerID == "nuts.macadamia" }, "expected macadamia evidence")
    }

    @MainActor
    private static func testIngredientLookupDoesNotResolveSubstringMatches() async throws {
        let store = FoodWalletStore()

        let almondButter = store.createIngredientMealDraft(
            title: "Toast",
            ingredients: [
                FoodMealIngredientInput(name: "Almond butter", grams: 32),
            ]
        )
        try expect(
            almondButter == .unknownIngredient("Almond butter"),
            "expected almond butter to require a real source, got \(almondButter)"
        )
        try expect(store.currentDraft == nil, "expected no fake draft for unresolved almond butter")

        let plainButter = store.createIngredientMealDraft(
            title: "Toast",
            ingredients: [
                FoodMealIngredientInput(name: "Butter", grams: 14),
            ]
        )
        try expect(plainButter == .created, "expected exact butter lookup to remain supported, got \(plainButter)")
        try expect(store.currentCandidate?.evidence.first?.providerID == "butter", "expected exact butter provider evidence")
    }

    @MainActor
    private static func testIngredientSuggestionsDoNotMatchInsideWords() async throws {
        let store = FoodWalletStore()
        let rows = store.addFoodSearchSuggestions(for: "oil")

        try expect(rows.contains { $0.title == "Olive oil" }, "expected exact oil alias to match")
        try expect(!rows.contains { $0.title == "Boiled egg" }, "expected oil not to match inside boiled")
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
        let store = FoodWalletStore(wallet: GrainFoodWallet(clock: clock), privacy: .granted)
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
        let result = try JSONDecoder().decode(BrokerFoodSearchEnvelope.self, from: brokerGroundBeefSearchEnvelopeJSON()).results[0]
        let store = FoodWalletStore(searchClient: StaticFoodSearchClient(results: [result]))

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
    private static func testCustomQRCodeIssuerLabelIsSignedInsideGR1() async throws {
        let store = FoodWalletStore()
        let createResult = store.createIngredientMealDraft(
            title: "Coach breakfast",
            ingredients: [
                FoodMealIngredientInput(name: "eggs", grams: 100),
                FoodMealIngredientInput(name: "toast", grams: 40),
            ]
        )
        try expect(createResult == .created, "expected source recipe creation")
        guard let recipe = store.savedRecipes.first else {
            throw FoodWalletTestFailure("expected recipe")
        }

        let issuerProfile = FoodWalletQRIssuerProfile(
            label: "Coach Petya",
            trustAnchorID: "coach:petya"
        )
        let qrText = try FoodWalletProtocolQRCodeFactory.qrText(recipe: recipe, issuerProfile: issuerProfile)
        let decoded = try FoodWalletProtocolQRCodeFactory.payload(fromGR1: qrText)

        try expect(FoodWalletQRFactory.verify(decoded), "expected custom issuer QR payload to verify")
        try expect(decoded.issuer?.label == "Coach Petya", "expected custom QR issuer label")
        try expect(decoded.signature?.signer == "Coach Petya", "expected signature signer to use custom label")

        let preview = try store.previewQRCodePayload(qrText)
        try expect(preview.signedByLabel.hasPrefix("Coach Petya • p256:"), "expected custom signer in preview")

        let tampered = qrText.replacingOccurrences(of: "GR1:", with: "GR1:A")
        do {
            _ = try store.previewQRCodePayload(tampered)
            throw FoodWalletTestFailure("expected tampered custom QR to fail")
        } catch is FoodWalletQRImportError {
            // Expected.
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
        try expect(source.createTypedFoodDraft("apple"), "expected source draft")
        source.confirmDraft()

        let restored = FoodWalletStore(entries: source.entries)

        try expect(restored.entries.count == 1, "expected restored entry")
        try expect(restored.entries.first?.entryID == source.entries.first?.entryID, "expected stable restored entry id")
        try expect(restored.safeSummary.totals.entryCount == 1, "expected restored safe summary")
        try expect(restored.safeSummary.entries.first?.label == "Apple", "expected restored safe summary label")
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

        try expect(store.createTypedFoodDraft("apple"), "expected draft")
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
        try expect(edited.sourceClass == .measured, "expected manual edit to be measured")
        try expect(edited.trustStatus == .selfIssued, "expected manual edit to be self-issued")
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

        try expect(store.createTypedFoodDraft("apple"), "expected first draft")
        store.confirmDraft()
        let deletedID = store.entries.first!.entryID
        try expect(store.createTypedFoodDraft("apple"), "expected second draft")
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
        try expect(store.createTypedFoodDraft("apple"), "expected sourced typed-food draft")
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
        try expect(source.createTypedFoodDraft("apple"), "expected source draft")
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

        try expect(store.createTypedFoodDraft("apple"), "expected sourced typed-food draft")
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
        try expect(seed.createTypedFoodDraft("apple"), "expected seed draft")
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

        try expect(restored.createTypedFoodDraft("apple"), "expected second draft")
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
        try expect(store.createTypedFoodDraft("apple"), "expected draft")
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
        try expect(store.createTypedFoodDraft("apple"), "expected estimated draft")
        store.confirmDraft()
        try expect(store.createVisibleLabelDraft(label: "Bottle label", caloriesPerContainer: 80, grams: 473), "expected measured draft")
        store.confirmDraft()

        let bundle = try store.exportPortableBundle()

        try expect(bundle.schema == "grain.food-wallet.bundle.v1", "expected Grain portable bundle schema")
        try expect(bundle.manifest.contentSha256.count == 64, "expected content hash")
        try expect(bundle.manifest.contentDigestID == "sha256:\(bundle.manifest.contentSha256)", "expected digest id to bind hash")
        try expect(bundle.manifest.signature?.algorithm == "p256-sha256", "expected self-issued signature")
        try expect(bundle.manifest.trustStatusSummary["verified"] == nil, "expected no synthetic verified provenance")
        try expect(bundle.manifest.trustStatusSummary["self_issued"] == 2, "expected self-issued provenance count")
        try expect(bundle.manifest.sourceClassSummary["attested"] == nil, "expected no synthetic attested source")
        try expect(bundle.manifest.sourceClassSummary["measured"] == 2, "expected measured source count")
        try expect(FoodWalletExportFactory.verifyIntegrity(bundle), "expected bundle integrity to verify")
    }

    @MainActor
    private static func testPortableImportPreviewsAndMergesIdempotently() async throws {
        let source = FoodWalletStore()
        try expect(source.createTypedFoodDraft("apple"), "expected source draft")
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
        try expect(source.createTypedFoodDraft("apple"), "expected source draft")
        source.confirmDraft()
        let original = String(decoding: try source.exportPortableJSON(), as: UTF8.self)
        let tampered = original.replacingOccurrences(of: "Apple", with: "Pear")

        let target = FoodWalletStore()
        try expectImportError(.integrityMismatch) {
            try target.previewPortableImport(Data(tampered.utf8))
        }
        try expect(target.entries.isEmpty, "expected tampered import to write nothing")
    }

    @MainActor
    private static func testStorePublishesAnalysisStateWhilePhotoEstimateRuns() async throws {
        let store = FoodWalletStore(
            analysisClient: SlowFoodAnalysisClient(delayNanoseconds: 100_000_000),
            privacy: .granted
        )

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
        let store = FoodWalletStore(analysisClient: FailingFoodAnalysisClient(), privacy: .granted)

        await store.analyze(photo: .uiTestFujiApple)

        try expect(store.analysisState.isFailed, "expected failed analysis state")
        try expect(store.analysisState.statusText == "Couldn’t analyze photo", "expected friendly failure status")
        try expect(store.currentDraft == nil, "expected no draft after failed analysis")
    }

    @MainActor
    private static func testStoreSanitizesProviderConfigurationFailure() async throws {
        let store = FoodWalletStore(analysisClient: ProviderNotConfiguredFoodAnalysisClient(), privacy: .granted)

        await store.analyze(photo: .uiTestFujiApple)

        try expect(store.analysisState.isFailed, "expected provider configuration failure state")
        guard case let .failed(failure) = store.analysisState else {
            throw FoodWalletTestFailure("expected failed state")
        }
        try expect(failure.code == .serviceUnavailable, "expected service-unavailable failure code")
        try expect(failure.message.localizedCaseInsensitiveContains("temporarily unavailable"), "expected user-facing fallback message")
        try expect(!failure.message.localizedCaseInsensitiveContains("OpenAI"), "expected no provider name in user-facing failure")
        try expect(!failure.message.localizedCaseInsensitiveContains("OPENAI_API_KEY"), "expected no secret configuration hint")
        try expect(!failure.message.localizedCaseInsensitiveContains("FOOD_ANALYSIS_MOCK"), "expected no developer mock hint")
        try expect(store.currentDraft == nil, "expected no draft after provider configuration failure")
        try expect(store.currentCandidate == nil, "expected no candidate after provider configuration failure")
    }

    @MainActor
    private static func testStorePublishesEntitlementRequiredFailure() async throws {
        let store = FoodWalletStore(analysisClient: EntitlementRequiredFoodAnalysisClient(), privacy: .granted)

        await store.analyze(photo: .uiTestFujiApple)

        try expect(store.analysisState.isFailed, "expected entitlement failure state")
        guard case let .failed(failure) = store.analysisState else {
            throw FoodWalletTestFailure("expected failed state")
        }
        try expect(failure.code == .entitlementRequired, "expected entitlement failure code")
        try expect(failure.message == "MealMark Plus is needed for more photo analysis this month.", "expected Plus upgrade message")
        try expect(store.currentDraft == nil, "expected no draft after entitlement failure")
    }

    @MainActor
    private static func testStorePublishesNoFoodStateWithoutDraft() async throws {
        let store = FoodWalletStore(analysisClient: NoFoodFoodAnalysisClient(), privacy: .granted)

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
            privacy: .granted,
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
        try expect(source.createTypedFoodDraft("apple"), "expected source draft")
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

        await store.analyze(photo: .uiTestFujiApple)

        try expect(store.privacy == .denied, "expected denied privacy to remain denied")
        try expect(store.analysisState == .blockedPrivacy, "expected denied privacy state")
        try expect(store.currentCandidate == nil, "expected denied privacy to block candidate")
        try expect(store.currentDraft == nil, "expected denied privacy to block draft")
        try expect(store.entries.isEmpty, "expected denied privacy to avoid entries")
    }

    @MainActor
    private static func testNotRequestedPrivacyRequiresExplicitConsent() async throws {
        let store = FoodWalletStore(privacy: .notRequested)

        await store.analyze(photo: .uiTestFujiApple)

        try expect(store.privacy == .notRequested, "expected consent state to stay pending")
        try expect(store.analysisState == .blockedPrivacy, "expected privacy gate before AI analysis")
        try expect(store.currentCandidate == nil, "expected no candidate before explicit consent")

        store.grantAIConsent()
        await store.analyze(photo: .uiTestFujiApple)

        try expect(store.privacy == .granted, "expected explicit consent")
        try expect(store.analysisState == .draftReady, "expected analysis after explicit consent")
        try expect(store.currentCandidate != nil, "expected candidate after explicit consent")
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
    var authorization: String?
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

private struct ProviderNotConfiguredFoodAnalysisClient: FoodAnalysisClient {
    func estimate(example: FoodCaptureExample) async throws -> FoodAnalysisCandidate {
        throw providerConfigurationError()
    }

    func estimate(photo: CapturedMealPhoto) async throws -> FoodAnalysisCandidate {
        throw providerConfigurationError()
    }

    func estimate(photoPayload: TransientMealPhotoPayload) async throws -> FoodAnalysisCandidate {
        throw providerConfigurationError()
    }

    private func providerConfigurationError() -> FoodAnalysisBrokerClientError {
        .brokerError(
            code: "PROVIDER_NOT_CONFIGURED",
            message: "OpenAI food analysis is not configured; set OPENAI_API_KEY or explicitly enable FOOD_ANALYSIS_MOCK=1",
            status: 503
        )
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

private struct EntitlementRequiredFoodAnalysisClient: FoodAnalysisClient {
    func estimate(example: FoodCaptureExample) async throws -> FoodAnalysisCandidate {
        throw entitlementError()
    }

    func estimate(photo: CapturedMealPhoto) async throws -> FoodAnalysisCandidate {
        throw entitlementError()
    }

    func estimate(photoPayload: TransientMealPhotoPayload) async throws -> FoodAnalysisCandidate {
        throw entitlementError()
    }

    private func entitlementError() -> FoodAnalysisBrokerClientError {
        .entitlementRequired(
            usage: MealMarkUsageSnapshot(
                feature: .photoAnalysis,
                limit: 10,
                used: 11,
                resetAtMs: 1_800_000_000_000,
                entitlementRequired: true
            ),
            message: "MealMark usage limit reached",
            status: 429
        )
    }
}

private struct StaticFoodSearchClient: BrokerFoodSearchClient {
    var results: [BrokerFoodSearchResult]

    func searchFood(_ request: BrokerFoodSearchRequest) async throws -> [BrokerFoodSearchResult] {
        results
    }
}

private final class CapturingFoodSearchClient: BrokerFoodSearchClient, @unchecked Sendable {
    var results: [BrokerFoodSearchResult]
    private(set) var requests: [BrokerFoodSearchRequest] = []

    init(results: [BrokerFoodSearchResult]) {
        self.results = results
    }

    func searchFood(_ request: BrokerFoodSearchRequest) async throws -> [BrokerFoodSearchResult] {
        requests.append(request)
        return results
    }
}

private func brokerClient(
    bearerToken: String? = nil,
    authorizationProvider: (any FoodAnalysisBrokerAuthorizationProvider)? = nil,
    handler: @escaping @Sendable (URLRequest) throws -> BrokerResponse
) -> FoodAnalysisBrokerClient {
    BrokerURLProtocol.setHandler(handler)
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [BrokerURLProtocol.self]
    return FoodAnalysisBrokerClient(
        endpoint: URL(string: "https://broker.example.test/v1/food/analyze-photo")!,
        bearerToken: bearerToken,
        authorizationProvider: authorizationProvider,
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

private func brokerGroundBeefSearchEnvelopeJSON() -> Data {
    Data(
        """
        {
          "ok": true,
          "request_id": "ground-beef-search-001",
          "query": "beef",
          "results": [
            {
              "result_id": "food-search:usda-fdc:333333",
              "primary_label": "Cooked ground beef",
              "generic_label": "ground beef",
              "brand_label": null,
              "category": "Beef Products",
              "source_label": "usda_fdc",
              "trust_label": "provider_estimate",
              "match": {
                "type": "name",
                "score": 0.96
              },
              "serving": {
                "basis": "per_100g",
                "serving_size_g": 100,
                "serving_label": "100 g"
              },
              "nutrition": {
                "per_100g": {
                  "kcal": 254,
                  "protein_g": 25.9,
                  "carbohydrate_g": 0,
                  "fat_g": 17.2,
                  "fiber_g": 0
                }
              },
              "provider_evidence": [
                {
                  "provider": "usda_fdc",
                  "provider_id": "333333",
                  "matched_name": "BEEF, GROUND, COOKED",
                  "match_type": "name",
                  "source_label": "usda_generic_food",
                  "trust_label": "provider_estimate"
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

private func brokerRateLimitErrorJSON(
    feature: String,
    limit: Int,
    used: Int,
    resetAtMs: Int64,
    entitlementRequired: Bool
) -> Data {
    Data(
        """
        {
          "ok": false,
          "error": {
            "code": "RATE_LIMITED",
            "message": "MealMark usage limit reached",
            "request_id": "broker-rate-limit-fixture",
            "details": {
              "feature": "\(feature)",
              "limit": \(limit),
              "used": \(used),
              "reset_at_ms": \(resetAtMs),
              "entitlement_required": \(entitlementRequired)
            }
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
