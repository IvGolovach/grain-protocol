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

    public static let defaultTemplates: [SavedFoodTemplate] = [
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
        SavedFoodTemplate(
            id: "protein-coffee",
            title: "Protein coffee",
            subtitle: "Coffee with protein shake",
            kcal: 190,
            varianceKcal: 20,
            amountGrams: 420,
            servingGrams: 420,
            macronutrients: MealMacronutrients(
                proteinGrams: 26,
                carbohydrateGrams: 10,
                fatGrams: 5,
                fiberGrams: 1
            )
        ),
    ]
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

    public static let defaultRecipes: [SavedFoodRecipe] = [
        SavedFoodRecipe(
            id: "tomato-cucumber-salad",
            title: "Tomato cucumber salad",
            subtitle: "Tomatoes, cucumber, olive oil, herbs",
            totalGrams: 420,
            totalKcal: 280,
            macronutrients: MealMacronutrients(
                proteinGrams: 5,
                carbohydrateGrams: 22,
                fatGrams: 20,
                fiberGrams: 7
            ),
            ingredients: [
                SavedFoodRecipeIngredient(id: "tomato", label: "Tomatoes", grams: 180, kcal: 32),
                SavedFoodRecipeIngredient(id: "cucumber", label: "Cucumber", grams: 160, kcal: 24),
                SavedFoodRecipeIngredient(id: "olive-oil", label: "Olive oil", grams: 24, kcal: 212),
                SavedFoodRecipeIngredient(id: "herbs", label: "Herbs and seasoning", grams: 56, kcal: 12),
            ]
        ),
    ]
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
