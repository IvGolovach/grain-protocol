import CryptoKit
import Foundation
import GrainFoodWallet

public struct SavedFoodTemplate: Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var subtitle: String
    public var kcal: Int64
    public var varianceKcal: Int64
    public var amountGrams: Int64
    public var servingGrams: Int64
    public var servings: Int64
    public var macronutrients: MealMacronutrients

    public init(
        id: String,
        title: String,
        subtitle: String,
        kcal: Int64,
        varianceKcal: Int64,
        amountGrams: Int64,
        servingGrams: Int64,
        servings: Int64 = 1,
        macronutrients: MealMacronutrients
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.kcal = kcal
        self.varianceKcal = varianceKcal
        self.amountGrams = amountGrams
        self.servingGrams = servingGrams
        self.servings = servings
        self.macronutrients = macronutrients
    }

    public var mealEstimate: MealEstimate {
        MealEstimate(
            label: title,
            kcal: kcal,
            varianceKcal: varianceKcal,
            amountGrams: amountGrams,
            servingGrams: servingGrams,
            servings: servings,
            macronutrients: macronutrients
        )
    }

    public static let defaultTemplates: [SavedFoodTemplate] = []
}

public struct SavedFoodRecipeIngredient: Identifiable, Equatable, Sendable {
    public var id: String
    public var label: String
    public var grams: Int64
    public var kcal: Int64

    public init(id: String, label: String, grams: Int64, kcal: Int64) {
        self.id = id
        self.label = label
        self.grams = grams
        self.kcal = kcal
    }
}

public struct SavedFoodRecipe: Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var subtitle: String
    public var totalGrams: Int64
    public var totalKcal: Int64
    public var macronutrients: MealMacronutrients
    public var ingredients: [SavedFoodRecipeIngredient]

    public init(
        id: String,
        title: String,
        subtitle: String,
        totalGrams: Int64,
        totalKcal: Int64,
        macronutrients: MealMacronutrients,
        ingredients: [SavedFoodRecipeIngredient]
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.totalGrams = totalGrams
        self.totalKcal = totalKcal
        self.macronutrients = macronutrients
        self.ingredients = ingredients
    }

    public func mealEstimate(consumedFraction: Double) -> MealEstimate {
        let bounded = min(1, max(0.05, consumedFraction))
        let grams = Int64((Double(totalGrams) * bounded).rounded())
        let kcal = Int64((Double(totalKcal) * bounded).rounded())
        return MealEstimate(
            label: title,
            kcal: kcal,
            varianceKcal: max(8, Int64((Double(kcal) * 0.08).rounded())),
            amountGrams: grams,
            servingGrams: totalGrams,
            servings: 1,
            macronutrients: macronutrients.scaled(by: bounded)
        )
    }

    public static let defaultRecipes: [SavedFoodRecipe] = []
}

public struct FoodMealIngredientInput: Equatable, Sendable {
    public var name: String
    public var grams: Int64

    public init(name: String, grams: Int64) {
        self.name = name
        self.grams = grams
    }
}

public enum FoodMealDraftCreationResult: Error, Equatable, Sendable, CustomStringConvertible {
    case created
    case emptyTitle
    case noIngredients
    case invalidGrams(String)
    case unknownIngredient(String)

    public var description: String {
        switch self {
        case .created:
            return "created"
        case .emptyTitle:
            return "emptyTitle"
        case .noIngredients:
            return "noIngredients"
        case let .invalidGrams(name):
            return "invalidGrams(\(name))"
        case let .unknownIngredient(name):
            return "unknownIngredient(\(name))"
        }
    }
}

public struct PersonalFoodIngredient: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var sourceServingGrams: Double
    public var sourceServingKcal: Int64
    public var kcalPer100Grams: Double
    public var macronutrientsPer100Grams: MealMacronutrients

    public init(
        id: String,
        name: String,
        sourceServingGrams: Double,
        sourceServingKcal: Int64,
        kcalPer100Grams: Double,
        macronutrientsPer100Grams: MealMacronutrients
    ) {
        self.id = id
        self.name = name
        self.sourceServingGrams = sourceServingGrams
        self.sourceServingKcal = sourceServingKcal
        self.kcalPer100Grams = kcalPer100Grams
        self.macronutrientsPer100Grams = macronutrientsPer100Grams
    }
}

public enum FoodPersonalIngredientSaveResult: Error, Equatable, Sendable, CustomStringConvertible {
    case saved
    case emptyName
    case invalidServingGrams
    case invalidCalories
    case invalidMacro(String)

    public var description: String {
        switch self {
        case .saved:
            return "saved"
        case .emptyName:
            return "emptyName"
        case .invalidServingGrams:
            return "invalidServingGrams"
        case .invalidCalories:
            return "invalidCalories"
        case let .invalidMacro(name):
            return "invalidMacro(\(name))"
        }
    }
}

public struct FoodWalletExportBundle: Codable, Equatable, Sendable {
    public var schema: String
    public var version: Int
    public var generatedAt: String
    public var totals: FoodWalletExportTotals
    public var entries: [FoodWalletExportEntry]
    public var templates: [FoodWalletExportTemplate]
    public var recipes: [FoodWalletExportRecipe]
    public var privacy: FoodWalletExportPrivacy
    public var manifest: FoodWalletExportManifest
}

public struct FoodWalletExportTotals: Codable, Equatable, Sendable {
    public var entryCount: Int
    public var sumMeanKcal: Int64
    public var sumVarianceKcal: Int64
}

public struct FoodWalletExportEntry: Codable, Equatable, Sendable {
    public var entryID: String
    public var draftID: String
    public var dateKey: String
    public var label: String
    public var kcal: Int64
    public var varianceKcal: Int64
    public var amountGrams: Int64
    public var proteinGrams: Double?
    public var carbohydrateGrams: Double?
    public var fatGrams: Double?
    public var fiberGrams: Double?
    public var sourceClass: String
    public var trustStatus: String
}

public struct FoodWalletExportTemplate: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var kcal: Int64
    public var amountGrams: Int64
}

public struct FoodWalletExportRecipe: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var totalKcal: Int64
    public var totalGrams: Int64
    public var ingredients: [String]
}

public struct FoodWalletExportPrivacy: Codable, Equatable, Sendable {
    public var photoRetentionPolicy: String
    public var excludesProtocolCustodyMaterial: Bool
    public var excludesPrivateMaterial: Bool
}

public struct FoodWalletExportManifest: Codable, Equatable, Sendable {
    public var entryCount: Int
    public var templateCount: Int
    public var recipeCount: Int
    public var sha256: String
}

public extension FoodAnalysisCandidate {
    func scaled(toGrams gramsMode: Int64) -> FoodAnalysisCandidate {
        let safeGrams = max(1, gramsMode)
        let previousGrams = max(1, portion.gramsMode)
        let factor = Double(safeGrams) / Double(previousGrams)
        var copy = self
        copy.portion = PortionEstimate(
            gramsMin: max(1, Int64((Double(portion.gramsMin) * factor).rounded())),
            gramsMode: safeGrams,
            gramsMax: max(safeGrams, Int64((Double(portion.gramsMax) * factor).rounded()))
        )
        copy.nutrition = NutritionRange(
            minKcal: max(0, Int64((Double(nutrition.minKcal) * factor).rounded())),
            modeKcal: max(0, Int64((Double(nutrition.modeKcal) * factor).rounded())),
            maxKcal: max(0, Int64((Double(nutrition.maxKcal) * factor).rounded()))
        )
        copy.macronutrients = macronutrients.scaled(by: factor)
        if !copy.assumptions.contains(where: { $0.id == "user-portion" }) {
            copy.assumptions.append(FoodAssumption(
                id: "user-portion",
                label: "portion adjusted by user"
            ))
        }
        return copy
    }
}

public extension MealMacronutrients {
    func scaled(by factor: Double) -> MealMacronutrients {
        MealMacronutrients(
            proteinGrams: proteinGrams * factor,
            carbohydrateGrams: carbohydrateGrams * factor,
            fatGrams: fatGrams * factor,
            fiberGrams: fiberGrams.map { $0 * factor }
        )
    }
}

struct FoodIngredientCatalog {
    struct ResolvedIngredient: Equatable, Sendable {
        var entry: Entry
        var inputName: String
        var grams: Int64

        var kcal: Int64 {
            Int64((entry.kcalPer100Grams * Double(grams) / 100).rounded())
        }

        var macronutrients: MealMacronutrients {
            entry.macronutrientsPer100Grams.scaled(by: Double(grams) / 100)
        }
    }

    struct Entry: Equatable, Sendable {
        var id: String
        var label: String
        var aliases: [String]
        var kcalPer100Grams: Double
        var macronutrientsPer100Grams: MealMacronutrients
        var provider: String = "food_wallet_ingredient_catalog"
    }

    static func candidate(
        title: String,
        ingredients: [FoodMealIngredientInput],
        personalIngredients: [PersonalFoodIngredient] = []
    ) -> Result<FoodAnalysisCandidate, FoodMealDraftCreationResult> {
        let mealTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !mealTitle.isEmpty else {
            return .failure(.emptyTitle)
        }

        var resolved: [ResolvedIngredient] = []
        for ingredient in ingredients {
            let inputName = ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if inputName.isEmpty && ingredient.grams <= 0 {
                continue
            }
            guard ingredient.grams > 0 else {
                return .failure(.invalidGrams(inputName.isEmpty ? "ingredient" : inputName))
            }
            guard let entry = lookup(inputName, personalIngredients: personalIngredients) else {
                return .failure(.unknownIngredient(inputName))
            }
            resolved.append(ResolvedIngredient(entry: entry, inputName: inputName, grams: ingredient.grams))
        }

        guard !resolved.isEmpty else {
            return .failure(.noIngredients)
        }

        let totalGrams = resolved.reduce(Int64(0)) { $0 + $1.grams }
        let totalKcal = resolved.reduce(Int64(0)) { $0 + $1.kcal }
        let variance = max(8, Int64((Double(totalKcal) * 0.10).rounded()))
        let macronutrients = resolved.reduce(
            MealMacronutrients(proteinGrams: 0, carbohydrateGrams: 0, fatGrams: 0, fiberGrams: 0)
        ) { partial, ingredient in
            let macros = ingredient.macronutrients
            return MealMacronutrients(
                proteinGrams: partial.proteinGrams + macros.proteinGrams,
                carbohydrateGrams: partial.carbohydrateGrams + macros.carbohydrateGrams,
                fatGrams: partial.fatGrams + macros.fatGrams,
                fiberGrams: (partial.fiberGrams ?? 0) + (macros.fiberGrams ?? 0)
            )
        }
        var assumptions = [
            FoodAssumption(id: "ingredient-catalog", label: "calculated from ingredient nutrition table"),
            FoodAssumption(id: "review-portion", label: "review portion before saving"),
        ]
        if resolved.contains(where: { $0.entry.provider == "food_wallet_personal_ingredient" }) {
            assumptions.append(FoodAssumption(
                id: "personal-ingredient",
                label: "uses nutrition label entered by user"
            ))
        }
        if resolved.contains(where: { $0.entry.id == "protein-powder.casein" }) {
            assumptions.append(FoodAssumption(
                id: "protein-powder-varies",
                label: "protein powder nutrition varies by brand; verify label"
            ))
        }
        return .success(FoodAnalysisCandidate(
            id: "ingredients-\(slug(mealTitle))",
            primaryLabel: mealTitle,
            genericLabel: mealTitle.lowercased(),
            dishType: resolved.count > 1 ? .mixed : .single,
            portion: PortionEstimate(
                gramsMin: max(1, totalGrams - max(1, totalGrams / 10)),
                gramsMode: totalGrams,
                gramsMax: totalGrams + max(1, totalGrams / 10)
            ),
            nutrition: NutritionRange(
                minKcal: max(0, totalKcal - variance),
                modeKcal: totalKcal,
                maxKcal: totalKcal + variance
            ),
            macronutrients: macronutrients,
            confidence: .medium,
            assumptions: assumptions,
            evidence: resolved.map { ingredient in
                ProviderEvidence(
                    provider: ingredient.entry.provider,
                    providerID: ingredient.entry.id,
                    matchedName: ingredient.entry.label,
                    servingBasis: "\(ingredient.grams)g user-entered ingredient"
                )
            },
            userConfirmationRequired: true
        ))
    }

    static func personalIngredient(
        name: String,
        servingGrams: Double,
        servingKcal: Int64,
        proteinGrams: Double,
        carbohydrateGrams: Double,
        fatGrams: Double,
        fiberGrams: Double?
    ) -> Result<PersonalFoodIngredient, FoodPersonalIngredientSaveResult> {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.emptyName)
        }
        guard servingGrams > 0 else {
            return .failure(.invalidServingGrams)
        }
        guard servingKcal >= 0 else {
            return .failure(.invalidCalories)
        }
        for (label, value) in [
            ("protein", proteinGrams),
            ("carbs", carbohydrateGrams),
            ("fat", fatGrams),
            ("fiber", fiberGrams ?? 0),
        ] where value < 0 {
            return .failure(.invalidMacro(label))
        }

        let factor = 100 / servingGrams
        return .success(PersonalFoodIngredient(
            id: "personal-\(slug(trimmed))",
            name: trimmed,
            sourceServingGrams: servingGrams,
            sourceServingKcal: servingKcal,
            kcalPer100Grams: Double(servingKcal) * factor,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: proteinGrams * factor,
                carbohydrateGrams: carbohydrateGrams * factor,
                fatGrams: fatGrams * factor,
                fiberGrams: fiberGrams.map { $0 * factor }
            )
        ))
    }

    private static func lookup(
        _ input: String,
        personalIngredients: [PersonalFoodIngredient]
    ) -> Entry? {
        let normalized = input.normalizedFoodIngredientName
        if let personal = personalIngredients.first(where: { ingredient in
            let normalizedPersonal = ingredient.name.normalizedFoodIngredientName
            return normalized == normalizedPersonal || normalized.contains(normalizedPersonal)
        }) {
            return Entry(
                id: personal.id,
                label: personal.name,
                aliases: [personal.name],
                kcalPer100Grams: personal.kcalPer100Grams,
                macronutrientsPer100Grams: personal.macronutrientsPer100Grams,
                provider: "food_wallet_personal_ingredient"
            )
        }
        return entries.first { entry in
            entry.aliases.contains { alias in
                normalized == alias || normalized.contains(alias)
            }
        }
    }

    private static func slug(_ value: String) -> String {
        let slug = value
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return slug.isEmpty ? "meal" : slug
    }

    private static let entries: [Entry] = [
        Entry(
            id: "egg.whole",
            label: "Whole egg",
            aliases: ["egg", "eggs", "whole egg"],
            kcalPer100Grams: 143,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 12.6,
                carbohydrateGrams: 0.7,
                fatGrams: 9.5,
                fiberGrams: 0
            )
        ),
        Entry(
            id: "bread.toast",
            label: "Toast",
            aliases: ["toast", "bread", "sourdough"],
            kcalPer100Grams: 265,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 9,
                carbohydrateGrams: 49,
                fatGrams: 3.2,
                fiberGrams: 2.7
            )
        ),
        Entry(
            id: "butter",
            label: "Butter",
            aliases: ["butter"],
            kcalPer100Grams: 717,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 0.9,
                carbohydrateGrams: 0.1,
                fatGrams: 81.1,
                fiberGrams: 0
            )
        ),
        Entry(
            id: "greek-yogurt.plain",
            label: "Plain Greek yogurt",
            aliases: ["greek yogurt", "yogurt"],
            kcalPer100Grams: 97,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 9,
                carbohydrateGrams: 3.6,
                fatGrams: 5,
                fiberGrams: 0
            )
        ),
        Entry(
            id: "protein-powder.casein",
            label: "Casein protein powder",
            aliases: [
                "casein",
                "casein protein",
                "casein protein powder",
                "casein powder",
                "micellar casein",
                "protein powder",
            ],
            kcalPer100Grams: 360,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 80,
                carbohydrateGrams: 10,
                fatGrams: 3,
                fiberGrams: 0
            )
        ),
        Entry(
            id: "oats.rolled",
            label: "Rolled oats",
            aliases: ["oats", "oatmeal"],
            kcalPer100Grams: 389,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 16.9,
                carbohydrateGrams: 66.3,
                fatGrams: 6.9,
                fiberGrams: 10.6
            )
        ),
        Entry(
            id: "berries.mixed",
            label: "Mixed berries",
            aliases: ["berries", "blueberries", "strawberries"],
            kcalPer100Grams: 57,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 0.7,
                carbohydrateGrams: 14.5,
                fatGrams: 0.3,
                fiberGrams: 2.4
            )
        ),
        Entry(
            id: "banana",
            label: "Banana",
            aliases: ["banana"],
            kcalPer100Grams: 89,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 1.1,
                carbohydrateGrams: 22.8,
                fatGrams: 0.3,
                fiberGrams: 2.6
            )
        ),
        Entry(
            id: "apple",
            label: "Apple",
            aliases: ["apple", "fuji apple"],
            kcalPer100Grams: 52,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 0.3,
                carbohydrateGrams: 13.8,
                fatGrams: 0.2,
                fiberGrams: 2.4
            )
        ),
        Entry(
            id: "avocado",
            label: "Avocado",
            aliases: ["avocado"],
            kcalPer100Grams: 160,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 2,
                carbohydrateGrams: 8.5,
                fatGrams: 14.7,
                fiberGrams: 6.7
            )
        ),
        Entry(
            id: "rice.cooked",
            label: "Cooked rice",
            aliases: ["rice", "cooked rice"],
            kcalPer100Grams: 130,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 2.7,
                carbohydrateGrams: 28,
                fatGrams: 0.3,
                fiberGrams: 0.4
            )
        ),
        Entry(
            id: "chicken-breast.cooked",
            label: "Cooked chicken breast",
            aliases: ["chicken", "chicken breast"],
            kcalPer100Grams: 165,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 31,
                carbohydrateGrams: 0,
                fatGrams: 3.6,
                fiberGrams: 0
            )
        ),
        Entry(
            id: "tomato",
            label: "Tomato",
            aliases: ["tomato", "tomatoes"],
            kcalPer100Grams: 18,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 0.9,
                carbohydrateGrams: 3.9,
                fatGrams: 0.2,
                fiberGrams: 1.2
            )
        ),
        Entry(
            id: "cucumber",
            label: "Cucumber",
            aliases: ["cucumber"],
            kcalPer100Grams: 15,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 0.7,
                carbohydrateGrams: 3.6,
                fatGrams: 0.1,
                fiberGrams: 0.5
            )
        ),
        Entry(
            id: "olive-oil",
            label: "Olive oil",
            aliases: ["olive oil", "oil"],
            kcalPer100Grams: 884,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 0,
                carbohydrateGrams: 0,
                fatGrams: 100,
                fiberGrams: 0
            )
        ),
        Entry(
            id: "herbs",
            label: "Herbs",
            aliases: ["herbs", "seasoning"],
            kcalPer100Grams: 21,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 1,
                carbohydrateGrams: 4,
                fatGrams: 0.5,
                fiberGrams: 2
            )
        ),
        Entry(
            id: "coffee",
            label: "Black coffee",
            aliases: ["coffee"],
            kcalPer100Grams: 1,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 0.1,
                carbohydrateGrams: 0,
                fatGrams: 0,
                fiberGrams: 0
            )
        ),
        Entry(
            id: "milk.whole",
            label: "Whole milk",
            aliases: ["milk"],
            kcalPer100Grams: 61,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 3.2,
                carbohydrateGrams: 4.8,
                fatGrams: 3.3,
                fiberGrams: 0
            )
        ),
    ]
}

private extension String {
    var normalizedFoodIngredientName: String {
        lowercased()
            .replacingOccurrences(of: "[^a-z0-9 ]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum QuickTextFoodParser {
    static func candidate(for text: String) -> FoodAnalysisCandidate {
        let normalized = text.lowercased()
        let meal: MealEstimate
        let confidence: EstimateConfidence
        let assumptions: [FoodAssumption]

        if normalized.contains("egg") && normalized.contains("toast") {
            meal = MealEstimate(
                label: text,
                kcal: 330,
                varianceKcal: 35,
                amountGrams: 220,
                servingGrams: 220,
                servings: 1,
                macronutrients: MealMacronutrients(
                    proteinGrams: 20,
                    carbohydrateGrams: 28,
                    fatGrams: 15,
                    fiberGrams: 4
                )
            )
            confidence = .medium
            assumptions = [
                FoodAssumption(id: "quick-text", label: "parsed from typed food"),
                FoodAssumption(id: "egg-toast-default", label: "two eggs and one toast serving"),
                FoodAssumption(id: "review-portion", label: "review portion before saving"),
            ]
        } else if normalized.contains("apple") {
            meal = MealEstimate(
                label: text,
                kcal: 102,
                varianceKcal: 12,
                amountGrams: 170,
                servingGrams: 170,
                servings: 1,
                macronutrients: MealMacronutrients(
                    proteinGrams: 0.5,
                    carbohydrateGrams: 27,
                    fatGrams: 0.3,
                    fiberGrams: 4.8
                )
            )
            confidence = .medium
            assumptions = [
                FoodAssumption(id: "quick-text", label: "parsed from typed food"),
                FoodAssumption(id: "apple-medium", label: "medium apple serving"),
            ]
        } else if normalized.contains("salad") {
            meal = MealEstimate(
                label: text,
                kcal: 260,
                varianceKcal: 90,
                amountGrams: 280,
                servingGrams: 280,
                servings: 1,
                macronutrients: MealMacronutrients(
                    proteinGrams: 7,
                    carbohydrateGrams: 24,
                    fatGrams: 16,
                    fiberGrams: 8
                )
            )
            confidence = .low
            assumptions = [
                FoodAssumption(id: "quick-text", label: "parsed from typed food"),
                FoodAssumption(id: "salad-dressing", label: "dressing or oil may change calories"),
                FoodAssumption(id: "review-portion", label: "review portion before saving"),
            ]
        } else {
            meal = MealEstimate(
                label: text,
                kcal: 300,
                varianceKcal: 120,
                amountGrams: 250,
                servingGrams: 250,
                servings: 1,
                macronutrients: MealMacronutrients(
                    proteinGrams: 12,
                    carbohydrateGrams: 35,
                    fatGrams: 10,
                    fiberGrams: 5
                )
            )
            confidence = .low
            assumptions = [
                FoodAssumption(id: "quick-text", label: "parsed from typed food"),
                FoodAssumption(id: "generic-fallback", label: "generic estimate needs review"),
            ]
        }

        let slug = normalized
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return FoodAnalysisCandidate(
            id: "quick-text-\(slug.isEmpty ? "food" : slug)",
            primaryLabel: meal.label,
            genericLabel: normalized,
            dishType: normalized.contains("salad") || normalized.contains("toast") ? .mixed : .single,
            portion: PortionEstimate(
                gramsMin: max(1, meal.amountGrams - max(1, meal.amountGrams / 5)),
                gramsMode: meal.amountGrams,
                gramsMax: meal.amountGrams + max(1, meal.amountGrams / 5)
            ),
            nutrition: NutritionRange(
                minKcal: max(0, meal.kcal - meal.varianceKcal),
                modeKcal: meal.kcal,
                maxKcal: meal.kcal + meal.varianceKcal
            ),
            macronutrients: meal.macronutrients ?? MealMacronutrients(
                proteinGrams: 0,
                carbohydrateGrams: 0,
                fatGrams: 0,
                fiberGrams: 0
            ),
            confidence: confidence,
            assumptions: assumptions,
            evidence: [
                ProviderEvidence(
                    provider: "food_wallet_quick_text",
                    providerID: "local-parser-v1",
                    matchedName: meal.label,
                    servingBasis: "typed_user_input"
                ),
            ],
            userConfirmationRequired: true
        )
    }
}

enum FoodWalletExportFactory {
    static func portableBundle(
        entries: [FoodIntakeEntry],
        templates: [SavedFoodTemplate],
        recipes: [SavedFoodRecipe],
        generatedAt: Date
    ) throws -> FoodWalletExportBundle {
        let exportEntries = entries.map(FoodWalletExportEntry.init(entry:))
        let preliminary = FoodWalletExportBundle(
            schema: "grain.food-wallet.export.v1",
            version: 1,
            generatedAt: ISO8601DateFormatter().string(from: generatedAt),
            totals: FoodWalletExportTotals(
                entryCount: entries.count,
                sumMeanKcal: entries.reduce(0) { $0 + $1.meal.kcal },
                sumVarianceKcal: entries.reduce(0) { $0 + $1.meal.varianceKcal }
            ),
            entries: exportEntries,
            templates: templates.map(FoodWalletExportTemplate.init(template:)),
            recipes: recipes.map(FoodWalletExportRecipe.init(recipe:)),
            privacy: FoodWalletExportPrivacy(
                photoRetentionPolicy: "no_photo_storage",
                excludesProtocolCustodyMaterial: true,
                excludesPrivateMaterial: true
            ),
            manifest: FoodWalletExportManifest(
                entryCount: entries.count,
                templateCount: templates.count,
                recipeCount: recipes.count,
                sha256: ""
            )
        )
        let digest = try sha256Hex(preliminary)
        var bundle = preliminary
        bundle.manifest.sha256 = digest
        return bundle
    }

    static func jsonData(_ bundle: FoodWalletExportBundle) throws -> Data {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(bundle)
    }

    static func csv(entries: [FoodIntakeEntry]) -> String {
        let header = "date,label,kcal_min,kcal_mode,kcal_max,grams,source_class,trust_status"
        let rows = entries.map { entry in
            [
                entry.dateKey,
                csvEscape(entry.meal.label),
                String(max(0, entry.meal.kcal - entry.meal.varianceKcal)),
                String(entry.meal.kcal),
                String(entry.meal.kcal + entry.meal.varianceKcal),
                String(entry.meal.amountGrams),
                entry.sourceClass.rawValue,
                entry.trustStatus.rawValue,
            ].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n") + "\n"
    }

    private static func sha256Hex(_ bundle: FoodWalletExportBundle) throws -> String {
        let data = try jsonData(bundle)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}

private extension FoodWalletExportEntry {
    init(entry: FoodIntakeEntry) {
        entryID = entry.entryID
        draftID = entry.draftID
        dateKey = entry.dateKey
        label = entry.meal.label
        kcal = entry.meal.kcal
        varianceKcal = entry.meal.varianceKcal
        amountGrams = entry.meal.amountGrams
        proteinGrams = entry.meal.macronutrients?.proteinGrams
        carbohydrateGrams = entry.meal.macronutrients?.carbohydrateGrams
        fatGrams = entry.meal.macronutrients?.fatGrams
        fiberGrams = entry.meal.macronutrients?.fiberGrams
        sourceClass = entry.sourceClass.rawValue
        trustStatus = entry.trustStatus.rawValue
    }
}

private extension FoodWalletExportTemplate {
    init(template: SavedFoodTemplate) {
        id = template.id
        title = template.title
        kcal = template.kcal
        amountGrams = template.amountGrams
    }
}

private extension FoodWalletExportRecipe {
    init(recipe: SavedFoodRecipe) {
        id = recipe.id
        title = recipe.title
        totalKcal = recipe.totalKcal
        totalGrams = recipe.totalGrams
        ingredients = recipe.ingredients.map(\.label)
    }
}
