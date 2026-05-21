import Foundation
import GrainFoodWallet

public enum BrokerFoodSearchError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidRequest(String)
    case invalidResponse
    case httpStatus(Int)
    case unsafeResult(String)

    public var description: String {
        switch self {
        case .invalidRequest(let reason):
            return "invalid search request: \(reason)"
        case .invalidResponse:
            return "invalid search response"
        case .httpStatus(let statusCode):
            return "broker returned HTTP \(statusCode)"
        case .unsafeResult(let reason):
            return "unsafe search result: \(reason)"
        }
    }
}

public struct BrokerFoodSearchRequest: Encodable, Equatable, Sendable {
    public var query: String?
    public var barcode: String?
    public var limit: Int
    public var locale: String?

    public init(
        query: String? = nil,
        barcode: String? = nil,
        limit: Int = 8,
        locale: String? = nil
    ) throws {
        let cleanQuery = Self.clean(query)
        let cleanBarcode = Self.normalizeBarcode(barcode)
        guard cleanQuery != nil || cleanBarcode != nil else {
            throw BrokerFoodSearchError.invalidRequest("query or barcode is required")
        }
        if let cleanQuery, cleanQuery.count > 160 {
            throw BrokerFoodSearchError.invalidRequest("query must be 160 characters or less")
        }
        if let barcode, cleanBarcode == nil, !barcode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw BrokerFoodSearchError.invalidRequest("barcode must contain 8 to 14 digits")
        }
        guard (1...20).contains(limit) else {
            throw BrokerFoodSearchError.invalidRequest("limit must be between 1 and 20")
        }
        let cleanLocale = Self.clean(locale)
        if let cleanLocale, cleanLocale.count > 32 {
            throw BrokerFoodSearchError.invalidRequest("locale must be 32 characters or less")
        }

        self.query = cleanQuery
        self.barcode = cleanBarcode
        self.limit = limit
        self.locale = cleanLocale
    }

    private static func clean(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public static func normalizeBarcode(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let digits = String(value.unicodeScalars.compactMap { scalar in
            (48...57).contains(scalar.value) ? Character(scalar) : nil
        })
        return (8...14).contains(digits.count) ? digits : nil
    }

    public static func preferredCameraBarcode(
        from values: [String?],
        allowsShortBarcode: Bool = false
    ) -> String? {
        let candidates = values.compactMap(normalizeBarcode)
            .filter { allowsShortBarcode || $0.count >= 12 }
        return candidates.max { lhs, rhs in
            cameraBarcodeRank(lhs) < cameraBarcodeRank(rhs)
        }
    }

    private static func cameraBarcodeRank(_ value: String) -> Int {
        switch value.count {
        case 13:
            return value.hasPrefix("0") ? 500 : 470
        case 12:
            return 490
        case 14:
            return 450
        case 8:
            return 120
        default:
            return 0
        }
    }
}

public struct CameraBarcodeStabilityTracker: Sendable {
    private var observationCounts: [String: Int]

    public init() {
        observationCounts = [:]
    }

    public mutating func observe(
        _ values: [String?],
        allowsShortBarcode: Bool = false,
        requiredObservations: Int = 2
    ) -> String? {
        guard let candidate = BrokerFoodSearchRequest.preferredCameraBarcode(
            from: values,
            allowsShortBarcode: allowsShortBarcode
        ) else {
            return nil
        }

        let count = (observationCounts[candidate] ?? 0) + 1
        observationCounts[candidate] = count
        return count >= max(1, requiredObservations) ? candidate : nil
    }

    public mutating func reset() {
        observationCounts.removeAll()
    }
}

public protocol BrokerFoodSearchClient: Sendable {
    func searchFood(_ request: BrokerFoodSearchRequest) async throws -> [BrokerFoodSearchResult]
}

public enum BrokerFoodSearchMatchType: String, Codable, Equatable, Sendable {
    case name
    case barcode
}

public struct BrokerFoodSearchResult: Decodable, Equatable, Sendable {
    public struct Match: Decodable, Equatable, Sendable {
        public var type: BrokerFoodSearchMatchType
        public var score: Double
    }

    public struct Serving: Decodable, Equatable, Sendable {
        public var basis: String
        public var servingSizeG: Double?
        public var servingLabel: String?

        private enum CodingKeys: String, CodingKey {
            case basis
            case servingSizeG = "serving_size_g"
            case servingLabel = "serving_label"
        }
    }

    public struct Per100gNutrition: Decodable, Equatable, Sendable {
        public var kcal: Double
        public var proteinG: Double
        public var carbohydrateG: Double
        public var fatG: Double
        public var fiberG: Double?

        private enum CodingKeys: String, CodingKey {
            case kcal
            case proteinG = "protein_g"
            case carbohydrateG = "carbohydrate_g"
            case fatG = "fat_g"
            case fiberG = "fiber_g"
        }
    }

    public struct Nutrition: Decodable, Equatable, Sendable {
        public var per100g: Per100gNutrition

        private enum CodingKeys: String, CodingKey {
            case per100g = "per_100g"
        }
    }

    public struct Evidence: Decodable, Equatable, Sendable {
        public var provider: String
        public var providerID: String
        public var matchedName: String
        public var matchType: String
        public var sourceLabel: String
        public var trustLabel: String

        private enum CodingKeys: String, CodingKey {
            case provider
            case providerID = "provider_id"
            case matchedName = "matched_name"
            case matchType = "match_type"
            case sourceLabel = "source_label"
            case trustLabel = "trust_label"
        }
    }

    public var resultID: String
    public var primaryLabel: String
    public var genericLabel: String
    public var brandLabel: String?
    public var category: String
    public var sourceLabel: String
    public var trustLabel: String
    public var match: Match
    public var serving: Serving
    public var nutrition: Nutrition
    public var providerEvidence: [Evidence]
    public var userConfirmationRequired: Bool

    private enum CodingKeys: String, CodingKey {
        case resultID = "result_id"
        case primaryLabel = "primary_label"
        case genericLabel = "generic_label"
        case brandLabel = "brand_label"
        case category
        case sourceLabel = "source_label"
        case trustLabel = "trust_label"
        case match
        case serving
        case nutrition
        case providerEvidence = "provider_evidence"
        case userConfirmationRequired = "user_confirmation_required"
    }

    public func addFoodSuggestionRow() -> AddFoodSuggestionRow {
        AddFoodSuggestionRow(
            id: resultID,
            kind: .providerMatch,
            title: primaryLabel,
            subtitle: "\(portionEstimate.label) | \(nutritionRange.label)",
            sourceLabel: match.type == .barcode ? "Barcode match" : FoodEvidenceSource.defaultLabel(for: sourceLabel),
            evidence: providerEvidence.map { $0.providerEvidence(isBarcode: match.type == .barcode) },
            confidence: confidence,
            nutrition: nutritionRange,
            portion: portionEstimate,
            searchText: [
                primaryLabel,
                genericLabel,
                brandLabel,
                category,
                sourceLabel,
                trustLabel,
                providerEvidence.map(\.matchedName).joined(separator: " "),
            ].compactMap { $0 }.joined(separator: " ")
        )
    }

    public func candidate() throws -> FoodAnalysisCandidate {
        guard userConfirmationRequired else {
            throw BrokerFoodSearchError.unsafeResult("broker search result must require user confirmation")
        }
        let matchAssumption = match.type == .barcode
            ? FoodAssumption(id: "barcode-match", label: "barcode matched packaged food database")
            : FoodAssumption(id: "provider-name-match", label: "matched provider nutrition database")
        return FoodAnalysisCandidate(
            id: resultID,
            primaryLabel: primaryLabel,
            genericLabel: genericLabel,
            dishType: dishType,
            portion: portionEstimate,
            nutrition: nutritionRange,
            macronutrients: macronutrients,
            confidence: confidence,
            assumptions: [
                matchAssumption,
                FoodAssumption(id: "review-portion", label: "review serving before saving"),
            ],
            evidence: providerEvidence.map { $0.providerEvidence(isBarcode: match.type == .barcode) },
            userConfirmationRequired: true
        )
    }

    public func personalIngredient() -> PersonalFoodIngredient {
        PersonalFoodIngredient(
            id: "personal-provider-\(Self.slug(resultID))",
            name: primaryLabel,
            sourceServingGrams: Double(servingGrams),
            sourceServingKcal: modeKcal,
            kcalPer100Grams: nutrition.per100g.kcal,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: nutrition.per100g.proteinG,
                carbohydrateGrams: nutrition.per100g.carbohydrateG,
                fatGrams: nutrition.per100g.fatG,
                fiberGrams: nutrition.per100g.fiberG
            )
        )
    }

    private var servingGrams: Int64 {
        max(1, Int64((serving.servingSizeG ?? 100).rounded()))
    }

    private var modeKcal: Int64 {
        max(0, Int64((nutrition.per100g.kcal * Double(servingGrams) / 100).rounded()))
    }

    private var varianceKcal: Int64 {
        if match.type == .barcode {
            return 0
        }
        return max(1, Int64((Double(modeKcal) * 0.10).rounded()))
    }

    private var portionEstimate: PortionEstimate {
        PortionEstimate(
            gramsMin: max(1, servingGrams - max(1, servingGrams / 10)),
            gramsMode: servingGrams,
            gramsMax: servingGrams + max(1, servingGrams / 10)
        )
    }

    private var nutritionRange: NutritionRange {
        NutritionRange(
            minKcal: max(0, modeKcal - varianceKcal),
            modeKcal: modeKcal,
            maxKcal: modeKcal + varianceKcal
        )
    }

    private var macronutrients: MealMacronutrients {
        let factor = Double(servingGrams) / 100
        return MealMacronutrients(
            proteinGrams: nutrition.per100g.proteinG * factor,
            carbohydrateGrams: nutrition.per100g.carbohydrateG * factor,
            fatGrams: nutrition.per100g.fatG * factor,
            fiberGrams: nutrition.per100g.fiberG.map { $0 * factor }
        )
    }

    private var confidence: EstimateConfidence {
        if match.type == .barcode {
            return .high
        }
        if match.score >= 0.90 {
            return .medium
        }
        return .low
    }

    private var dishType: DishType {
        if match.type == .barcode || brandLabel != nil || category.localizedCaseInsensitiveContains("packaged") {
            return .packaged
        }
        if category.localizedCaseInsensitiveContains("common") {
            return .single
        }
        return .unknown
    }

    private static func slug(_ value: String) -> String {
        let slug = value
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return slug.isEmpty ? "food" : slug
    }
}

private extension BrokerFoodSearchResult.Evidence {
    func providerEvidence(isBarcode: Bool) -> ProviderEvidence {
        ProviderEvidence(
            provider: provider,
            providerID: providerID,
            matchedName: matchedName,
            servingBasis: matchType,
            sourceLabelID: isBarcode ? "barcode_provider" : sourceLabel,
            matchType: matchType,
            trustLabel: trustLabel
        )
    }
}

public struct MockBrokerFoodSearchClient: BrokerFoodSearchClient {
    public init() {}

    public func searchFood(_ request: BrokerFoodSearchRequest) async throws -> [BrokerFoodSearchResult] {
        let json = Self.fixtureJSON(for: request)
        guard let json else {
            return []
        }
        let data = Data(json.utf8)
        return try JSONDecoder().decode(BrokerFoodSearchEnvelope.self, from: data).results
    }

    private static func fixtureJSON(for request: BrokerFoodSearchRequest) -> String? {
        if request.barcode == "012345678905" {
            return kombuchaSearchJSON
        }
        return nil
    }

    private static let kombuchaSearchJSON = """
    {
      "ok": true,
      "results": [
        {
          "result_id": "food-search:fixture-kombucha-bottle",
          "primary_label": "Ginger lemon kombucha",
          "generic_label": "kombucha",
          "brand_label": "Grain Fixture Kitchen",
          "category": "packaged_beverage",
          "source_label": "deterministic_fixture",
          "trust_label": "barcode_fixture",
          "match": {"type": "barcode", "score": 1},
          "serving": {"basis": "per_100g", "serving_size_g": 473, "serving_label": "1 bottle (473 ml)"},
          "nutrition": {"per_100g": {"kcal": 17, "protein_g": 0, "carbohydrate_g": 4.2, "fat_g": 0, "fiber_g": 0}},
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
    """
}

public struct BrokerFoodSearchEnvelope: Decodable, Sendable {
    public var ok: Bool
    public var results: [BrokerFoodSearchResult]
}
