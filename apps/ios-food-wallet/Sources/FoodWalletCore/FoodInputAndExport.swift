import CryptoKit
import Foundation
import GrainFoodWallet

public struct SavedFoodTemplate: Identifiable, Codable, Equatable, Sendable {
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

public struct SavedFoodRecipeIngredient: Identifiable, Codable, Equatable, Sendable {
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

public struct FoodWalletDailyNutritionSummary: Equatable, Sendable {
    public var entryCount: Int
    public var kcal: Int64
    public var varianceKcal: Int64
    public var proteinGrams: Double
    public var carbohydrateGrams: Double
    public var fatGrams: Double
    public var fiberGrams: Double?

    public init(entries: [FoodIntakeEntry]) {
        entryCount = entries.count
        kcal = entries.reduce(0) { $0 + $1.meal.kcal }
        varianceKcal = entries.reduce(0) { $0 + $1.meal.varianceKcal }
        proteinGrams = entries.reduce(0) { $0 + ($1.meal.macronutrients?.proteinGrams ?? 0) }
        carbohydrateGrams = entries.reduce(0) { $0 + ($1.meal.macronutrients?.carbohydrateGrams ?? 0) }
        fatGrams = entries.reduce(0) { $0 + ($1.meal.macronutrients?.fatGrams ?? 0) }
        let fiberValues = entries.compactMap { $0.meal.macronutrients?.fiberGrams }
        fiberGrams = fiberValues.isEmpty ? nil : fiberValues.reduce(0, +)
    }

    public var kcalRangeLabel: String {
        guard entryCount > 0 else {
            return "0 kcal"
        }
        guard varianceKcal > 0 else {
            return "\(kcal) kcal"
        }
        return "\(max(0, kcal - varianceKcal))-\(kcal + varianceKcal) kcal"
    }

    public var macroLabel: String {
        "P \(Self.format(proteinGrams))g • C \(Self.format(carbohydrateGrams))g • F \(Self.format(fatGrams))g"
    }

    public static func display(_ value: Double) -> String {
        format(value)
    }

    private static func format(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return "\(Int(rounded))"
        }
        return "\(rounded)"
    }
}

public enum FoodWalletQRPayloadKind: String, Codable, Equatable, Sendable {
    case recipe
    case personalFood = "personal_food"
}

public struct FoodWalletQRIssuer: Codable, Equatable, Sendable {
    public var label: String
    public var keyID: String

    public init(label: String, keyID: String) {
        self.label = label
        self.keyID = keyID
    }

    enum CodingKeys: String, CodingKey {
        case label
        case keyID = "keyId"
    }
}

public struct FoodWalletQRPayload: Codable, Equatable, Sendable {
    public var schema: String
    public var version: Int
    public var kind: FoodWalletQRPayloadKind
    public var title: String
    public var contentSha256: String
    public var issuer: FoodWalletQRIssuer?
    public var signature: FoodWalletExportSignature?
    public var recipe: FoodWalletExportRecipe?
    public var personalFood: FoodWalletExportPersonalFood?

    enum CodingKeys: String, CodingKey {
        case schema
        case version
        case kind
        case title
        case contentSha256
        case issuer
        case signature
        case recipe
        case personalFood
    }
}

public struct FoodWalletQRImportPreview: Equatable, Sendable {
    public var title: String
    public var subtitle: String
    public var nutritionLabel: String
    public var macronutrientsLabel: String
    public var signedByLabel: String
    public var sourceLabel: String
    public var ingredients: [String]

    public init(
        title: String,
        subtitle: String,
        nutritionLabel: String,
        macronutrientsLabel: String,
        signedByLabel: String,
        sourceLabel: String,
        ingredients: [String]
    ) {
        self.title = title
        self.subtitle = subtitle
        self.nutritionLabel = nutritionLabel
        self.macronutrientsLabel = macronutrientsLabel
        self.signedByLabel = signedByLabel
        self.sourceLabel = sourceLabel
        self.ingredients = ingredients
    }
}

public enum FoodWalletQRImportError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidPayload
    case integrityMismatch
    case unsupportedPayload
    case protocolServingOfferRequiresTrust

    public var description: String {
        switch self {
        case .invalidPayload:
            return "invalidPayload"
        case .integrityMismatch:
            return "integrityMismatch"
        case .unsupportedPayload:
            return "unsupportedPayload"
        case .protocolServingOfferRequiresTrust:
            return "protocolServingOfferRequiresTrust"
        }
    }
}

public struct SavedFoodRecipe: Identifiable, Codable, Equatable, Sendable {
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
    public var summary: FoodWalletExportSummary
    public var entries: [FoodWalletExportEntry]
    public var templates: [FoodWalletExportTemplate]
    public var recipes: [FoodWalletExportRecipe]
    public var personalFoods: [FoodWalletExportPersonalFood]?
    public var privacy: FoodWalletExportPrivacy
    public var manifest: FoodWalletExportManifest
}

public struct FoodWalletExportTotals: Codable, Equatable, Sendable {
    public var entryCount: Int
    public var sumMeanKcal: Int64
    public var sumVarianceKcal: Int64
}

public struct FoodWalletExportSummary: Codable, Equatable, Sendable {
    public var sourceClassCounts: [String: Int]
    public var trustStatusCounts: [String: Int]
}

public struct FoodWalletExportEntry: Codable, Equatable, Sendable {
    public var entryID: String
    public var draftID: String
    public var confirmedAt: String
    public var dateKey: String
    public var label: String
    public var kcal: Int64
    public var varianceKcal: Int64
    public var amountGrams: Int64
    public var servingGrams: Int64?
    public var servings: Int64
    public var proteinGrams: Double?
    public var carbohydrateGrams: Double?
    public var fatGrams: Double?
    public var fiberGrams: Double?
    public var sourceClass: String
    public var trustStatus: String

    enum CodingKeys: String, CodingKey {
        case entryID = "entryId"
        case draftID = "draftId"
        case confirmedAt
        case dateKey
        case label
        case kcal
        case varianceKcal
        case amountGrams
        case servingGrams
        case servings
        case proteinGrams
        case carbohydrateGrams
        case fatGrams
        case fiberGrams
        case sourceClass
        case trustStatus
    }
}

public struct FoodWalletExportTemplate: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var subtitle: String?
    public var kcal: Int64
    public var varianceKcal: Int64?
    public var amountGrams: Int64
    public var servingGrams: Int64?
    public var servings: Int64?
    public var proteinGrams: Double?
    public var carbohydrateGrams: Double?
    public var fatGrams: Double?
    public var fiberGrams: Double?
    public var evidenceProvider: String?
    public var servingBasis: String?
}

public struct FoodWalletExportRecipe: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var subtitle: String?
    public var totalKcal: Int64
    public var totalGrams: Int64
    public var ingredients: [String]
    public var ingredientDetails: [FoodWalletExportRecipeIngredient]?
    public var proteinGrams: Double?
    public var carbohydrateGrams: Double?
    public var fatGrams: Double?
    public var fiberGrams: Double?
    public var evidenceProvider: String?
    public var servingBasis: String?
}

public struct FoodWalletExportRecipeIngredient: Codable, Equatable, Sendable {
    public var id: String
    public var label: String
    public var grams: Int64
    public var kcal: Int64
}

public struct FoodWalletExportPersonalFood: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var sourceServingGrams: Double
    public var sourceServingKcal: Int64
    public var kcalPer100Grams: Double
    public var proteinGramsPer100: Double
    public var carbohydrateGramsPer100: Double
    public var fatGramsPer100: Double
    public var fiberGramsPer100: Double?
    public var evidenceProvider: String
    public var servingBasis: String
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
    public var personalFoodCount: Int?
    public var contentSha256: String
    public var contentDigestID: String
    public var sourceClassSummary: [String: Int]
    public var trustStatusSummary: [String: Int]
    public var signature: FoodWalletExportSignature?

    enum CodingKeys: String, CodingKey {
        case entryCount
        case templateCount
        case recipeCount
        case personalFoodCount
        case contentSha256
        case contentDigestID = "contentDigestId"
        case sourceClassSummary
        case trustStatusSummary
        case signature
    }
}

public struct FoodWalletExportSignature: Codable, Equatable, Sendable {
    public var algorithm: String
    public var signer: String
    public var publicKeyX963Base64: String
    public var signatureDerBase64: String

    enum CodingKeys: String, CodingKey {
        case algorithm
        case signer
        case publicKeyX963Base64
        case signatureDerBase64
    }
}

public struct FoodWalletImportPreview: Equatable, Sendable {
    public var integrityVerified: Bool
    public var entryCount: Int
    public var newEntryCount: Int
    public var duplicateEntryCount: Int
    public var dateRange: String?
    public var sourceClassSummary: [String: Int]
    public var trustStatusSummary: [String: Int]
}

public struct FoodWalletImportResult: Equatable, Sendable {
    public var importedEntryCount: Int
    public var duplicateEntryCount: Int
}

public enum FoodWalletImportError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidJSON
    case unsupportedSchema(String)
    case unsupportedVersion(Int)
    case integrityMismatch
    case signatureMismatch
    case unsafeMaterial(String)
    case invalidManifest(String)
    case invalidEntry(String)

    public var description: String {
        switch self {
        case .invalidJSON:
            return "invalidJSON"
        case let .unsupportedSchema(schema):
            return "unsupportedSchema(\(schema))"
        case let .unsupportedVersion(version):
            return "unsupportedVersion(\(version))"
        case .integrityMismatch:
            return "integrityMismatch"
        case .signatureMismatch:
            return "signatureMismatch"
        case let .unsafeMaterial(token):
            return "unsafeMaterial(\(token))"
        case let .invalidManifest(reason):
            return "invalidManifest(\(reason))"
        case let .invalidEntry(reason):
            return "invalidEntry(\(reason))"
        }
    }
}

public struct FoodWalletLocalLedgerState: Codable, Equatable, Sendable {
    public var schema: String
    public var version: Int
    public var entries: [FoodWalletExportEntry]
}

public struct FoodWalletUserLibraryState: Codable, Equatable, Sendable {
    public var schema: String
    public var version: Int
    public var templates: [SavedFoodTemplate]
    public var recipes: [SavedFoodRecipe]
    public var personalIngredients: [PersonalFoodIngredient]

    public init(
        schema: String = "grain.food-wallet.user-library.v1",
        version: Int = 1,
        templates: [SavedFoodTemplate] = [],
        recipes: [SavedFoodRecipe] = [],
        personalIngredients: [PersonalFoodIngredient] = []
    ) {
        self.schema = schema
        self.version = version
        self.templates = templates
        self.recipes = recipes
        self.personalIngredients = personalIngredients
    }

    public var isEmpty: Bool {
        templates.isEmpty && recipes.isEmpty && personalIngredients.isEmpty
    }

    enum CodingKeys: String, CodingKey {
        case schema
        case version
        case templates
        case recipes
        case personalIngredients
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schema = try container.decodeIfPresent(String.self, forKey: .schema) ?? "grain.food-wallet.user-library.v1"
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        templates = try container.decodeIfPresent([SavedFoodTemplate].self, forKey: .templates) ?? []
        recipes = try container.decodeIfPresent([SavedFoodRecipe].self, forKey: .recipes) ?? []
        personalIngredients = try container.decodeIfPresent(
            [PersonalFoodIngredient].self,
            forKey: .personalIngredients
        ) ?? []
    }
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

    struct ResolvedMeal: Equatable, Sendable {
        var title: String
        var ingredients: [ResolvedIngredient]
        var totalGrams: Int64
        var totalKcal: Int64
        var varianceKcal: Int64
        var macronutrients: MealMacronutrients
    }

    struct Entry: Equatable, Sendable {
        var id: String
        var label: String
        var aliases: [String]
        var kcalPer100Grams: Double
        var macronutrientsPer100Grams: MealMacronutrients
        var defaultServingGrams: Int64 = 100
        var servingLabel: String? = nil
        var provider: String = "food_wallet_ingredient_catalog"

        var searchableText: String {
            ([label] + aliases).joined(separator: " ")
        }
    }

    static func candidate(
        title: String,
        ingredients: [FoodMealIngredientInput],
        personalIngredients: [PersonalFoodIngredient] = []
    ) -> Result<FoodAnalysisCandidate, FoodMealDraftCreationResult> {
        switch resolveMeal(title: title, ingredients: ingredients, personalIngredients: personalIngredients) {
        case let .failure(error):
            return .failure(error)
        case let .success(meal):
        var assumptions = [
            FoodAssumption(id: "ingredient-catalog", label: "calculated from ingredient nutrition table"),
            FoodAssumption(id: "review-portion", label: "review portion before saving"),
        ]
        if meal.ingredients.contains(where: { $0.entry.provider == "food_wallet_personal_ingredient" }) {
            assumptions.append(FoodAssumption(
                id: "personal-ingredient",
                label: "uses nutrition label entered by user"
            ))
        }
        if meal.ingredients.contains(where: { $0.entry.id == "protein-powder.casein" }) {
            assumptions.append(FoodAssumption(
                id: "protein-powder-varies",
                label: "protein powder nutrition varies by brand; verify label"
            ))
        }
        return .success(FoodAnalysisCandidate(
            id: "ingredients-\(slug(meal.title))",
            primaryLabel: meal.title,
            genericLabel: meal.title.lowercased(),
            dishType: meal.ingredients.count > 1 ? .mixed : .single,
            portion: PortionEstimate(
                gramsMin: max(1, meal.totalGrams - max(1, meal.totalGrams / 10)),
                gramsMode: meal.totalGrams,
                gramsMax: meal.totalGrams + max(1, meal.totalGrams / 10)
            ),
            nutrition: NutritionRange(
                minKcal: max(0, meal.totalKcal - meal.varianceKcal),
                modeKcal: meal.totalKcal,
                maxKcal: meal.totalKcal + meal.varianceKcal
            ),
            macronutrients: meal.macronutrients,
            confidence: .medium,
            assumptions: assumptions,
            evidence: meal.ingredients.map { ingredient in
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
    }

    static func savedRecipe(
        title: String,
        ingredients: [FoodMealIngredientInput],
        personalIngredients: [PersonalFoodIngredient] = []
    ) -> Result<SavedFoodRecipe, FoodMealDraftCreationResult> {
        switch resolveMeal(title: title, ingredients: ingredients, personalIngredients: personalIngredients) {
        case let .failure(error):
            return .failure(error)
        case let .success(meal):
            let subtitle = meal.ingredients
                .prefix(3)
                .map { $0.entry.label }
                .joined(separator: ", ")
            return .success(SavedFoodRecipe(
                id: "recipe-\(slug(meal.title))",
                title: meal.title,
                subtitle: subtitle.isEmpty ? "Custom meal" : subtitle,
                totalGrams: meal.totalGrams,
                totalKcal: meal.totalKcal,
                macronutrients: meal.macronutrients,
                ingredients: meal.ingredients.map { ingredient in
                    SavedFoodRecipeIngredient(
                        id: ingredient.entry.id,
                        label: ingredient.entry.label,
                        grams: ingredient.grams,
                        kcal: ingredient.kcal
                    )
                }
            ))
        }
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

    static func suggestionRows(
        for text: String,
        personalIngredients: [PersonalFoodIngredient] = [],
        limit: Int = 8
    ) -> [AddFoodSuggestionRow] {
        let query = AddFoodSearchQuery(text)
        guard !query.isEmpty else {
            return []
        }

        let catalogRows = entries
            .compactMap { entry -> (score: Int, row: AddFoodSuggestionRow)? in
                guard let score = matchScore(query: query, entry: entry) else {
                    return nil
                }
                return (score, suggestionRow(entry: entry))
            }
        let personalRows = personalIngredients
            .compactMap { ingredient -> (score: Int, row: AddFoodSuggestionRow)? in
                let entry = entry(from: ingredient)
                guard let score = matchScore(query: query, entry: entry) else {
                    return nil
                }
                return (score, suggestionRow(entry: entry))
            }

        return (catalogRows + personalRows)
            .sorted { left, right in
                if left.score != right.score {
                    return left.score > right.score
                }
                return left.row.title.localizedCaseInsensitiveCompare(right.row.title) == .orderedAscending
            }
            .prefix(limit)
            .map(\.row)
    }

    static func candidate(
        suggestionID: String,
        personalIngredients: [PersonalFoodIngredient] = []
    ) -> FoodAnalysisCandidate? {
        let entryID = suggestionID.replacingOccurrences(of: "ingredient:", with: "")
        if let entry = entries.first(where: { $0.id == entryID }) {
            return singleFoodCandidate(entry: entry)
        }
        if let personal = personalIngredients.first(where: { "personal:\($0.id)" == suggestionID || $0.id == entryID }) {
            return singleFoodCandidate(entry: entry(from: personal))
        }
        return nil
    }

    private static func resolveMeal(
        title: String,
        ingredients: [FoodMealIngredientInput],
        personalIngredients: [PersonalFoodIngredient]
    ) -> Result<ResolvedMeal, FoodMealDraftCreationResult> {
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
        return .success(ResolvedMeal(
            title: mealTitle,
            ingredients: resolved,
            totalGrams: totalGrams,
            totalKcal: totalKcal,
            varianceKcal: variance,
            macronutrients: macronutrients
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
        if let exact = entries.first(where: { entry in
            entry.label.normalizedFoodIngredientName == normalized ||
            entry.aliases.contains { alias in
                alias.normalizedFoodIngredientName == normalized
            }
        }) {
            return exact
        }
        return entries.first { entry in
            entry.aliases.contains { alias in
                let normalizedAlias = alias.normalizedFoodIngredientName
                return !normalizedAlias.isEmpty && normalized.contains(normalizedAlias)
            }
        }
    }

    private static func suggestionRow(entry: Entry) -> AddFoodSuggestionRow {
        let meal = mealEstimate(entry: entry)
        return AddFoodSuggestionRow(
            id: "ingredient:\(entry.id)",
            kind: entry.provider == "food_wallet_personal_ingredient" ? .personalIngredient : .providerMatch,
            title: entry.label,
            subtitle: "\(entry.servingLabel ?? "\(entry.defaultServingGrams) g") | \(meal.kcal) kcal",
            sourceLabel: FoodEvidenceSource.defaultLabel(for: entry.provider),
            evidence: [
                ProviderEvidence(
                    provider: entry.provider,
                    providerID: entry.id,
                    matchedName: entry.label,
                    servingBasis: entry.servingLabel ?? "\(entry.defaultServingGrams)g default serving"
                ),
            ],
            confidence: .medium,
            nutrition: NutritionRange(
                minKcal: max(0, meal.kcal - meal.varianceKcal),
                modeKcal: meal.kcal,
                maxKcal: meal.kcal + meal.varianceKcal
            ),
            portion: PortionEstimate(
                gramsMin: max(1, entry.defaultServingGrams - max(1, entry.defaultServingGrams / 10)),
                gramsMode: entry.defaultServingGrams,
                gramsMax: entry.defaultServingGrams + max(1, entry.defaultServingGrams / 10)
            ),
            searchText: entry.searchableText
        )
    }

    private static func singleFoodCandidate(entry: Entry) -> FoodAnalysisCandidate {
        let meal = mealEstimate(entry: entry)
        let variance = meal.varianceKcal
        return FoodAnalysisCandidate(
            id: "ingredient-\(slug(entry.id))",
            primaryLabel: entry.label,
            genericLabel: entry.label.lowercased(),
            dishType: .single,
            portion: PortionEstimate(
                gramsMin: max(1, entry.defaultServingGrams - max(1, entry.defaultServingGrams / 10)),
                gramsMode: entry.defaultServingGrams,
                gramsMax: entry.defaultServingGrams + max(1, entry.defaultServingGrams / 10)
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
            confidence: .medium,
            assumptions: [
                FoodAssumption(id: "catalog-match", label: "matched local nutrition catalog"),
                FoodAssumption(id: "review-portion", label: "review portion before saving"),
            ],
            evidence: [
                ProviderEvidence(
                    provider: entry.provider,
                    providerID: entry.id,
                    matchedName: entry.label,
                    servingBasis: entry.servingLabel ?? "\(entry.defaultServingGrams)g default serving"
                ),
            ],
            userConfirmationRequired: true
        )
    }

    private static func mealEstimate(entry: Entry) -> MealEstimate {
        let factor = Double(entry.defaultServingGrams) / 100
        let kcal = Int64((entry.kcalPer100Grams * factor).rounded())
        return MealEstimate(
            label: entry.label,
            kcal: kcal,
            varianceKcal: max(1, Int64((Double(kcal) * 0.10).rounded())),
            amountGrams: entry.defaultServingGrams,
            servingGrams: entry.defaultServingGrams,
            servings: 1,
            macronutrients: entry.macronutrientsPer100Grams.scaled(by: factor)
        )
    }

    private static func entry(from ingredient: PersonalFoodIngredient) -> Entry {
        Entry(
            id: "personal:\(ingredient.id)",
            label: ingredient.name,
            aliases: [ingredient.name],
            kcalPer100Grams: ingredient.kcalPer100Grams,
            macronutrientsPer100Grams: ingredient.macronutrientsPer100Grams,
            defaultServingGrams: max(1, Int64(ingredient.sourceServingGrams.rounded())),
            servingLabel: "\(Int64(ingredient.sourceServingGrams.rounded())) g saved serving",
            provider: "food_wallet_personal_ingredient"
        )
    }

    private static func matchScore(query: AddFoodSearchQuery, entry: Entry) -> Int? {
        let searchable = AddFoodSearchQuery.normalize(entry.searchableText)
        guard query.tokens.allSatisfy({ searchable.contains($0) }) else {
            return nil
        }
        if "milk".hasPrefix(query.normalizedValue),
           let milkPriority = milkSuggestionPriority(entry.id) {
            return 120 + milkPriority
        }
        if let commonPriority = commonSuggestionPriority(query.normalizedValue, entry.id) {
            return 115 + commonPriority
        }
        if entry.aliases.contains(where: { AddFoodSearchQuery.normalize($0) == query.normalizedValue }) {
            return 100
        }
        if AddFoodSearchQuery.normalize(entry.label) == query.normalizedValue {
            return 95
        }
        return 70 + query.tokens.count
    }

    private static func milkSuggestionPriority(_ id: String) -> Int? {
        switch id {
        case "milk.whole":
            return 6
        case "milk.2-percent":
            return 5
        case "milk.skim":
            return 4
        case "milk.1-percent":
            return 3
        case "milk.oat":
            return 2
        case "milk.soy.unsweetened":
            return 1
        case "milk.almond.unsweetened":
            return 0
        default:
            return nil
        }
    }

    private static func commonSuggestionPriority(_ query: String, _ id: String) -> Int? {
        switch query {
        case "egg", "eggs":
            switch id {
            case "egg.whole": return 8
            case "egg.boiled": return 7
            case "egg.white": return 6
            case "egg.scrambled": return 5
            case "egg.yolk": return 4
            default: return nil
            }
        case "beef":
            switch id {
            case "beef.ground.cooked": return 8
            case "beef.steak.cooked": return 7
            case "beef.roast.cooked": return 6
            default: return nil
            }
        case "pork":
            switch id {
            case "pork.tenderloin.cooked": return 8
            case "pork.chop.cooked": return 7
            case "pork.ground.cooked": return 6
            case "pork.bacon.cooked": return 5
            default: return nil
            }
        default:
            return nil
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
            aliases: ["egg", "eggs", "whole egg", "raw egg", "chicken egg"],
            kcalPer100Grams: 143,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 12.6,
                carbohydrateGrams: 0.7,
                fatGrams: 9.5,
                fiberGrams: 0
            )
        ),
        Entry(
            id: "egg.boiled",
            label: "Boiled egg",
            aliases: ["egg", "eggs", "boiled egg", "hard boiled egg", "hard-boiled egg"],
            kcalPer100Grams: 155,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 12.6,
                carbohydrateGrams: 1.1,
                fatGrams: 10.6,
                fiberGrams: 0
            ),
            defaultServingGrams: 50,
            servingLabel: "1 large egg (50 g)"
        ),
        Entry(
            id: "egg.white",
            label: "Egg whites",
            aliases: ["egg", "eggs", "egg white", "egg whites", "liquid egg whites"],
            kcalPer100Grams: 52,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 10.9,
                carbohydrateGrams: 0.7,
                fatGrams: 0.2,
                fiberGrams: 0
            )
        ),
        Entry(
            id: "egg.yolk",
            label: "Egg yolk",
            aliases: ["egg", "eggs", "egg yolk", "egg yolks"],
            kcalPer100Grams: 322,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 15.9,
                carbohydrateGrams: 3.6,
                fatGrams: 26.5,
                fiberGrams: 0
            ),
            defaultServingGrams: 17,
            servingLabel: "1 large yolk (17 g)"
        ),
        Entry(
            id: "egg.scrambled",
            label: "Scrambled eggs",
            aliases: ["egg", "eggs", "scrambled egg", "scrambled eggs"],
            kcalPer100Grams: 149,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 9.9,
                carbohydrateGrams: 1.6,
                fatGrams: 10.9,
                fiberGrams: 0
            )
        ),
        Entry(
            id: "beef.ground.cooked",
            label: "Cooked ground beef",
            aliases: ["beef", "ground beef", "cooked ground beef", "minced beef", "hamburger meat"],
            kcalPer100Grams: 254,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 25.9,
                carbohydrateGrams: 0,
                fatGrams: 17.2,
                fiberGrams: 0
            )
        ),
        Entry(
            id: "beef.steak.cooked",
            label: "Cooked beef steak",
            aliases: ["beef", "steak", "beef steak", "cooked steak", "sirloin", "sirloin steak"],
            kcalPer100Grams: 217,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 26.1,
                carbohydrateGrams: 0,
                fatGrams: 11.8,
                fiberGrams: 0
            )
        ),
        Entry(
            id: "beef.roast.cooked",
            label: "Cooked roast beef",
            aliases: ["beef", "roast beef", "cooked roast beef"],
            kcalPer100Grams: 170,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 29.1,
                carbohydrateGrams: 0,
                fatGrams: 5.9,
                fiberGrams: 0
            )
        ),
        Entry(
            id: "pork.tenderloin.cooked",
            label: "Cooked pork tenderloin",
            aliases: ["pork", "pork tenderloin", "cooked pork", "lean pork"],
            kcalPer100Grams: 143,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 26.2,
                carbohydrateGrams: 0,
                fatGrams: 3.5,
                fiberGrams: 0
            )
        ),
        Entry(
            id: "pork.chop.cooked",
            label: "Cooked pork chop",
            aliases: ["pork", "pork chop", "cooked pork chop", "pork loin chop"],
            kcalPer100Grams: 231,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 25.7,
                carbohydrateGrams: 0,
                fatGrams: 13.9,
                fiberGrams: 0
            )
        ),
        Entry(
            id: "pork.ground.cooked",
            label: "Cooked ground pork",
            aliases: ["pork", "ground pork", "minced pork", "cooked ground pork"],
            kcalPer100Grams: 297,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 25.7,
                carbohydrateGrams: 0,
                fatGrams: 20.8,
                fiberGrams: 0
            )
        ),
        Entry(
            id: "pork.bacon.cooked",
            label: "Cooked bacon",
            aliases: ["pork", "bacon", "cooked bacon"],
            kcalPer100Grams: 541,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 37,
                carbohydrateGrams: 1.4,
                fatGrams: 42,
                fiberGrams: 0
            ),
            defaultServingGrams: 16,
            servingLabel: "2 slices (16 g)"
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
            ),
            defaultServingGrams: 30,
            servingLabel: "1 scoop (30 g)"
        ),
        Entry(
            id: "nuts.macadamia",
            label: "Macadamia nuts",
            aliases: ["macadamia", "macadamia nut", "macadamia nuts", "raw macadamia", "raw macadamia nuts"],
            kcalPer100Grams: 718,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 7.9,
                carbohydrateGrams: 13.8,
                fatGrams: 75.8,
                fiberGrams: 8.6
            ),
            defaultServingGrams: 28,
            servingLabel: "1 oz (28 g)"
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
            aliases: ["milk", "whole milk", "full fat milk"],
            kcalPer100Grams: 61,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 3.2,
                carbohydrateGrams: 4.8,
                fatGrams: 3.3,
                fiberGrams: 0
            )
        ),
        Entry(
            id: "milk.2-percent",
            label: "2% milk",
            aliases: ["milk", "2 milk", "2% milk", "reduced fat milk"],
            kcalPer100Grams: 50,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 3.4,
                carbohydrateGrams: 4.9,
                fatGrams: 2,
                fiberGrams: 0
            )
        ),
        Entry(
            id: "milk.1-percent",
            label: "1% milk",
            aliases: ["milk", "1 milk", "1% milk", "low fat milk"],
            kcalPer100Grams: 42,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 3.4,
                carbohydrateGrams: 5,
                fatGrams: 1,
                fiberGrams: 0
            )
        ),
        Entry(
            id: "milk.skim",
            label: "Skim milk",
            aliases: ["milk", "skim milk", "nonfat milk", "fat free milk"],
            kcalPer100Grams: 34,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 3.4,
                carbohydrateGrams: 5,
                fatGrams: 0.1,
                fiberGrams: 0
            )
        ),
        Entry(
            id: "milk.oat",
            label: "Oat milk",
            aliases: ["milk", "oat milk", "oat beverage"],
            kcalPer100Grams: 48,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 1,
                carbohydrateGrams: 6.7,
                fatGrams: 1.7,
                fiberGrams: 0.8
            )
        ),
        Entry(
            id: "milk.almond.unsweetened",
            label: "Unsweetened almond milk",
            aliases: ["milk", "almond milk", "unsweetened almond milk"],
            kcalPer100Grams: 15,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 0.6,
                carbohydrateGrams: 0.6,
                fatGrams: 1.2,
                fiberGrams: 0.4
            )
        ),
        Entry(
            id: "milk.soy.unsweetened",
            label: "Unsweetened soy milk",
            aliases: ["milk", "soy milk", "unsweetened soy milk"],
            kcalPer100Grams: 33,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 3.3,
                carbohydrateGrams: 1.7,
                fatGrams: 1.8,
                fiberGrams: 0.6
            )
        ),
        Entry(
            id: "cheese.cheddar",
            label: "Cheddar cheese",
            aliases: ["cheese", "cheddar", "cheddar cheese"],
            kcalPer100Grams: 403,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 24.9,
                carbohydrateGrams: 1.3,
                fatGrams: 33.1,
                fiberGrams: 0
            )
        ),
        Entry(
            id: "cottage-cheese.lowfat",
            label: "Low-fat cottage cheese",
            aliases: ["cottage cheese", "low fat cottage cheese"],
            kcalPer100Grams: 82,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 11.5,
                carbohydrateGrams: 3.4,
                fatGrams: 2.3,
                fiberGrams: 0
            )
        ),
        Entry(
            id: "peanut-butter",
            label: "Peanut butter",
            aliases: ["peanut butter", "pb"],
            kcalPer100Grams: 588,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 25,
                carbohydrateGrams: 20,
                fatGrams: 50,
                fiberGrams: 6
            )
        ),
        Entry(
            id: "honey",
            label: "Honey",
            aliases: ["honey"],
            kcalPer100Grams: 304,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 0.3,
                carbohydrateGrams: 82.4,
                fatGrams: 0,
                fiberGrams: 0.2
            )
        ),
        Entry(
            id: "broccoli",
            label: "Broccoli",
            aliases: ["broccoli"],
            kcalPer100Grams: 34,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 2.8,
                carbohydrateGrams: 6.6,
                fatGrams: 0.4,
                fiberGrams: 2.6
            )
        ),
        Entry(
            id: "spinach.raw",
            label: "Raw spinach",
            aliases: ["spinach", "raw spinach"],
            kcalPer100Grams: 23,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 2.9,
                carbohydrateGrams: 3.6,
                fatGrams: 0.4,
                fiberGrams: 2.2
            )
        ),
        Entry(
            id: "carrot",
            label: "Carrot",
            aliases: ["carrot", "carrots"],
            kcalPer100Grams: 41,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 0.9,
                carbohydrateGrams: 9.6,
                fatGrams: 0.2,
                fiberGrams: 2.8
            )
        ),
        Entry(
            id: "potato.baked",
            label: "Baked potato",
            aliases: ["potato", "baked potato"],
            kcalPer100Grams: 93,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 2.5,
                carbohydrateGrams: 21.2,
                fatGrams: 0.1,
                fiberGrams: 2.2
            )
        ),
        Entry(
            id: "sweet-potato",
            label: "Sweet potato",
            aliases: ["sweet potato", "yam"],
            kcalPer100Grams: 86,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 1.6,
                carbohydrateGrams: 20.1,
                fatGrams: 0.1,
                fiberGrams: 3
            )
        ),
        Entry(
            id: "quinoa.cooked",
            label: "Cooked quinoa",
            aliases: ["quinoa", "cooked quinoa"],
            kcalPer100Grams: 120,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 4.4,
                carbohydrateGrams: 21.3,
                fatGrams: 1.9,
                fiberGrams: 2.8
            )
        ),
        Entry(
            id: "pasta.cooked",
            label: "Cooked pasta",
            aliases: ["pasta", "cooked pasta", "spaghetti"],
            kcalPer100Grams: 158,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 5.8,
                carbohydrateGrams: 30.9,
                fatGrams: 0.9,
                fiberGrams: 1.8
            )
        ),
        Entry(
            id: "salmon.cooked",
            label: "Cooked salmon",
            aliases: ["salmon", "cooked salmon"],
            kcalPer100Grams: 206,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 22.1,
                carbohydrateGrams: 0,
                fatGrams: 12.4,
                fiberGrams: 0
            )
        ),
        Entry(
            id: "tuna.canned-water",
            label: "Canned tuna in water",
            aliases: ["tuna", "canned tuna"],
            kcalPer100Grams: 116,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 25.5,
                carbohydrateGrams: 0,
                fatGrams: 0.8,
                fiberGrams: 0
            )
        ),
        Entry(
            id: "tofu.firm",
            label: "Firm tofu",
            aliases: ["tofu", "firm tofu"],
            kcalPer100Grams: 144,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 15.7,
                carbohydrateGrams: 3.9,
                fatGrams: 8.7,
                fiberGrams: 2.3
            )
        ),
        Entry(
            id: "beans.black.cooked",
            label: "Cooked black beans",
            aliases: ["black beans", "beans", "cooked black beans"],
            kcalPer100Grams: 132,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 8.9,
                carbohydrateGrams: 23.7,
                fatGrams: 0.5,
                fiberGrams: 8.7
            )
        ),
        Entry(
            id: "lentils.cooked",
            label: "Cooked lentils",
            aliases: ["lentils", "cooked lentils"],
            kcalPer100Grams: 116,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 9,
                carbohydrateGrams: 20.1,
                fatGrams: 0.4,
                fiberGrams: 7.9
            )
        ),
        Entry(
            id: "tortilla.flour",
            label: "Flour tortilla",
            aliases: ["tortilla", "flour tortilla"],
            kcalPer100Grams: 304,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 8,
                carbohydrateGrams: 49,
                fatGrams: 8,
                fiberGrams: 2.7
            )
        ),
        Entry(
            id: "hummus",
            label: "Hummus",
            aliases: ["hummus"],
            kcalPer100Grams: 166,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 7.9,
                carbohydrateGrams: 14.3,
                fatGrams: 9.6,
                fiberGrams: 6
            )
        ),
        Entry(
            id: "protein-powder.whey",
            label: "Whey protein powder",
            aliases: ["whey", "whey protein", "whey protein powder", "protein powder"],
            kcalPer100Grams: 400,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: 78,
                carbohydrateGrams: 8,
                fatGrams: 6,
                fiberGrams: 0
            ),
            defaultServingGrams: 30,
            servingLabel: "1 scoop (30 g)"
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
    static func candidate(for text: String) -> FoodAnalysisCandidate? {
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
            return nil
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

public enum FoodWalletExportFactory {
    public static func portableBundle(
        entries: [FoodIntakeEntry],
        templates: [SavedFoodTemplate],
        recipes: [SavedFoodRecipe],
        generatedAt: Date,
        personalFoods: [PersonalFoodIngredient] = []
    ) throws -> FoodWalletExportBundle {
        let exportEntries = entries.map(FoodWalletExportEntry.init(entry:))
        let exportPersonalFoods = personalFoods.map(FoodWalletExportPersonalFood.init(ingredient:))
        let sourceCounts = counts(entries.map { $0.sourceClass.rawValue })
        let trustCounts = counts(entries.map { $0.trustStatus.rawValue })
        var bundle = FoodWalletExportBundle(
            schema: "grain.food-wallet.bundle.v1",
            version: 1,
            generatedAt: ISO8601DateFormatter().string(from: generatedAt),
            totals: FoodWalletExportTotals(
                entryCount: entries.count,
                sumMeanKcal: entries.reduce(0) { $0 + $1.meal.kcal },
                sumVarianceKcal: entries.reduce(0) { $0 + $1.meal.varianceKcal }
            ),
            summary: FoodWalletExportSummary(
                sourceClassCounts: sourceCounts,
                trustStatusCounts: trustCounts
            ),
            entries: exportEntries,
            templates: templates.map(FoodWalletExportTemplate.init(template:)),
            recipes: recipes.map(FoodWalletExportRecipe.init(recipe:)),
            personalFoods: exportPersonalFoods.isEmpty ? nil : exportPersonalFoods,
            privacy: FoodWalletExportPrivacy(
                photoRetentionPolicy: "no_photo_storage",
                excludesProtocolCustodyMaterial: true,
                excludesPrivateMaterial: true
            ),
            manifest: FoodWalletExportManifest(
                entryCount: entries.count,
                templateCount: templates.count,
                recipeCount: recipes.count,
                personalFoodCount: exportPersonalFoods.isEmpty ? nil : exportPersonalFoods.count,
                contentSha256: "",
                contentDigestID: "",
                sourceClassSummary: sourceCounts,
                trustStatusSummary: trustCounts,
                signature: nil
            )
        )
        let contentData = try canonicalContentData(for: bundle)
        let digest = sha256Hex(contentData)
        bundle.manifest.contentSha256 = digest
        bundle.manifest.contentDigestID = "sha256:\(digest)"
        bundle.manifest.signature = try sign(contentData)
        return bundle
    }

    public static func jsonData(_ bundle: FoodWalletExportBundle) throws -> Data {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(bundle)
    }

    public static func decodeBundle(_ data: Data) throws -> FoodWalletExportBundle {
        guard isSafeForImport(data) else {
            throw FoodWalletImportError.unsafeMaterial("raw_protocol_or_photo_material")
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(FoodWalletExportBundle.self, from: data)
        } catch {
            throw FoodWalletImportError.invalidJSON
        }
    }

    public static func csv(entries: [FoodIntakeEntry]) -> String {
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

    public static func verifyIntegrity(_ bundle: FoodWalletExportBundle) -> Bool {
        do {
            try validate(bundle)
            return true
        } catch {
            return false
        }
    }

    public static func validate(_ bundle: FoodWalletExportBundle) throws {
        guard bundle.schema == "grain.food-wallet.bundle.v1" else {
            throw FoodWalletImportError.unsupportedSchema(bundle.schema)
        }
        guard bundle.version == 1 else {
            throw FoodWalletImportError.unsupportedVersion(bundle.version)
        }
        guard bundle.manifest.entryCount == bundle.entries.count else {
            throw FoodWalletImportError.invalidManifest("entry count mismatch")
        }
        guard bundle.manifest.templateCount == bundle.templates.count else {
            throw FoodWalletImportError.invalidManifest("template count mismatch")
        }
        guard bundle.manifest.recipeCount == bundle.recipes.count else {
            throw FoodWalletImportError.invalidManifest("recipe count mismatch")
        }
        let personalFoods = bundle.personalFoods ?? []
        if personalFoods.isEmpty {
            if let personalFoodCount = bundle.manifest.personalFoodCount, personalFoodCount != 0 {
                throw FoodWalletImportError.invalidManifest("personal food count mismatch")
            }
        } else {
            guard bundle.manifest.personalFoodCount == personalFoods.count else {
                throw FoodWalletImportError.invalidManifest("personal food count mismatch")
            }
        }
        let contentData = try canonicalContentData(for: bundle)
        let digest = sha256Hex(contentData)
        guard digest == bundle.manifest.contentSha256 else {
            throw FoodWalletImportError.integrityMismatch
        }
        guard bundle.manifest.contentDigestID == "sha256:\(digest)" else {
            throw FoodWalletImportError.integrityMismatch
        }
        if let signature = bundle.manifest.signature {
            guard try verify(signature: signature, contentData: contentData) else {
                throw FoodWalletImportError.signatureMismatch
            }
        }
        guard bundle.totals.entryCount == bundle.entries.count else {
            throw FoodWalletImportError.invalidManifest("total entry count mismatch")
        }
        let sourceCounts = counts(bundle.entries.map(\.sourceClass))
        let trustCounts = counts(bundle.entries.map(\.trustStatus))
        guard bundle.totals.sumMeanKcal == bundle.entries.reduce(0, { $0 + $1.kcal }) else {
            throw FoodWalletImportError.invalidManifest("total kcal mismatch")
        }
        guard bundle.totals.sumVarianceKcal == bundle.entries.reduce(0, { $0 + $1.varianceKcal }) else {
            throw FoodWalletImportError.invalidManifest("total variance mismatch")
        }
        guard sourceCounts == bundle.summary.sourceClassCounts else {
            throw FoodWalletImportError.invalidManifest("source summary mismatch")
        }
        guard trustCounts == bundle.summary.trustStatusCounts else {
            throw FoodWalletImportError.invalidManifest("trust summary mismatch")
        }
        guard sourceCounts == bundle.manifest.sourceClassSummary else {
            throw FoodWalletImportError.invalidManifest("manifest source summary mismatch")
        }
        guard trustCounts == bundle.manifest.trustStatusSummary else {
            throw FoodWalletImportError.invalidManifest("manifest trust summary mismatch")
        }
        guard bundle.privacy.photoRetentionPolicy == "no_photo_storage",
              bundle.privacy.excludesProtocolCustodyMaterial,
              bundle.privacy.excludesPrivateMaterial else {
            throw FoodWalletImportError.invalidManifest("privacy policy mismatch")
        }
        for entry in bundle.entries {
            try validate(entry)
        }
        for personalFood in personalFoods {
            try validate(personalFood)
        }
    }

    public static func importPreview(
        bundle: FoodWalletExportBundle,
        existingEntryIDs: Set<String>
    ) throws -> FoodWalletImportPreview {
        try validate(bundle)
        let incomingIDs = bundle.entries.map(\.entryID)
        let duplicateCount = incomingIDs.filter { existingEntryIDs.contains($0) }.count
        return FoodWalletImportPreview(
            integrityVerified: true,
            entryCount: bundle.entries.count,
            newEntryCount: bundle.entries.count - duplicateCount,
            duplicateEntryCount: duplicateCount,
            dateRange: dateRange(for: bundle.entries),
            sourceClassSummary: bundle.manifest.sourceClassSummary,
            trustStatusSummary: bundle.manifest.trustStatusSummary
        )
    }

    public static func entries(from bundle: FoodWalletExportBundle) throws -> [FoodIntakeEntry] {
        try validate(bundle)
        return try bundle.entries.map(FoodIntakeEntry.init(exportEntry:))
    }

    private static func validate(_ entry: FoodWalletExportEntry) throws {
        guard !entry.entryID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FoodWalletImportError.invalidEntry("missing entry id")
        }
        guard !entry.draftID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FoodWalletImportError.invalidEntry("missing draft id")
        }
        guard !entry.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FoodWalletImportError.invalidEntry("missing label")
        }
        guard entry.amountGrams >= 0, entry.kcal >= 0, entry.varianceKcal >= 0 else {
            throw FoodWalletImportError.invalidEntry("negative nutrition values")
        }
        guard FoodSourceClass(rawValue: entry.sourceClass) != nil else {
            throw FoodWalletImportError.invalidEntry("unknown source class")
        }
        guard FoodTrustStatus(rawValue: entry.trustStatus) != nil else {
            throw FoodWalletImportError.invalidEntry("unknown trust status")
        }
    }

    private static func validate(_ personalFood: FoodWalletExportPersonalFood) throws {
        guard !personalFood.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FoodWalletImportError.invalidEntry("missing personal food id")
        }
        guard !personalFood.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FoodWalletImportError.invalidEntry("missing personal food name")
        }
        guard personalFood.sourceServingGrams > 0,
              personalFood.sourceServingKcal >= 0,
              personalFood.kcalPer100Grams >= 0,
              personalFood.proteinGramsPer100 >= 0,
              personalFood.carbohydrateGramsPer100 >= 0,
              personalFood.fatGramsPer100 >= 0,
              (personalFood.fiberGramsPer100 ?? 0) >= 0 else {
            throw FoodWalletImportError.invalidEntry("invalid personal food nutrition")
        }
        guard personalFood.evidenceProvider == "food_wallet_personal_ingredient" else {
            throw FoodWalletImportError.invalidEntry("unknown personal food evidence provider")
        }
        guard personalFood.servingBasis == "user_entered_nutrition_label" else {
            throw FoodWalletImportError.invalidEntry("unknown personal food serving basis")
        }
    }

    private static func canonicalContentData(for bundle: FoodWalletExportBundle) throws -> Data {
        var unsigned = bundle
        unsigned.manifest.contentSha256 = ""
        unsigned.manifest.contentDigestID = ""
        unsigned.manifest.signature = nil
        return try jsonData(unsigned)
    }

    private static func sign(_ contentData: Data) throws -> FoodWalletExportSignature {
        let privateKey = P256.Signing.PrivateKey()
        let signature = try privateKey.signature(for: contentData)
        return FoodWalletExportSignature(
            algorithm: "p256-sha256",
            signer: "local-device-self-issued",
            publicKeyX963Base64: privateKey.publicKey.x963Representation.base64EncodedString(),
            signatureDerBase64: signature.derRepresentation.base64EncodedString()
        )
    }

    private static func verify(signature: FoodWalletExportSignature, contentData: Data) throws -> Bool {
        guard signature.algorithm == "p256-sha256" else {
            return false
        }
        guard
            let publicKeyData = Data(base64Encoded: signature.publicKeyX963Base64),
            let signatureData = Data(base64Encoded: signature.signatureDerBase64)
        else {
            return false
        }
        let publicKey = try P256.Signing.PublicKey(x963Representation: publicKeyData)
        let ecdsaSignature = try P256.Signing.ECDSASignature(derRepresentation: signatureData)
        return publicKey.isValidSignature(ecdsaSignature, for: contentData)
    }

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func counts(_ values: [String]) -> [String: Int] {
        values.reduce(into: [:]) { partial, value in
            partial[value, default: 0] += 1
        }
    }

    private static func dateRange(for entries: [FoodWalletExportEntry]) -> String? {
        let values = entries.map(\.dateKey).sorted()
        guard let first = values.first, let last = values.last else {
            return nil
        }
        return first == last ? first : "\(first)...\(last)"
    }

    private static func isSafeForImport(_ data: Data) -> Bool {
        let text = String(decoding: data, as: UTF8.self)
        let forbidden = [
            "rawPhoto",
            "photoBytes",
            "photoBase64",
            "imageBytes",
            "snapshotB64",
            "bundleB64",
            "identityBundle",
            "syncBundle",
            "privateKey",
            "trustPub",
            "COSE",
            "CBOR",
            "GR1:",
        ]
        return !forbidden.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}

public enum FoodWalletQRFactory {
    public static func payload(recipe: SavedFoodRecipe) throws -> FoodWalletQRPayload {
        let payload = FoodWalletQRPayload(
            schema: "grain.food-wallet.qr.v1",
            version: 1,
            kind: .recipe,
            title: recipe.title,
            contentSha256: "",
            issuer: nil,
            signature: nil,
            recipe: FoodWalletExportRecipe(recipe: recipe),
            personalFood: nil
        )
        return try signedPayload(payload)
    }

    public static func payload(personalFood: PersonalFoodIngredient) throws -> FoodWalletQRPayload {
        let payload = FoodWalletQRPayload(
            schema: "grain.food-wallet.qr.v1",
            version: 1,
            kind: .personalFood,
            title: personalFood.name,
            contentSha256: "",
            issuer: nil,
            signature: nil,
            recipe: nil,
            personalFood: FoodWalletExportPersonalFood(ingredient: personalFood)
        )
        return try signedPayload(payload)
    }

    public static func payloadText(_ payload: FoodWalletQRPayload) throws -> String {
        String(decoding: try jsonData(payload), as: UTF8.self)
    }

    public static func payload(from text: String) throws -> FoodWalletQRPayload {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("GR1:") {
            return try FoodWalletProtocolQRCodeFactory.payload(fromGR1: text)
        }
        guard let data = text.data(using: .utf8) else {
            throw FoodWalletQRImportError.invalidPayload
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let payload = try? decoder.decode(FoodWalletQRPayload.self, from: data) else {
            throw FoodWalletQRImportError.invalidPayload
        }
        guard payload.schema == "grain.food-wallet.qr.v1", payload.version == 1 else {
            throw FoodWalletQRImportError.unsupportedPayload
        }
        guard verify(payload) else {
            throw FoodWalletQRImportError.integrityMismatch
        }
        return payload
    }

    public static func verify(_ payload: FoodWalletQRPayload) -> Bool {
        do {
            guard payload.schema == "grain.food-wallet.qr.v1", payload.version == 1 else {
                return false
            }
            switch payload.kind {
            case .recipe:
                guard payload.recipe != nil, payload.personalFood == nil else {
                    return false
                }
            case .personalFood:
                guard payload.personalFood != nil, payload.recipe == nil else {
                    return false
                }
            }
            guard try contentDigest(payload) == payload.contentSha256 else {
                return false
            }
            guard let signature = payload.signature else {
                return false
            }
            return try verify(signature: signature, contentData: contentData(for: payload))
        } catch {
            return false
        }
    }

    private static func signedPayload(_ payload: FoodWalletQRPayload) throws -> FoodWalletQRPayload {
        let privateKey = P256.Signing.PrivateKey()
        var signed = payload
        signed.signature = nil
        signed.contentSha256 = ""
        let publicKey = privateKey.publicKey.x963Representation
        let keyID = "p256:\(sha256Hex(publicKey).prefix(16))"
        signed.issuer = FoodWalletQRIssuer(label: "MealMark self-issued", keyID: keyID)
        let contentData = try contentData(for: signed)
        signed.contentSha256 = sha256Hex(contentData)
        let signature = try privateKey.signature(for: contentData)
        signed.signature = FoodWalletExportSignature(
            algorithm: "p256-sha256",
            signer: signed.issuer?.label ?? "MealMark self-issued",
            publicKeyX963Base64: publicKey.base64EncodedString(),
            signatureDerBase64: signature.derRepresentation.base64EncodedString()
        )
        return signed
    }

    private static func contentDigest(_ payload: FoodWalletQRPayload) throws -> String {
        sha256Hex(try contentData(for: payload))
    }

    private static func contentData(for payload: FoodWalletQRPayload) throws -> Data {
        var unsigned = payload
        unsigned.contentSha256 = ""
        unsigned.signature = nil
        return try jsonData(unsigned)
    }

    private static func verify(signature: FoodWalletExportSignature, contentData: Data) throws -> Bool {
        guard signature.algorithm == "p256-sha256",
              let publicKeyData = Data(base64Encoded: signature.publicKeyX963Base64),
              let signatureData = Data(base64Encoded: signature.signatureDerBase64) else {
            return false
        }
        let publicKey = try P256.Signing.PublicKey(x963Representation: publicKeyData)
        let ecdsaSignature = try P256.Signing.ECDSASignature(derRepresentation: signatureData)
        return publicKey.isValidSignature(ecdsaSignature, for: contentData)
    }

    private static func jsonData(_ payload: FoodWalletQRPayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(payload)
    }

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

extension FoodWalletExportEntry {
    init(entry: FoodIntakeEntry) {
        entryID = entry.entryID
        draftID = entry.draftID
        confirmedAt = String(format: "%.17g", entry.confirmedAt.timeIntervalSinceReferenceDate)
        dateKey = entry.dateKey
        label = entry.meal.label
        kcal = entry.meal.kcal
        varianceKcal = entry.meal.varianceKcal
        amountGrams = entry.meal.amountGrams
        servingGrams = entry.meal.servingGrams
        servings = entry.meal.servings
        proteinGrams = entry.meal.macronutrients?.proteinGrams
        carbohydrateGrams = entry.meal.macronutrients?.carbohydrateGrams
        fatGrams = entry.meal.macronutrients?.fatGrams
        fiberGrams = entry.meal.macronutrients?.fiberGrams
        sourceClass = entry.sourceClass.rawValue
        trustStatus = entry.trustStatus.rawValue
    }

    var mealEstimate: MealEstimate {
        let macronutrients: MealMacronutrients?
        if proteinGrams == nil, carbohydrateGrams == nil, fatGrams == nil, fiberGrams == nil {
            macronutrients = nil
        } else {
            macronutrients = MealMacronutrients(
                proteinGrams: proteinGrams ?? 0,
                carbohydrateGrams: carbohydrateGrams ?? 0,
                fatGrams: fatGrams ?? 0,
                fiberGrams: fiberGrams
            )
        }
        return MealEstimate(
            label: label,
            kcal: kcal,
            varianceKcal: varianceKcal,
            amountGrams: amountGrams,
            servingGrams: servingGrams,
            servings: servings,
            macronutrients: macronutrients
        )
    }
}

public enum FoodWalletLocalLedgerCodec {
    public static func encodeEntries(_ entries: [FoodIntakeEntry]) throws -> Data {
        let state = FoodWalletLocalLedgerState(
            schema: "grain.food-wallet.local-ledger.v1",
            version: 1,
            entries: entries.map(FoodWalletExportEntry.init(entry:))
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(state)
    }

    public static func decodeEntries(_ data: Data) throws -> [FoodIntakeEntry] {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let state: FoodWalletLocalLedgerState
        do {
            state = try decoder.decode(FoodWalletLocalLedgerState.self, from: data)
        } catch {
            throw FoodWalletImportError.invalidJSON
        }
        guard state.schema == "grain.food-wallet.local-ledger.v1" else {
            throw FoodWalletImportError.unsupportedSchema(state.schema)
        }
        guard state.version == 1 else {
            throw FoodWalletImportError.unsupportedVersion(state.version)
        }
        return try state.entries.map(FoodIntakeEntry.init(exportEntry:))
    }
}

public enum FoodWalletUserLibraryCodec {
    public static func encode(_ state: FoodWalletUserLibraryState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(state)
    }

    public static func encode(
        templates: [SavedFoodTemplate],
        recipes: [SavedFoodRecipe],
        personalIngredients: [PersonalFoodIngredient]
    ) throws -> Data {
        try encode(FoodWalletUserLibraryState(
            templates: templates,
            recipes: recipes,
            personalIngredients: personalIngredients
        ))
    }

    public static func decode(_ data: Data) throws -> FoodWalletUserLibraryState {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            let state = try decoder.decode(FoodWalletUserLibraryState.self, from: data)
            try validate(state)
            return state
        } catch let error as FoodWalletImportError {
            throw error
        } catch {
            if let legacyPersonalIngredients = try? decoder.decode([PersonalFoodIngredient].self, from: data) {
                let state = FoodWalletUserLibraryState(personalIngredients: legacyPersonalIngredients)
                try validate(state)
                return state
            }
            throw FoodWalletImportError.invalidJSON
        }
    }

    private static func validate(_ state: FoodWalletUserLibraryState) throws {
        guard state.schema == "grain.food-wallet.user-library.v1" else {
            throw FoodWalletImportError.unsupportedSchema(state.schema)
        }
        guard state.version == 1 else {
            throw FoodWalletImportError.unsupportedVersion(state.version)
        }
    }
}

private extension FoodIntakeEntry {
    init(exportEntry: FoodWalletExportEntry) throws {
        guard !exportEntry.entryID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FoodWalletImportError.invalidEntry("missing entry id")
        }
        guard !exportEntry.draftID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FoodWalletImportError.invalidEntry("missing draft id")
        }
        guard !exportEntry.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FoodWalletImportError.invalidEntry("missing label")
        }
        guard exportEntry.amountGrams >= 0,
              exportEntry.kcal >= 0,
              exportEntry.varianceKcal >= 0 else {
            throw FoodWalletImportError.invalidEntry("negative nutrition values")
        }
        guard let sourceClass = FoodSourceClass(rawValue: exportEntry.sourceClass) else {
            throw FoodWalletImportError.invalidEntry("unknown source class")
        }
        guard let trustStatus = FoodTrustStatus(rawValue: exportEntry.trustStatus) else {
            throw FoodWalletImportError.invalidEntry("unknown trust status")
        }
        let confirmedAt = Double(exportEntry.confirmedAt).map(Date.init(timeIntervalSinceReferenceDate:))
            ?? foodWalletISO8601Formatter().date(from: exportEntry.confirmedAt)
            ?? ISO8601DateFormatter().date(from: exportEntry.confirmedAt)
            ?? Date(timeIntervalSince1970: 0)
        self.init(
            entryID: exportEntry.entryID,
            draftID: exportEntry.draftID,
            meal: exportEntry.mealEstimate,
            sourceClass: sourceClass,
            trustStatus: trustStatus,
            confirmedAt: confirmedAt,
            dateKey: exportEntry.dateKey
        )
    }
}

private func foodWalletISO8601Formatter() -> ISO8601DateFormatter {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}

private extension FoodWalletExportTemplate {
    init(template: SavedFoodTemplate) {
        id = template.id
        title = template.title
        subtitle = template.subtitle
        kcal = template.kcal
        varianceKcal = template.varianceKcal
        amountGrams = template.amountGrams
        servingGrams = template.servingGrams
        servings = template.servings
        proteinGrams = template.macronutrients.proteinGrams
        carbohydrateGrams = template.macronutrients.carbohydrateGrams
        fatGrams = template.macronutrients.fatGrams
        fiberGrams = template.macronutrients.fiberGrams
        evidenceProvider = "food_wallet_template"
        servingBasis = "saved_template"
    }
}

private extension FoodWalletExportRecipe {
    init(recipe: SavedFoodRecipe) {
        id = recipe.id
        title = recipe.title
        subtitle = recipe.subtitle
        totalKcal = recipe.totalKcal
        totalGrams = recipe.totalGrams
        ingredients = recipe.ingredients.map(\.label)
        ingredientDetails = recipe.ingredients.map(FoodWalletExportRecipeIngredient.init(ingredient:))
        proteinGrams = recipe.macronutrients.proteinGrams
        carbohydrateGrams = recipe.macronutrients.carbohydrateGrams
        fatGrams = recipe.macronutrients.fatGrams
        fiberGrams = recipe.macronutrients.fiberGrams
        evidenceProvider = "food_wallet_recipe"
        servingBasis = "recipe_yield"
    }
}

extension SavedFoodRecipe {
    init(exportRecipe: FoodWalletExportRecipe) {
        let details = exportRecipe.ingredientDetails ?? exportRecipe.ingredients.enumerated().map { index, label in
            FoodWalletExportRecipeIngredient(
                id: "qr-ingredient-\(index)",
                label: label,
                grams: 0,
                kcal: 0
            )
        }
        let macros = MealMacronutrients(
            proteinGrams: exportRecipe.proteinGrams ?? 0,
            carbohydrateGrams: exportRecipe.carbohydrateGrams ?? 0,
            fatGrams: exportRecipe.fatGrams ?? 0,
            fiberGrams: exportRecipe.fiberGrams
        )
        self.init(
            id: exportRecipe.id,
            title: exportRecipe.title,
            subtitle: exportRecipe.subtitle ?? details.prefix(3).map(\.label).joined(separator: ", "),
            totalGrams: exportRecipe.totalGrams,
            totalKcal: exportRecipe.totalKcal,
            macronutrients: macros,
            ingredients: details.map(SavedFoodRecipeIngredient.init(exportIngredient:))
        )
    }
}

private extension FoodWalletExportRecipeIngredient {
    init(ingredient: SavedFoodRecipeIngredient) {
        id = ingredient.id
        label = ingredient.label
        grams = ingredient.grams
        kcal = ingredient.kcal
    }
}

extension SavedFoodRecipeIngredient {
    init(exportIngredient: FoodWalletExportRecipeIngredient) {
        self.init(
            id: exportIngredient.id,
            label: exportIngredient.label,
            grams: exportIngredient.grams,
            kcal: exportIngredient.kcal
        )
    }
}

private extension FoodWalletExportPersonalFood {
    init(ingredient: PersonalFoodIngredient) {
        id = ingredient.id
        name = ingredient.name
        sourceServingGrams = ingredient.sourceServingGrams
        sourceServingKcal = ingredient.sourceServingKcal
        kcalPer100Grams = ingredient.kcalPer100Grams
        proteinGramsPer100 = ingredient.macronutrientsPer100Grams.proteinGrams
        carbohydrateGramsPer100 = ingredient.macronutrientsPer100Grams.carbohydrateGrams
        fatGramsPer100 = ingredient.macronutrientsPer100Grams.fatGrams
        fiberGramsPer100 = ingredient.macronutrientsPer100Grams.fiberGrams
        evidenceProvider = "food_wallet_personal_ingredient"
        servingBasis = "user_entered_nutrition_label"
    }
}

extension PersonalFoodIngredient {
    init(exportPersonalFood: FoodWalletExportPersonalFood) {
        self.init(
            id: exportPersonalFood.id,
            name: exportPersonalFood.name,
            sourceServingGrams: exportPersonalFood.sourceServingGrams,
            sourceServingKcal: exportPersonalFood.sourceServingKcal,
            kcalPer100Grams: exportPersonalFood.kcalPer100Grams,
            macronutrientsPer100Grams: MealMacronutrients(
                proteinGrams: exportPersonalFood.proteinGramsPer100,
                carbohydrateGrams: exportPersonalFood.carbohydrateGramsPer100,
                fatGrams: exportPersonalFood.fatGramsPer100,
                fiberGrams: exportPersonalFood.fiberGramsPer100
            )
        )
    }
}
