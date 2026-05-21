import Foundation
import GrainFoodWallet

public enum FoodCaptureExample: String, CaseIterable, Sendable {
    case fujiApple
    case mushroomRisotto

    public var displayName: String {
        switch self {
        case .fujiApple:
            return "Fuji apple"
        case .mushroomRisotto:
            return "Mushroom risotto"
        }
    }
}

public enum DishType: String, Codable, Equatable, Sendable {
    case single
    case mixed
    case packaged
    case unknown
}

public enum EstimateConfidence: String, Codable, Equatable, Sendable {
    case high
    case medium
    case low

    public var label: String {
        switch self {
        case .high:
            return "High confidence"
        case .medium:
            return "Medium confidence"
        case .low:
            return "Low confidence"
        }
    }
}

public struct NutritionRange: Codable, Equatable, Sendable {
    public var minKcal: Int64
    public var modeKcal: Int64
    public var maxKcal: Int64

    public init(minKcal: Int64, modeKcal: Int64, maxKcal: Int64) {
        self.minKcal = minKcal
        self.modeKcal = modeKcal
        self.maxKcal = maxKcal
    }

    public var varianceKcal: Int64 {
        max(0, (maxKcal - minKcal) / 2)
    }

    public var label: String {
        "\(minKcal)-\(maxKcal) kcal"
    }
}

public struct PortionEstimate: Codable, Equatable, Sendable {
    public var gramsMin: Int64
    public var gramsMode: Int64
    public var gramsMax: Int64

    public init(gramsMin: Int64, gramsMode: Int64, gramsMax: Int64) {
        self.gramsMin = gramsMin
        self.gramsMode = gramsMode
        self.gramsMax = gramsMax
    }

    public var label: String {
        "about \(gramsMode) g"
    }
}

public struct FoodAssumption: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var label: String
    public var isEnabled: Bool

    public init(id: String, label: String, isEnabled: Bool = true) {
        self.id = id
        self.label = label
        self.isEnabled = isEnabled
    }
}

public struct ProviderEvidence: Codable, Equatable, Sendable {
    public var provider: String
    public var providerID: String
    public var matchedName: String
    public var servingBasis: String
    public var sourceLabelID: String?
    public var matchType: String?
    public var trustLabel: String?

    public init(
        provider: String,
        providerID: String,
        matchedName: String,
        servingBasis: String,
        sourceLabelID: String? = nil,
        matchType: String? = nil,
        trustLabel: String? = nil
    ) {
        self.provider = provider
        self.providerID = providerID
        self.matchedName = matchedName
        self.servingBasis = servingBasis
        self.sourceLabelID = Self.clean(sourceLabelID)
        self.matchType = Self.clean(matchType)
        self.trustLabel = Self.clean(trustLabel)
    }

    public var source: FoodEvidenceSource {
        FoodEvidenceSource(id: sourceLabelID ?? provider)
    }

    public var sourceLabel: String {
        source.label
    }

    public var normalizedProvider: String {
        FoodEvidenceSource.normalize(provider)
    }

    private static func clean(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

public struct FoodEvidenceSource: Codable, Equatable, Sendable {
    public var id: String
    public var label: String

    public init(id: String, label: String? = nil) {
        let normalizedID = Self.normalize(id)
        self.id = normalizedID
        self.label = Self.clean(label) ?? Self.defaultLabel(for: normalizedID)
    }

    public static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }

    public static func defaultLabel(for id: String) -> String {
        switch normalize(id) {
        case "visible_nutrition_label":
            return "Label read"
        case "barcode_provider":
            return "Barcode match"
        case "open_food_facts":
            return "Barcode match"
        case "food_wallet_template":
            return "Template"
        case "food_wallet_recipe":
            return "Recipe"
        case "food_wallet_history":
            return "Recent"
        case "food_wallet_ingredient_catalog":
            return "Ingredient catalog"
        case "food_wallet_personal_ingredient":
            return "Personal ingredient"
        case "usda_fdc":
            return "USDA estimate"
        case "curated_cache":
            return "Curated estimate"
        case "on_device_photo_heuristic":
            return "Photo estimate"
        case "grain_serving_offer":
            return "Grain serving"
        case "mealmark_qr":
            return "MealMark QR"
        case "deterministic_fixture":
            return "Food search match"
        case "curated_fixture":
            return "Curated food data"
        case "broker_test":
            return "Broker test"
        case "":
            return "Unknown source"
        default:
            return normalize(id)
                .split(separator: "_")
                .map { word in
                    word.prefix(1).uppercased() + word.dropFirst()
                }
                .joined(separator: " ")
        }
    }

    private static func clean(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

public struct MealMarkProvenanceSnapshot: Identifiable, Codable, Equatable, Sendable {
    public var candidateID: String
    public var draftID: String?
    public var entryID: String?
    public var sourceClass: String
    public var trustStatus: String
    public var primarySourceLabel: String
    public var sourceLabels: [String]
    public var evidence: [ProviderEvidence]

    public var id: String {
        entryID ?? draftID ?? candidateID
    }

    public init(
        candidateID: String,
        draftID: String? = nil,
        entryID: String? = nil,
        sourceClass: String,
        trustStatus: String,
        primarySourceLabel: String,
        sourceLabels: [String],
        evidence: [ProviderEvidence]
    ) {
        self.candidateID = candidateID
        self.draftID = Self.clean(draftID)
        self.entryID = Self.clean(entryID)
        self.sourceClass = sourceClass
        self.trustStatus = trustStatus
        self.primarySourceLabel = Self.clean(primarySourceLabel) ?? "Unknown source"
        self.sourceLabels = Self.uniqueNonEmpty(sourceLabels)
        if self.sourceLabels.isEmpty {
            self.sourceLabels = [self.primarySourceLabel]
        }
        self.evidence = evidence
    }

    public init(candidate: FoodAnalysisCandidate, draft: FoodIntakeDraft, entryID: String? = nil) {
        self.init(
            candidateID: candidate.id,
            draftID: draft.draftID,
            entryID: entryID,
            sourceClass: draft.sourceClass.rawValue,
            trustStatus: draft.trustStatus.rawValue,
            primarySourceLabel: candidate.primarySourceLabel(trustStatus: draft.trustStatus),
            sourceLabels: candidate.sourceLabels,
            evidence: candidate.evidence
        )
    }

    public init(candidate: FoodAnalysisCandidate, entry: FoodIntakeEntry) {
        self.init(
            candidateID: candidate.id,
            draftID: entry.draftID,
            entryID: entry.entryID,
            sourceClass: entry.sourceClass.rawValue,
            trustStatus: entry.trustStatus.rawValue,
            primarySourceLabel: candidate.primarySourceLabel(trustStatus: entry.trustStatus),
            sourceLabels: candidate.sourceLabels,
            evidence: candidate.evidence
        )
    }

    private static func clean(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func uniqueNonEmpty(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else {
                continue
            }
            seen.insert(trimmed)
            result.append(trimmed)
        }
        return result
    }
}

public enum AddFoodSuggestionKind: String, Codable, Equatable, Sendable {
    case analysisCandidate = "analysis_candidate"
    case providerMatch = "provider_match"
    case recentEntry = "recent_entry"
    case savedTemplate = "saved_template"
    case savedRecipe = "saved_recipe"
    case personalIngredient = "personal_ingredient"
    case manual
}

public struct AddFoodSearchQuery: Codable, Equatable, Sendable {
    public var rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var normalizedValue: String {
        Self.normalize(rawValue)
    }

    public var tokens: [String] {
        normalizedValue.split(separator: " ").map(String.init)
    }

    public var isEmpty: Bool {
        normalizedValue.isEmpty
    }

    public func matches(_ row: AddFoodSuggestionRow) -> Bool {
        guard !isEmpty else {
            return true
        }
        let haystack = row.normalizedSearchText
        return tokens.allSatisfy { haystack.contains($0) }
    }

    public static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

public struct AddFoodSuggestionRow: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var kind: AddFoodSuggestionKind
    public var title: String
    public var subtitle: String?
    public var sourceLabel: String
    public var evidence: [ProviderEvidence]
    public var confidence: EstimateConfidence?
    public var nutrition: NutritionRange?
    public var portion: PortionEstimate?
    public var searchText: String

    public init(
        id: String,
        kind: AddFoodSuggestionKind,
        title: String,
        subtitle: String? = nil,
        sourceLabel: String,
        evidence: [ProviderEvidence] = [],
        confidence: EstimateConfidence? = nil,
        nutrition: NutritionRange? = nil,
        portion: PortionEstimate? = nil,
        searchText: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.subtitle = Self.clean(subtitle)
        self.sourceLabel = Self.clean(sourceLabel) ?? "Unknown source"
        self.evidence = evidence
        self.confidence = confidence
        self.nutrition = nutrition
        self.portion = portion
        self.searchText = Self.clean(searchText) ?? Self.defaultSearchText(
            title: self.title,
            subtitle: self.subtitle,
            sourceLabel: self.sourceLabel,
            evidence: evidence
        )
    }

    public var normalizedSearchText: String {
        AddFoodSearchQuery.normalize(searchText)
    }

    public func matches(_ query: AddFoodSearchQuery) -> Bool {
        query.matches(self)
    }

    private static func clean(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func defaultSearchText(
        title: String,
        subtitle: String?,
        sourceLabel: String,
        evidence: [ProviderEvidence]
    ) -> String {
        var parts = [title, sourceLabel].compactMap(Self.clean)
        if let subtitle = Self.clean(subtitle) {
            parts.append(subtitle)
        }
        let evidenceText = evidence.flatMap { item in
            [item.provider, item.providerID, item.matchedName, item.servingBasis, item.sourceLabel]
        }
        return (parts + evidenceText).joined(separator: " ")
    }
}

public struct FoodPhotoFeatures: Codable, Equatable, Sendable {
    public var redBalance: Double
    public var greenBalance: Double
    public var blueBalance: Double
    public var brightness: Double

    public init(redBalance: Double, greenBalance: Double, blueBalance: Double, brightness: Double) {
        self.redBalance = redBalance
        self.greenBalance = greenBalance
        self.blueBalance = blueBalance
        self.brightness = brightness
    }

    public static let unknown = FoodPhotoFeatures(
        redBalance: 0,
        greenBalance: 0,
        blueBalance: 0,
        brightness: 0
    )
}

public struct CapturedMealPhoto: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var widthPixels: Int
    public var heightPixels: Int
    public var compressedByteCount: Int
    public var contentType: String
    public var features: FoodPhotoFeatures

    public init(
        id: String,
        widthPixels: Int,
        heightPixels: Int,
        compressedByteCount: Int,
        contentType: String = "image/jpeg",
        features: FoodPhotoFeatures = .unknown
    ) {
        self.id = id
        self.widthPixels = widthPixels
        self.heightPixels = heightPixels
        self.compressedByteCount = compressedByteCount
        self.contentType = contentType
        self.features = features
    }

    public static let uiTestFujiApple = CapturedMealPhoto(
        id: "ui-test-fuji-apple-photo",
        widthPixels: 1200,
        heightPixels: 1600,
        compressedByteCount: 260_000,
        features: FoodPhotoFeatures(redBalance: 0.58, greenBalance: 0.36, blueBalance: 0.20, brightness: 0.62)
    )
}

public struct TransientMealPhotoPayload: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public var photo: CapturedMealPhoto
    public var byteCount: Int {
        jpegDataStorage.count
    }

    private let jpegDataStorage: Data

    public init(photo: CapturedMealPhoto, jpegData: Data) {
        self.photo = photo
        self.jpegDataStorage = jpegData
    }

    public func withJPEGData<Result>(_ body: (Data) throws -> Result) rethrows -> Result {
        try body(jpegDataStorage)
    }

    public var description: String {
        "TransientMealPhotoPayload(photoID: \(photo.id), byteCount: \(byteCount), bytes: <redacted>)"
    }

    public var debugDescription: String {
        description
    }
}

public struct FoodAnalysisCandidate: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var primaryLabel: String
    public var genericLabel: String
    public var dishType: DishType
    public var portion: PortionEstimate
    public var nutrition: NutritionRange
    public var macronutrients: MealMacronutrients
    public var confidence: EstimateConfidence
    public var assumptions: [FoodAssumption]
    public var evidence: [ProviderEvidence]
    public var userConfirmationRequired: Bool

    public init(
        id: String,
        primaryLabel: String,
        genericLabel: String,
        dishType: DishType,
        portion: PortionEstimate,
        nutrition: NutritionRange,
        macronutrients: MealMacronutrients,
        confidence: EstimateConfidence,
        assumptions: [FoodAssumption],
        evidence: [ProviderEvidence],
        userConfirmationRequired: Bool = true
    ) {
        self.id = id
        self.primaryLabel = primaryLabel
        self.genericLabel = genericLabel
        self.dishType = dishType
        self.portion = portion
        self.nutrition = nutrition
        self.macronutrients = macronutrients
        self.confidence = confidence
        self.assumptions = assumptions
        self.evidence = evidence
        self.userConfirmationRequired = userConfirmationRequired
    }

    public var trustStatus: FoodTrustStatus {
        .estimated
    }

    public var sourceClass: FoodSourceClass {
        .estimated
    }

    public var sourceLabels: [String] {
        var seen: Set<String> = []
        var labels: [String] = []
        for label in evidence.map(\.sourceLabel) {
            guard !seen.contains(label) else {
                continue
            }
            seen.insert(label)
            labels.append(label)
        }
        return labels
    }

    public func primarySourceLabel(trustStatus: FoodTrustStatus = .estimated) -> String {
        if trustStatus == .verified {
            return trustStatus.label
        }

        let providers = Set(evidence.map(\.normalizedProvider))
        let sourceIDs = Set(evidence.map { FoodEvidenceSource.normalize($0.sourceLabelID ?? "") })
        for provider in [
            "visible_nutrition_label",
            "barcode_provider",
            "open_food_facts",
            "food_wallet_template",
            "food_wallet_recipe",
            "food_wallet_history",
            "food_wallet_ingredient_catalog",
            "food_wallet_personal_ingredient",
            "usda_fdc",
            "curated_cache",
            "on_device_photo_heuristic",
        ] where providers.contains(provider) || sourceIDs.contains(provider) {
            return FoodEvidenceSource.defaultLabel(for: provider)
        }

        return sourceLabels.first ?? trustStatus.label
    }

    public func provenanceSnapshot(
        draftID: String? = nil,
        entryID: String? = nil,
        sourceClass: FoodSourceClass,
        trustStatus: FoodTrustStatus
    ) -> MealMarkProvenanceSnapshot {
        MealMarkProvenanceSnapshot(
            candidateID: id,
            draftID: draftID,
            entryID: entryID,
            sourceClass: sourceClass.rawValue,
            trustStatus: trustStatus.rawValue,
            primarySourceLabel: primarySourceLabel(trustStatus: trustStatus),
            sourceLabels: sourceLabels,
            evidence: evidence
        )
    }

    public func addFoodSuggestionRow(kind: AddFoodSuggestionKind = .analysisCandidate) -> AddFoodSuggestionRow {
        AddFoodSuggestionRow(
            id: id,
            kind: kind,
            title: primaryLabel,
            subtitle: "\(portion.label) | \(nutrition.label)",
            sourceLabel: primarySourceLabel(),
            evidence: evidence,
            confidence: confidence,
            nutrition: nutrition,
            portion: portion
        )
    }

    public func mealEstimate() -> MealEstimate {
        MealEstimate(
            label: primaryLabel,
            kcal: nutrition.modeKcal,
            varianceKcal: nutrition.varianceKcal,
            amountGrams: portion.gramsMode,
            servingGrams: portion.gramsMode,
            servings: 1,
            macronutrients: macronutrients
        )
    }
}

public protocol FoodAnalysisClient: Sendable {
    func estimate(example: FoodCaptureExample) async throws -> FoodAnalysisCandidate
    func estimate(photo: CapturedMealPhoto) async throws -> FoodAnalysisCandidate
    func estimate(photoPayload: TransientMealPhotoPayload) async throws -> FoodAnalysisCandidate
}

public extension FoodAnalysisClient {
    func estimate(photoPayload: TransientMealPhotoPayload) async throws -> FoodAnalysisCandidate {
        try await estimate(photo: photoPayload.photo)
    }
}

public struct MockFoodAnalysisClient: FoodAnalysisClient {
    public init() {}

    public func estimate(example: FoodCaptureExample) async throws -> FoodAnalysisCandidate {
        switch example {
        case .fujiApple:
            return FoodAnalysisCandidate(
                id: "mock-fuji-apple",
                primaryLabel: "Fuji apple",
                genericLabel: "apple",
                dishType: .single,
                portion: PortionEstimate(gramsMin: 140, gramsMode: 170, gramsMax: 210),
                nutrition: NutritionRange(minKcal: 90, modeKcal: 102, maxKcal: 115),
                macronutrients: MealMacronutrients(
                    proteinGrams: 0.5,
                    carbohydrateGrams: 27,
                    fatGrams: 0.3,
                    fiberGrams: 4.8
                ),
                confidence: .medium,
                assumptions: [
                    FoodAssumption(id: "single-item", label: "single medium apple"),
                    FoodAssumption(id: "no-visible-additions", label: "no visible added ingredients"),
                ],
                evidence: [
                    ProviderEvidence(
                        provider: "curated_cache",
                        providerID: "fruit.apple.fuji.medium",
                        matchedName: "Fuji apple, medium",
                        servingBasis: "per_100g"
                    ),
                ]
            )
        case .mushroomRisotto:
            return FoodAnalysisCandidate(
                id: "mock-mushroom-risotto",
                primaryLabel: "Mushroom risotto",
                genericLabel: "risotto",
                dishType: .mixed,
                portion: PortionEstimate(gramsMin: 260, gramsMode: 320, gramsMax: 390),
                nutrition: NutritionRange(minKcal: 520, modeKcal: 640, maxKcal: 760),
                macronutrients: MealMacronutrients(
                    proteinGrams: 14,
                    carbohydrateGrams: 78,
                    fatGrams: 24,
                    fiberGrams: 4
                ),
                confidence: .low,
                assumptions: [
                    FoodAssumption(id: "rice-base", label: "rice base"),
                    FoodAssumption(id: "butter-oil", label: "butter or oil likely"),
                    FoodAssumption(id: "cheese", label: "cheese likely"),
                    FoodAssumption(id: "mushrooms", label: "mushrooms visible"),
                    FoodAssumption(id: "no-meat", label: "no visible meat"),
                    FoodAssumption(id: "restaurant-portion", label: "restaurant portion"),
                ],
                evidence: [
                    ProviderEvidence(
                        provider: "curated_cache",
                        providerID: "dish.risotto.mushroom.restaurant",
                        matchedName: "restaurant-style mushroom risotto",
                        servingBasis: "recipe_component"
                    ),
                    ProviderEvidence(
                        provider: "usda_fdc",
                        providerID: "generic-cooked-rice-mushroom-cheese",
                        matchedName: "rice dish with cheese and mushrooms",
                        servingBasis: "per_100g"
                    ),
                ]
            )
        }
    }

    public func estimate(photo: CapturedMealPhoto) async throws -> FoodAnalysisCandidate {
        if looksLikeSingleFruit(photo.features) {
            var candidate = try await estimate(example: .fujiApple)
            candidate.id = "mock-photo-fuji-apple"
            candidate.assumptions.append(
                FoodAssumption(id: "photo-color-heuristic", label: "photo features look like a single fruit")
            )
            candidate.evidence.append(
                ProviderEvidence(
                    provider: "on_device_photo_heuristic",
                    providerID: photo.id,
                    matchedName: "captured meal photo",
                    servingBasis: "temporary_photo_features"
                )
            )
            return candidate
        }

        if looksLikeWarmMixedDish(photo.features) {
            var candidate = try await estimate(example: .mushroomRisotto)
            candidate.id = "mock-photo-mushroom-risotto"
            candidate.evidence.append(
                ProviderEvidence(
                    provider: "on_device_photo_heuristic",
                    providerID: photo.id,
                    matchedName: "captured meal photo",
                    servingBasis: "temporary_photo_features"
                )
            )
            return candidate
        }

        return FoodAnalysisCandidate(
            id: "mock-photo-generic-meal",
            primaryLabel: "Captured meal",
            genericLabel: "meal",
            dishType: .unknown,
            portion: PortionEstimate(gramsMin: 180, gramsMode: 300, gramsMax: 480),
            nutrition: NutritionRange(minKcal: 350, modeKcal: 560, maxKcal: 820),
            macronutrients: MealMacronutrients(
                proteinGrams: 18,
                carbohydrateGrams: 62,
                fatGrams: 21,
                fiberGrams: 6
            ),
            confidence: .low,
            assumptions: [
                FoodAssumption(id: "photo-only", label: "photo-only estimate"),
                FoodAssumption(id: "portion-uncertain", label: "portion size needs review"),
                FoodAssumption(id: "manual-confirmation", label: "user confirmation required"),
            ],
            evidence: [
                ProviderEvidence(
                    provider: "on_device_photo_heuristic",
                    providerID: photo.id,
                    matchedName: "captured meal photo",
                    servingBasis: "temporary_photo_features"
                ),
            ]
        )
    }

    private func looksLikeSingleFruit(_ features: FoodPhotoFeatures) -> Bool {
        features.brightness > 0.35 && features.redBalance > 0.45 && features.greenBalance > 0.25
    }

    private func looksLikeWarmMixedDish(_ features: FoodPhotoFeatures) -> Bool {
        features.brightness > 0.25 && features.redBalance >= features.blueBalance && features.greenBalance >= features.blueBalance
    }
}
