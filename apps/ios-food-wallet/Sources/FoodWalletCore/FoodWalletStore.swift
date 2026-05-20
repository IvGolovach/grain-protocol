import Combine
import Foundation
import GrainFoodWallet

public struct FoodWalletDeviceSmokeResult: Equatable, Sendable {
    public let passed: Bool
    public let entryCount: Int
    public let totalKcal: Int64
    public let reason: String

    public init(passed: Bool, entryCount: Int, totalKcal: Int64, reason: String) {
        self.passed = passed
        self.entryCount = entryCount
        self.totalKcal = totalKcal
        self.reason = reason
    }
}

public enum FoodAnalysisSource: Equatable, Sendable {
    case example(FoodCaptureExample)
    case photo(id: String)
    case transientPhoto(id: String, byteCount: Int)
}

public struct FoodAnalysisOperation: Equatable, Sendable {
    public var id: UUID
    public var source: FoodAnalysisSource
    public var startedAt: Date

    public init(id: UUID = UUID(), source: FoodAnalysisSource, startedAt: Date = Date()) {
        self.id = id
        self.source = source
        self.startedAt = startedAt
    }
}

public enum FoodAnalysisFailureCode: Equatable, Sendable {
    case invalidPayload
    case invalidResponse
    case httpStatus(Int)
    case noFoodDetected
    case timeout
    case unsafeCandidate
    case network
    case unknown
}

public struct FoodAnalysisFailure: Equatable, Sendable {
    public var code: FoodAnalysisFailureCode
    public var message: String

    public init(code: FoodAnalysisFailureCode, message: String) {
        self.code = code
        self.message = message
    }
}

public enum FoodAnalysisState: Equatable, Sendable {
    case idle
    case analyzing(FoodAnalysisOperation)
    case slow(FoodAnalysisOperation)
    case failed(FoodAnalysisFailure)
    case draftReady
    case blockedPrivacy

    public var isAnalyzing: Bool {
        switch self {
        case .analyzing, .slow:
            return true
        case .idle, .failed, .draftReady, .blockedPrivacy:
            return false
        }
    }

    public var isSlow: Bool {
        if case .slow = self {
            return true
        }
        return false
    }

    public var isFailed: Bool {
        if case .failed = self {
            return true
        }
        return false
    }

    public var statusText: String {
        switch self {
        case .idle:
            return "No active analysis"
        case .analyzing:
            return "Looking for food"
        case .slow:
            return "Still analyzing photo"
        case let .failed(failure) where failure.code == .noFoodDetected:
            return "No food found"
        case .failed:
            return "Couldn’t analyze photo"
        case .draftReady:
            return "Draft ready"
        case .blockedPrivacy:
            return "AI photo analysis disabled"
        }
    }

    public var errorMessage: String? {
        if case let .failed(failure) = self {
            return failure.message
        }
        return nil
    }
}

public enum FoodSearchState: Equatable, Sendable {
    case idle
    case loading
    case ready(resultCount: Int)
    case empty
    case failed(String)
}

@MainActor
public final class FoodWalletStore: ObservableObject {
    private static let defaultSlowAnalysisThresholdNanoseconds: UInt64 = 8_000_000_000

    @Published public private(set) var currentCandidate: FoodAnalysisCandidate?
    @Published public private(set) var currentDraft: FoodIntakeDraft?
    @Published public private(set) var analysisState: FoodAnalysisState
    @Published public private(set) var entries: [FoodIntakeEntry]
    @Published public private(set) var safeSummary: SafeFoodSummary
    @Published public private(set) var savedTemplates: [SavedFoodTemplate]
    @Published public private(set) var savedRecipes: [SavedFoodRecipe]
    @Published public private(set) var personalIngredients: [PersonalFoodIngredient]
    @Published public private(set) var foodSearchState: FoodSearchState
    @Published public private(set) var brokerFoodSearchRows: [AddFoodSuggestionRow]
    @Published public var selectedExample: FoodCaptureExample
    @Published public var subscription: SubscriptionState
    @Published public var privacy: PrivacyConsentState

    private let analysisClient: any FoodAnalysisClient
    private let searchClient: (any BrokerFoodSearchClient)?
    private let slowAnalysisThresholdNanoseconds: UInt64
    private let analysisTimeoutNanoseconds: UInt64
    private let personalIngredientsDidChange: @MainActor ([PersonalFoodIngredient]) -> Void
    private let userLibraryDidChange: @MainActor (FoodWalletUserLibraryState) -> Void
    private let entriesDidChange: @MainActor ([FoodIntakeEntry]) -> Void
    private let entriesReload: (@MainActor () -> [FoodIntakeEntry])?
    private var slowAnalysisTask: Task<Void, Never>?
    private var analysisTimeoutTask: Task<Void, Never>?
    private var wallet: GrainFoodWallet
    private var brokerFoodSearchResults: [String: BrokerFoodSearchResult] = [:]
    private var entryProvenanceByEntryID: [String: MealMarkProvenanceSnapshot] = [:]

    public init(
        analysisClient: any FoodAnalysisClient = MockFoodAnalysisClient(),
        searchClient: (any BrokerFoodSearchClient)? = nil,
        wallet: GrainFoodWallet = GrainFoodWallet(),
        entries: [FoodIntakeEntry] = [],
        subscription: SubscriptionState = .free,
        privacy: PrivacyConsentState = .notRequested,
        savedTemplates: [SavedFoodTemplate] = SavedFoodTemplate.defaultTemplates,
        savedRecipes: [SavedFoodRecipe] = SavedFoodRecipe.defaultRecipes,
        personalIngredients: [PersonalFoodIngredient] = [],
        onEntriesChange: @escaping @MainActor ([FoodIntakeEntry]) -> Void = { _ in },
        onPersonalIngredientsChange: @escaping @MainActor ([PersonalFoodIngredient]) -> Void = { _ in },
        onUserLibraryChange: @escaping @MainActor (FoodWalletUserLibraryState) -> Void = { _ in },
        onEntriesReload: (@MainActor () -> [FoodIntakeEntry])? = nil,
        slowAnalysisThresholdNanoseconds: UInt64 = 8_000_000_000,
        analysisTimeoutNanoseconds: UInt64 = 30_000_000_000
    ) {
        self.analysisClient = analysisClient
        self.searchClient = searchClient
        self.slowAnalysisThresholdNanoseconds = slowAnalysisThresholdNanoseconds
        self.analysisTimeoutNanoseconds = analysisTimeoutNanoseconds
        self.personalIngredientsDidChange = onPersonalIngredientsChange
        self.userLibraryDidChange = onUserLibraryChange
        self.entriesDidChange = onEntriesChange
        self.entriesReload = onEntriesReload
        self.wallet = wallet
        self.analysisState = .idle
        self.entries = entries
        self.wallet.replaceEntries(entries)
        self.safeSummary = wallet.exportSafeSummary()
        self.savedTemplates = savedTemplates
        self.savedRecipes = savedRecipes
        self.personalIngredients = personalIngredients
        self.foodSearchState = .idle
        self.brokerFoodSearchRows = []
        self.selectedExample = .fujiApple
        self.subscription = subscription
        self.privacy = privacy
    }

    public var todayTotalLabel: String {
        let selected = todayEntries
        if selected.isEmpty {
            return "No meals saved yet"
        }
        let mean = selected.reduce(Int64(0)) { $0 + $1.meal.kcal }
        let variance = selected.reduce(Int64(0)) { $0 + $1.meal.varianceKcal }
        if variance == 0 {
            return "\(mean) kcal"
        }
        return "\(max(0, mean - variance))-\(mean + variance) kcal"
    }

    public var todayEntries: [FoodIntakeEntry] {
        entries.filter { Calendar.autoupdatingCurrent.isDateInToday($0.confirmedAt) }
    }

    public var todayNutritionSummary: FoodWalletDailyNutritionSummary {
        FoodWalletDailyNutritionSummary(entries: todayEntries)
    }

    public var hasDraft: Bool {
        currentDraft != nil && currentCandidate != nil
    }

    public var canStartAnalysis: Bool {
        !analysisState.isAnalyzing && privacy != .denied
    }

    public var canSaveDraft: Bool {
        analysisState == .draftReady && hasDraft
    }

    public var canDiscardDraft: Bool {
        hasDraft || analysisState.isFailed || analysisState == .blockedPrivacy
    }

    public func entry(entryID: String) -> FoodIntakeEntry? {
        entries.first { $0.entryID == entryID }
    }

    public func provenanceSnapshot(entryID: String) -> MealMarkProvenanceSnapshot? {
        entryProvenanceByEntryID[entryID]
    }

    public func savedRecipe(id: String) -> SavedFoodRecipe? {
        savedRecipes.first { $0.id == id }
    }

    public func personalIngredient(id: String) -> PersonalFoodIngredient? {
        personalIngredients.first { $0.id == id }
    }

    public func grantAIConsent() {
        privacy = .granted
    }

    public func chooseExample(_ example: FoodCaptureExample) {
        selectedExample = example
    }

    public func analyzeSelectedExample() async {
        guard preparePrivacyForAnalysis() else {
            return
        }
        await analyze(example: selectedExample)
    }

    public func analyze(example: FoodCaptureExample) async {
        guard preparePrivacyForAnalysis() else {
            return
        }
        let operation = beginAnalysis(source: .example(example))
        do {
            let candidate = try await analysisClient.estimate(example: example)
            apply(candidate: candidate, for: operation)
        } catch {
            failAnalysis(error, for: operation)
        }
    }

    public func analyze(photo: CapturedMealPhoto) async {
        guard preparePrivacyForAnalysis() else {
            return
        }

        let operation = beginAnalysis(source: .photo(id: photo.id))
        do {
            let candidate = try await analysisClient.estimate(photo: photo)
            apply(candidate: candidate, for: operation)
        } catch {
            failAnalysis(error, for: operation)
        }
    }

    public func analyze(photoPayload: TransientMealPhotoPayload) async {
        guard preparePrivacyForAnalysis() else {
            return
        }

        let operation = beginAnalysis(source: .transientPhoto(
            id: photoPayload.photo.id,
            byteCount: photoPayload.byteCount
        ))
        do {
            let candidate = try await analysisClient.estimate(photoPayload: photoPayload)
            apply(candidate: candidate, for: operation)
        } catch {
            failAnalysis(error, for: operation)
        }
    }

    public func cancelAnalysis() {
        cancelAnalysisTimers()
        currentCandidate = nil
        currentDraft = nil
        analysisState = .idle
    }

    public func toggleAssumption(id: String) {
        guard var candidate = currentCandidate else {
            return
        }
        candidate.assumptions = candidate.assumptions.map { assumption in
            guard assumption.id == id else {
                return assumption
            }
            var copy = assumption
            copy.isEnabled.toggle()
            return copy
        }
        currentCandidate = candidate
        if let draft = currentDraft {
            currentDraft = makeDraft(
                meal: candidate.mealEstimate(),
                sourceClass: draft.sourceClass,
                trustStatus: draft.trustStatus
            )
        } else {
            currentDraft = wallet.makeEstimatedDraft(meal: candidate.mealEstimate())
        }
    }

    public func createQuickTextDraft(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }
        let candidate = QuickTextFoodParser.candidate(for: trimmed)
        presentDraft(candidate: candidate, sourceClass: .measured, trustStatus: .selfIssued)
        return true
    }

    public func addFoodSearchSuggestions(for text: String) -> [AddFoodSuggestionRow] {
        FoodIngredientCatalog.suggestionRows(for: text, personalIngredients: personalIngredients)
    }

    public func ingredientSuggestions(for text: String, limit: Int = 5) -> [AddFoodSuggestionRow] {
        FoodIngredientCatalog.suggestionRows(
            for: text,
            personalIngredients: personalIngredients,
            limit: limit
        )
    }

    public func createFoodSearchSuggestionDraft(id: String) -> Bool {
        guard let candidate = FoodIngredientCatalog.candidate(
            suggestionID: id,
            personalIngredients: personalIngredients
        ) else {
            return false
        }
        presentDraft(candidate: candidate, sourceClass: .measured, trustStatus: .selfIssued)
        return true
    }

    public func searchBrokerFood(query: String) async {
        await searchBrokerFood(requestFactory: {
            try BrokerFoodSearchRequest(query: query)
        })
    }

    public func searchBrokerFood(barcode: String) async {
        await searchBrokerFood(requestFactory: {
            try BrokerFoodSearchRequest(barcode: barcode)
        })
    }

    public func clearBrokerFoodSearch() {
        brokerFoodSearchRows = []
        brokerFoodSearchResults = [:]
        foodSearchState = .idle
    }

    public func createBrokerFoodSearchDraft(id: String) -> Bool {
        guard let result = brokerFoodSearchResults[id],
              let candidate = try? result.candidate() else {
            return false
        }
        presentDraft(candidate: candidate, sourceClass: .estimated, trustStatus: .estimated)
        return true
    }

    public func createIngredientMealDraft(
        title: String,
        ingredients: [FoodMealIngredientInput]
    ) -> FoodMealDraftCreationResult {
        let recipeResult = FoodIngredientCatalog.savedRecipe(
            title: title,
            ingredients: ingredients,
            personalIngredients: personalIngredients
        )
        let candidateResult = FoodIngredientCatalog.candidate(
            title: title,
            ingredients: ingredients,
            personalIngredients: personalIngredients
        )

        switch (recipeResult, candidateResult) {
        case let (.success(recipe), .success(candidate)):
            upsertSavedRecipe(recipe)
            presentDraft(candidate: candidate, sourceClass: .measured, trustStatus: .selfIssued)
            return .created
        case let (.failure(result), _), let (_, .failure(result)):
            return result
        }
    }

    public func updateSavedRecipe(
        id: String,
        title: String,
        ingredients: [FoodMealIngredientInput]
    ) -> FoodMealDraftCreationResult {
        switch FoodIngredientCatalog.savedRecipe(
            title: title,
            ingredients: ingredients,
            personalIngredients: personalIngredients
        ) {
        case var .success(recipe):
            recipe.id = id
            upsertSavedRecipe(recipe)
            return .created
        case let .failure(result):
            return result
        }
    }

    public func deleteSavedRecipe(id: String) -> Bool {
        guard let index = savedRecipes.firstIndex(where: { $0.id == id }) else {
            return false
        }
        savedRecipes.remove(at: index)
        publishUserLibraryMutation()
        return true
    }

    public func qrPayloadTextForRecipe(id: String) -> String? {
        guard let recipe = savedRecipe(id: id),
              let payload = try? FoodWalletQRFactory.payload(recipe: recipe),
              FoodWalletQRFactory.verify(payload) else {
            return nil
        }
        return try? FoodWalletQRFactory.payloadText(payload)
    }

    public func qrPayloadTextForPersonalIngredient(id: String) -> String? {
        guard let ingredient = personalIngredient(id: id),
              let payload = try? FoodWalletQRFactory.payload(personalFood: ingredient),
              FoodWalletQRFactory.verify(payload) else {
            return nil
        }
        return try? FoodWalletQRFactory.payloadText(payload)
    }

    public func savePersonalIngredient(
        name: String,
        servingGrams: Double,
        servingKcal: Int64,
        proteinGrams: Double,
        carbohydrateGrams: Double,
        fatGrams: Double,
        fiberGrams: Double? = nil
    ) -> FoodPersonalIngredientSaveResult {
        switch FoodIngredientCatalog.personalIngredient(
            name: name,
            servingGrams: servingGrams,
            servingKcal: servingKcal,
            proteinGrams: proteinGrams,
            carbohydrateGrams: carbohydrateGrams,
            fatGrams: fatGrams,
            fiberGrams: fiberGrams
        ) {
        case let .success(ingredient):
            if let existingIndex = personalIngredients.firstIndex(where: { $0.id == ingredient.id }) {
                personalIngredients[existingIndex] = ingredient
            } else {
                personalIngredients.append(ingredient)
            }
            publishUserLibraryMutation()
            return .saved
        case let .failure(result):
            return result
        }
    }

    public func updateCurrentDraftPortion(gramsMode: Int64) -> Bool {
        guard let candidate = currentCandidate, let draft = currentDraft, gramsMode > 0 else {
            return false
        }
        let scaledCandidate = candidate.scaled(toGrams: gramsMode)
        currentCandidate = scaledCandidate
        currentDraft = FoodIntakeDraft(
            draftID: draft.draftID,
            meal: scaledCandidate.mealEstimate(),
            sourceClass: draft.sourceClass,
            trustStatus: draft.trustStatus,
            createdAt: draft.createdAt,
            dateKey: draft.dateKey
        )
        analysisState = .draftReady
        return true
    }

    public func updateEntry(entryID: String, label: String, gramsMode: Int64) -> Bool {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLabel.isEmpty, gramsMode > 0 else {
            return false
        }
        guard let index = entries.firstIndex(where: { $0.entryID == entryID }) else {
            return false
        }

        let current = entries[index]
        let updatedMeal = Self.editedMeal(
            current.meal,
            label: trimmedLabel,
            gramsMode: gramsMode
        )
        let updatedEntry = FoodIntakeEntry(
            entryID: current.entryID,
            draftID: current.draftID,
            meal: updatedMeal,
            sourceClass: current.sourceClass,
            trustStatus: current.trustStatus,
            confirmedAt: current.confirmedAt,
            dateKey: current.dateKey
        )
        entries[index] = updatedEntry
        publishEntryMutation()
        return true
    }

    public func deleteEntry(entryID: String) -> Bool {
        guard let index = entries.firstIndex(where: { $0.entryID == entryID }) else {
            return false
        }
        entries.remove(at: index)
        entryProvenanceByEntryID[entryID] = nil
        publishEntryMutation()
        return true
    }

    public func createTemplateDraft(id: String) -> Bool {
        guard let template = savedTemplates.first(where: { $0.id == id }) else {
            return false
        }
        presentDraft(
            candidate: FoodWalletStore.candidate(
                id: "template-\(template.id)",
                label: template.title,
                genericLabel: template.title.lowercased(),
                dishType: .mixed,
                meal: template.mealEstimate,
                confidence: .high,
                assumptions: [
                    FoodAssumption(id: "saved-template", label: "saved meal template"),
                    FoodAssumption(id: "review-portion", label: "review portion before saving"),
                ],
                evidence: [
                    ProviderEvidence(
                        provider: "food_wallet_template",
                        providerID: template.id,
                        matchedName: template.title,
                        servingBasis: "saved_template"
                    ),
                ]
            ),
            sourceClass: .measured,
            trustStatus: .selfIssued
        )
        return true
    }

    public func createRecipeDraft(id: String, consumedFraction: Double) -> Bool {
        guard let recipe = savedRecipes.first(where: { $0.id == id }) else {
            return false
        }
        let meal = recipe.mealEstimate(consumedFraction: consumedFraction)
        presentDraft(
            candidate: FoodWalletStore.candidate(
                id: "recipe-\(recipe.id)",
                label: recipe.title,
                genericLabel: recipe.title.lowercased(),
                dishType: .mixed,
                meal: meal,
                confidence: .high,
                assumptions: [
                    FoodAssumption(id: "saved-recipe", label: "saved recipe ingredients"),
                    FoodAssumption(id: "partial-portion", label: "logged partial portion"),
                ],
                evidence: [
                    ProviderEvidence(
                        provider: "food_wallet_recipe",
                        providerID: recipe.id,
                        matchedName: recipe.title,
                        servingBasis: "recipe_yield"
                    ),
                ]
            ),
            sourceClass: .measured,
            trustStatus: .selfIssued
        )
        return true
    }

    public func createRecentEntryDraft(entryID: String) -> Bool {
        guard let entry = entries.first(where: { $0.entryID == entryID }) else {
            return false
        }
        presentDraft(
            candidate: FoodWalletStore.candidate(
                id: "repeat-\(entry.entryID)",
                label: entry.meal.label,
                genericLabel: entry.meal.label.lowercased(),
                dishType: .unknown,
                meal: entry.meal,
                confidence: .high,
                assumptions: [
                    FoodAssumption(id: "repeat-entry", label: "repeated from confirmed entry"),
                ],
                evidence: [
                    ProviderEvidence(
                        provider: "food_wallet_history",
                        providerID: entry.entryID,
                        matchedName: entry.meal.label,
                        servingBasis: "confirmed_entry"
                    ),
                ]
            ),
            sourceClass: .measured,
            trustStatus: .selfIssued
        )
        return true
    }

    public func createVisibleLabelDraft(label: String, caloriesPerContainer: Int64, grams: Int64) -> Bool {
        guard caloriesPerContainer > 0, grams > 0 else {
            return false
        }
        let meal = MealEstimate(
            label: label,
            kcal: caloriesPerContainer,
            varianceKcal: 0,
            amountGrams: grams,
            servingGrams: grams,
            servings: 1,
            macronutrients: MealMacronutrients(
                proteinGrams: 0,
                carbohydrateGrams: Double(caloriesPerContainer) / 4,
                fatGrams: 0,
                fiberGrams: 0
            )
        )
        presentDraft(
            candidate: FoodWalletStore.candidate(
                id: "visible-label-\(label.lowercased().replacingOccurrences(of: " ", with: "-"))",
                label: label,
                genericLabel: label.lowercased(),
                dishType: .packaged,
                meal: meal,
                confidence: .high,
                assumptions: [
                    FoodAssumption(id: "visible-label", label: "visible nutrition label calories"),
                    FoodAssumption(id: "whole-container", label: "whole container label value"),
                ],
                evidence: [
                    ProviderEvidence(
                        provider: "visible_nutrition_label",
                        providerID: "label-user-confirmed",
                        matchedName: label,
                        servingBasis: "per_container_label"
                    ),
                ]
            ),
            sourceClass: .measured,
            trustStatus: .selfIssued
        )
        return true
    }

    public func createVerifiedServingOfferDraft() -> Bool {
        let meal = MealEstimate(
            label: "Verified lentil bowl",
            kcal: 520,
            varianceKcal: 0,
            amountGrams: 420,
            servingGrams: 420,
            servings: 1,
            macronutrients: MealMacronutrients(
                proteinGrams: 26,
                carbohydrateGrams: 68,
                fatGrams: 14,
                fiberGrams: 15
            )
        )
        presentDraft(
            candidate: FoodWalletStore.candidate(
                id: "verified-serving-offer",
                label: meal.label,
                genericLabel: "lentil bowl",
                dishType: .mixed,
                meal: meal,
                confidence: .high,
                assumptions: [
                    FoodAssumption(id: "issuer-serving", label: "issuer-provided serving"),
                    FoodAssumption(id: "grain-verified", label: "verified serving offer"),
                ],
                evidence: [
                    ProviderEvidence(
                        provider: "grain_serving_offer",
                        providerID: "local-serving-offer",
                        matchedName: "Verified lentil bowl",
                        servingBasis: "issuer_attested_serving"
                    ),
                ]
            ),
            sourceClass: .attested,
            trustStatus: .verified
        )
        return true
    }

    public func copyEntries(fromDateKey dateKey: String) -> Int {
        let selected = entries.filter { $0.dateKey == dateKey }
        for entry in selected.reversed() {
            let draft = wallet.makeSelfIssuedDraft(meal: entry.meal)
            entries.insert(wallet.confirmDraft(draft), at: 0)
        }
        if !selected.isEmpty {
            safeSummary = wallet.exportSafeSummary()
            entriesDidChange(entries)
        }
        return selected.count
    }

    public func exportPortableBundle(generatedAt: Date = Date()) throws -> FoodWalletExportBundle {
        try FoodWalletExportFactory.portableBundle(
            entries: entries,
            templates: savedTemplates,
            recipes: savedRecipes,
            generatedAt: generatedAt,
            personalFoods: personalIngredients
        )
    }

    public func exportPortableJSON() throws -> Data {
        try FoodWalletExportFactory.jsonData(exportPortableBundle())
    }

    public func exportCSV() -> String {
        FoodWalletExportFactory.csv(entries: entries)
    }

    public func previewPortableImport(_ data: Data) throws -> FoodWalletImportPreview {
        try previewPortableImport(FoodWalletExportFactory.decodeBundle(data))
    }

    public func previewPortableImport(_ bundle: FoodWalletExportBundle) throws -> FoodWalletImportPreview {
        try FoodWalletExportFactory.importPreview(
            bundle: bundle,
            existingEntryIDs: Set(entries.map(\.entryID))
        )
    }

    @discardableResult
    public func importPortableBundle(_ data: Data) throws -> FoodWalletImportResult {
        try importPortableBundle(FoodWalletExportFactory.decodeBundle(data))
    }

    @discardableResult
    public func importPortableBundle(_ bundle: FoodWalletExportBundle) throws -> FoodWalletImportResult {
        let preview = try previewPortableImport(bundle)
        guard preview.newEntryCount > 0 else {
            return FoodWalletImportResult(
                importedEntryCount: 0,
                duplicateEntryCount: preview.duplicateEntryCount
            )
        }

        let existingIDs = Set(entries.map(\.entryID))
        let importedEntries = try FoodWalletExportFactory.entries(from: bundle)
        let newEntries = importedEntries.filter { !existingIDs.contains($0.entryID) }
        for entry in newEntries.reversed() {
            entries.insert(entry, at: 0)
        }
        wallet.replaceEntries(entries)
        safeSummary = wallet.exportSafeSummary()
        entriesDidChange(entries)
        return FoodWalletImportResult(
            importedEntryCount: newEntries.count,
            duplicateEntryCount: preview.duplicateEntryCount
        )
    }

    public func confirmDraft() {
        guard let draft = currentDraft else {
            return
        }
        let candidate = currentCandidate
        let entry = wallet.confirmDraft(draft)
        entries.insert(entry, at: 0)
        if let candidate {
            entryProvenanceByEntryID[entry.entryID] = MealMarkProvenanceSnapshot(candidate: candidate, entry: entry)
        }
        safeSummary = wallet.exportSafeSummary()
        entriesDidChange(entries)
        currentCandidate = nil
        currentDraft = nil
        analysisState = .idle
    }

    public func discardDraft() {
        currentCandidate = nil
        currentDraft = nil
        analysisState = .idle
    }

    public func resetLocalData() {
        cancelAnalysisTimers()
        wallet = GrainFoodWallet()
        entries = []
        entryProvenanceByEntryID = [:]
        currentCandidate = nil
        currentDraft = nil
        analysisState = .idle
        safeSummary = wallet.exportSafeSummary()
        savedTemplates = []
        savedRecipes = []
        personalIngredients = []
        publishUserLibraryMutation()
        entriesDidChange(entries)
    }

    public func refreshLocalState() async {
        guard let entriesReload else {
            wallet.replaceEntries(entries)
            safeSummary = wallet.exportSafeSummary()
            return
        }
        entries = entriesReload()
        wallet.replaceEntries(entries)
        safeSummary = wallet.exportSafeSummary()
    }

    public func runDeviceSmoke() async -> FoodWalletDeviceSmokeResult {
        resetLocalData()

        await analyze(photo: .uiTestFujiApple)
        guard currentCandidate?.primaryLabel == "Fuji apple", currentDraft != nil else {
            return smokeFailure("photo apple draft was not created")
        }
        confirmDraft()

        await analyze(example: .mushroomRisotto)
        guard currentCandidate?.primaryLabel == "Mushroom risotto", currentDraft != nil else {
            return smokeFailure("risotto draft was not created")
        }
        toggleAssumption(id: "butter-oil")
        confirmDraft()

        guard entries.count == 2 else {
            return smokeFailure("expected two confirmed entries, got \(entries.count)")
        }
        guard safeSummary.totals.entryCount == 2 else {
            return smokeFailure("expected two safe summary entries, got \(safeSummary.totals.entryCount)")
        }

        let summary = String(describing: safeSummary)
        let forbidden = ["rawPhoto", "photoBytes", "COSE", "CBOR", "snapshot", "privateKey", "trustPub", "GR1"]
        for token in forbidden where summary.localizedCaseInsensitiveContains(token) {
            return smokeFailure("safe summary leaked \(token)")
        }

        return FoodWalletDeviceSmokeResult(
            passed: true,
            entryCount: entries.count,
            totalKcal: safeSummary.totals.sumMeanKcal,
            reason: "ok"
        )
    }

    private func smokeFailure(_ reason: String) -> FoodWalletDeviceSmokeResult {
        FoodWalletDeviceSmokeResult(
            passed: false,
            entryCount: entries.count,
            totalKcal: safeSummary.totals.sumMeanKcal,
            reason: reason
        )
    }

    private func preparePrivacyForAnalysis() -> Bool {
        if privacy == .denied {
            cancelAnalysisTimers()
            currentCandidate = nil
            currentDraft = nil
            analysisState = .blockedPrivacy
            return false
        }
        if privacy == .notRequested {
            grantAIConsent()
        }
        return true
    }

    private func beginAnalysis(source: FoodAnalysisSource) -> FoodAnalysisOperation {
        cancelAnalysisTimers()
        currentCandidate = nil
        currentDraft = nil

        let operation = FoodAnalysisOperation(source: source)
        analysisState = .analyzing(operation)
        scheduleSlowState(for: operation)
        scheduleTimeoutState(for: operation)
        return operation
    }

    private func scheduleSlowState(for operation: FoodAnalysisOperation) {
        let threshold = slowAnalysisThresholdNanoseconds
        slowAnalysisTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: threshold)
            } catch {
                return
            }
            await MainActor.run {
                guard let self, self.analysisState == .analyzing(operation) else {
                    return
                }
                self.analysisState = .slow(operation)
            }
        }
    }

    private func scheduleTimeoutState(for operation: FoodAnalysisOperation) {
        let threshold = analysisTimeoutNanoseconds
        analysisTimeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: threshold)
            } catch {
                return
            }
            await MainActor.run {
                guard let self, self.isCurrent(operation: operation) else {
                    return
                }
                self.cancelAnalysisTimers()
                self.currentCandidate = nil
                self.currentDraft = nil
                self.analysisState = .failed(FoodAnalysisFailure(
                    code: .timeout,
                    message: "Analysis took too long. Check your connection, try another photo, or enter the meal manually."
                ))
            }
        }
    }

    private func cancelAnalysisTimers() {
        slowAnalysisTask?.cancel()
        slowAnalysisTask = nil
        analysisTimeoutTask?.cancel()
        analysisTimeoutTask = nil
    }

    private func apply(candidate: FoodAnalysisCandidate, for operation: FoodAnalysisOperation) {
        guard isCurrent(operation: operation) else {
            return
        }
        cancelAnalysisTimers()
        presentDraft(candidate: candidate, sourceClass: .estimated, trustStatus: .estimated)
    }

    private func failAnalysis(_ error: Error, for operation: FoodAnalysisOperation) {
        guard isCurrent(operation: operation) else {
            return
        }
        cancelAnalysisTimers()
        currentCandidate = nil
        currentDraft = nil
        analysisState = .failed(FoodWalletStore.analysisFailure(for: error))
    }

    private func isCurrent(operation: FoodAnalysisOperation) -> Bool {
        switch analysisState {
        case let .analyzing(current), let .slow(current):
            return current.id == operation.id
        case .idle, .failed, .draftReady, .blockedPrivacy:
            return false
        }
    }

    private func presentDraft(
        candidate: FoodAnalysisCandidate,
        sourceClass: FoodSourceClass,
        trustStatus: FoodTrustStatus
    ) {
        cancelAnalysisTimers()
        currentCandidate = candidate
        currentDraft = makeDraft(
            meal: candidate.mealEstimate(),
            sourceClass: sourceClass,
            trustStatus: trustStatus
        )
        analysisState = .draftReady
    }

    private func publishEntryMutation() {
        let entryIDs = Set(entries.map(\.entryID))
        entryProvenanceByEntryID = entryProvenanceByEntryID.filter { entryIDs.contains($0.key) }
        wallet.replaceEntries(entries)
        safeSummary = wallet.exportSafeSummary()
        entriesDidChange(entries)
    }

    private func upsertSavedRecipe(_ recipe: SavedFoodRecipe) {
        if let existingIndex = savedRecipes.firstIndex(where: { $0.id == recipe.id }) {
            savedRecipes[existingIndex] = recipe
        } else {
            savedRecipes.append(recipe)
        }
        publishUserLibraryMutation()
    }

    private func publishUserLibraryMutation() {
        savedRecipes.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        personalIngredients.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        personalIngredientsDidChange(personalIngredients)
        userLibraryDidChange(FoodWalletUserLibraryState(
            templates: savedTemplates,
            recipes: savedRecipes,
            personalIngredients: personalIngredients
        ))
    }

    private func searchBrokerFood(requestFactory: () throws -> BrokerFoodSearchRequest) async {
        guard let searchClient else {
            brokerFoodSearchRows = []
            brokerFoodSearchResults = [:]
            foodSearchState = .failed("Food lookup is unavailable. Try photo or enter the food manually.")
            return
        }

        foodSearchState = .loading
        do {
            let request = try requestFactory()
            let results = try await searchClient.searchFood(request)
            brokerFoodSearchResults = Dictionary(uniqueKeysWithValues: results.map { ($0.resultID, $0) })
            brokerFoodSearchRows = results.map { $0.addFoodSuggestionRow() }
            foodSearchState = results.isEmpty ? .empty : .ready(resultCount: results.count)
        } catch {
            brokerFoodSearchRows = []
            brokerFoodSearchResults = [:]
            foodSearchState = .failed(Self.foodSearchFailureMessage(for: error))
        }
    }

    private func makeDraft(
        meal: MealEstimate,
        sourceClass: FoodSourceClass,
        trustStatus: FoodTrustStatus
    ) -> FoodIntakeDraft {
        switch trustStatus {
        case .verified:
            return wallet.makeVerifiedDraft(meal: meal)
        case .selfIssued:
            return wallet.makeSelfIssuedDraft(meal: meal)
        case .estimated, .untrusted:
            return wallet.makeEstimatedDraft(meal: meal)
        }
    }

    private static func candidate(
        id: String,
        label: String,
        genericLabel: String,
        dishType: DishType,
        meal: MealEstimate,
        confidence: EstimateConfidence,
        assumptions: [FoodAssumption],
        evidence: [ProviderEvidence]
    ) -> FoodAnalysisCandidate {
        let variance = max(0, meal.varianceKcal)
        return FoodAnalysisCandidate(
            id: id,
            primaryLabel: label,
            genericLabel: genericLabel,
            dishType: dishType,
            portion: PortionEstimate(
                gramsMin: max(1, meal.amountGrams - max(1, meal.amountGrams / 6)),
                gramsMode: meal.amountGrams,
                gramsMax: meal.amountGrams + max(1, meal.amountGrams / 6)
            ),
            nutrition: NutritionRange(
                minKcal: max(0, meal.kcal - variance),
                modeKcal: meal.kcal,
                maxKcal: meal.kcal + variance
            ),
            macronutrients: meal.macronutrients ?? MealMacronutrients(
                proteinGrams: 0,
                carbohydrateGrams: 0,
                fatGrams: 0,
                fiberGrams: 0
            ),
            confidence: confidence,
            assumptions: assumptions,
            evidence: evidence,
            userConfirmationRequired: true
        )
    }

    private static func editedMeal(_ meal: MealEstimate, label: String, gramsMode: Int64) -> MealEstimate {
        let oldGrams = max(1, meal.amountGrams)
        let factor = Double(max(1, gramsMode)) / Double(oldGrams)
        return MealEstimate(
            label: label,
            kcal: max(0, Int64((Double(meal.kcal) * factor).rounded())),
            varianceKcal: max(0, Int64((Double(meal.varianceKcal) * factor).rounded())),
            amountGrams: max(1, gramsMode),
            servingGrams: max(1, gramsMode),
            servings: meal.servings,
            macronutrients: meal.macronutrients?.scaled(by: factor)
        )
    }

    private static func analysisFailure(for error: Error) -> FoodAnalysisFailure {
        guard let brokerError = error as? FoodAnalysisBrokerClientError else {
            if let urlError = error as? URLError, urlError.code == .timedOut {
                return FoodAnalysisFailure(
                    code: .timeout,
                    message: "Analysis took too long. Check your connection, try another photo, or enter the meal manually."
                )
            }
            if error is URLError {
                return FoodAnalysisFailure(
                    code: .network,
                    message: "MealMark could not reach the analysis service. Check your connection, then try again."
                )
            }
            return FoodAnalysisFailure(
                code: .unknown,
                message: "The analysis service did not return a usable food estimate. Try another photo or enter this meal manually."
            )
        }

        switch brokerError {
        case .invalidPayload:
            return FoodAnalysisFailure(
                code: .invalidPayload,
                message: "MealMark could not send this photo. Try another photo or enter the meal manually."
            )
        case .invalidResponse:
            return FoodAnalysisFailure(
                code: .invalidResponse,
                message: "The analysis service returned data MealMark could not read. Try again."
            )
        case let .httpStatus(status):
            return FoodAnalysisFailure(
                code: .httpStatus(status),
                message: "The analysis service returned HTTP \(status). Try again or enter the meal manually."
            )
        case let .brokerError(code, message, status):
            if code == "NO_FOOD_DETECTED" {
                return FoodAnalysisFailure(
                    code: .noFoodDetected,
                    message: message
                )
            }
            if code == "UPSTREAM_TIMEOUT" {
                return FoodAnalysisFailure(
                    code: .timeout,
                    message: "Analysis took too long. Check your connection, try another photo, or enter the meal manually."
                )
            }
            return FoodAnalysisFailure(
                code: .httpStatus(status),
                message: message.isEmpty ? "The analysis service returned \(code). Try again." : message
            )
        case .requestTimedOut:
            return FoodAnalysisFailure(
                code: .timeout,
                message: "Analysis took too long. Check your connection, try another photo, or enter the meal manually."
            )
        case .networkUnavailable:
            return FoodAnalysisFailure(
                code: .network,
                message: "MealMark could not reach the analysis service. Check your connection, then try again."
            )
        case .unsafeCandidate:
            return FoodAnalysisFailure(
                code: .unsafeCandidate,
                message: "The analysis service returned an unsafe food estimate. Try another photo or enter the meal manually."
            )
        }
    }

    private static func foodSearchFailureMessage(for error: Error) -> String {
        if let requestError = error as? BrokerFoodSearchError {
            switch requestError {
            case let .invalidRequest(reason):
                if reason.localizedCaseInsensitiveContains("barcode") {
                    return "Enter 8 to 14 UPC or EAN digits."
                }
                return "MealMark could not search that food. Check the text and try again."
            case .invalidResponse:
                return "Food lookup returned data MealMark could not read."
            case let .httpStatus(status):
                return "Food lookup returned HTTP \(status). Try again."
            case .unsafeResult:
                return "Food lookup returned a result that still needs safer review."
            }
        }

        if let brokerError = error as? FoodAnalysisBrokerClientError {
            switch brokerError {
            case let .httpStatus(status):
                return "Food lookup service returned HTTP \(status). Try again."
            case let .brokerError(code, message, status):
                if code == "UPSTREAM_TIMEOUT" {
                    return "Food lookup took too long. Check your connection and try again."
                }
                return message.isEmpty ? "Food lookup returned HTTP \(status). Try again." : message
            case .requestTimedOut:
                return "Food lookup took too long. Check your connection and try again."
            case .networkUnavailable:
                return "Food lookup could not reach the broker. Check that it is running on this network."
            case .invalidResponse:
                return "Food lookup service returned data MealMark could not read."
            case .unsafeCandidate:
                return "Food lookup returned a result that still needs safer review."
            case .invalidPayload:
                return "MealMark could not send this lookup request."
            }
        }

        if error is URLError {
            return "Food lookup could not reach the broker. Check that it is running on this network."
        }

        return "Food lookup failed. Try again, use photo, or enter the food manually."
    }
}
