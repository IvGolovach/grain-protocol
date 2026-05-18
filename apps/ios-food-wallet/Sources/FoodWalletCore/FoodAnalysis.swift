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

    public init(provider: String, providerID: String, matchedName: String, servingBasis: String) {
        self.provider = provider
        self.providerID = providerID
        self.matchedName = matchedName
        self.servingBasis = servingBasis
    }
}

public struct FoodAnalysisCandidate: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var primaryLabel: String
    public var genericLabel: String
    public var dishType: DishType
    public var portion: PortionEstimate
    public var nutrition: NutritionRange
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

    public func mealEstimate() -> MealEstimate {
        MealEstimate(
            label: primaryLabel,
            kcal: nutrition.modeKcal,
            varianceKcal: nutrition.varianceKcal,
            amountGrams: portion.gramsMode,
            servingGrams: portion.gramsMode,
            servings: 1
        )
    }
}

public protocol FoodAnalysisClient: Sendable {
    func estimate(example: FoodCaptureExample) async throws -> FoodAnalysisCandidate
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
}
