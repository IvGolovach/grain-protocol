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
