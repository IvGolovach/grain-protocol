import Foundation

public enum FoodGraphModelKey: String, Codable, CaseIterable, Sendable {
    case cooc
    case core
    case chem
}

public enum FoodGraphMatchStatus: String, Codable, Sendable {
    case resolved
    case ambiguous
    case unmapped
}

public enum FoodGraphMatchMethod: String, Codable, Sendable {
    case exact
    case alias
    case safeSingular = "safe_singular"
    case ambiguousAlias = "ambiguous_alias"
    case unmapped
}

public struct FoodGraphNeighbor: Codable, Equatable, Sendable {
    public let name: String
    public let score: Double
}

public struct FoodGraphResolvedIngredient: Equatable, Sendable {
    public let input: String
    public let normalized: String
    public let status: FoodGraphMatchStatus
    public let method: FoodGraphMatchMethod
    public let canonicalName: String?
    public let confidence: Double
    public let candidates: [String]
    public let warning: String?
}

public struct FoodGraphPairingSuggestion: Equatable, Sendable {
    public let name: String
    public let score: Double
    public let model: FoodGraphModelKey
    public let via: [String]
    public let advisoryOnly = true
}

public struct FoodGraphMealInput: Equatable, Sendable {
    public let mealID: String?
    public let label: String?
    public let ingredients: [String]

    public init(mealID: String? = nil, label: String? = nil, ingredients: [String]) {
        self.mealID = mealID
        self.label = label
        self.ingredients = ingredients
    }
}

public struct FoodGraphSimilarMeal: Equatable, Sendable {
    public let mealID: String?
    public let label: String?
    public let score: Double
    public let sharedIngredients: [String]
    public let relatedIngredients: [String]
    public let advisoryOnly = true
}

public struct FoodGraphSourceRef: Codable, Equatable, Sendable {
    public struct Payload: Codable, Equatable, Sendable {
        public struct Resolved: Codable, Equatable, Sendable {
            public let input: String
            public let canonicalName: String
            public let method: FoodGraphMatchMethod
            public let confidence: Double

            enum CodingKeys: String, CodingKey {
                case input
                case canonicalName = "canonical_name"
                case method
                case confidence
            }
        }

        public struct Ambiguous: Codable, Equatable, Sendable {
            public let input: String
            public let candidates: [String]
        }

        public let artifactID: String
        public let advisoryOnly: Bool
        public let mayChangeKcal: Bool
        public let mayChangeRecordTrust: Bool
        public let mayChangeNutritionConfidence: Bool
        public let resolvedIngredients: [Resolved]
        public let ambiguousInputs: [Ambiguous]
        public let unmappedInputs: [String]

        enum CodingKeys: String, CodingKey {
            case artifactID = "artifact_id"
            case advisoryOnly = "advisory_only"
            case mayChangeKcal = "may_change_kcal"
            case mayChangeRecordTrust = "may_change_record_trust"
            case mayChangeNutritionConfidence = "may_change_nutrition_confidence"
            case resolvedIngredients = "resolved_ingredients"
            case ambiguousInputs = "ambiguous_inputs"
            case unmappedInputs = "unmapped_inputs"
        }
    }

    public let foodGraph: Payload

    enum CodingKeys: String, CodingKey {
        case foodGraph = "food_graph"
    }
}

public enum FoodGraphError: Error, Equatable, CustomStringConvertible {
    case missingBundledResource(String)
    case invalidArtifactPolicy

    public var description: String {
        switch self {
        case .missingBundledResource(let name):
            return "Missing bundled food graph resource: \(name)"
        case .invalidArtifactPolicy:
            return "Food graph artifact must be local, advisory-only, and forbidden from changing nutrition/trust state"
        }
    }
}

public final class LocalFoodGraph: @unchecked Sendable {
    private let manifest: Manifest
    private let vocabulary: Set<String>
    private let aliases: [String: String]
    private let ambiguousAliases: [String: [String]]
    private let neighbors: [FoodGraphModelKey: [String: [FoodGraphNeighbor]]]

    public var artifactID: String { manifest.artifactID }

    public static func loadBundledMealMarkGraph() throws -> LocalFoodGraph {
        try LocalFoodGraph(bundle: .module, resourceDirectory: "MealMarkFoodGraph")
    }

    public init(bundle: Bundle, resourceDirectory: String) throws {
        manifest = try Self.decodeBundled(Manifest.self, name: "manifest", bundle: bundle, directory: resourceDirectory)
        let vocabularyArray = try Self.decodeBundled([String].self, name: "vocabulary", bundle: bundle, directory: resourceDirectory)
        let aliasesFile = try Self.decodeBundled(AliasFile.self, name: "aliases", bundle: bundle, directory: resourceDirectory)
        var loadedNeighbors: [FoodGraphModelKey: [String: [FoodGraphNeighbor]]] = [:]
        for key in FoodGraphModelKey.allCases {
            loadedNeighbors[key] = try Self.decodeBundled(
                [String: [FoodGraphNeighbor]].self,
                name: "neighbors-\(key.rawValue)",
                bundle: bundle,
                directory: resourceDirectory
            )
        }
        vocabulary = Set(vocabularyArray)
        aliases = aliasesFile.aliases
        ambiguousAliases = aliasesFile.ambiguousAliases
        neighbors = loadedNeighbors
        try assertArtifactPolicy()
    }

    public func resolveIngredient(_ input: String) -> FoodGraphResolvedIngredient {
        let normalized = Self.normalize(input)
        if normalized.isEmpty {
            return unmapped(input: input, normalized: normalized, warning: "empty ingredient input")
        }
        if let candidates = ambiguousAliases[normalized] {
            return FoodGraphResolvedIngredient(
                input: input,
                normalized: normalized,
                status: .ambiguous,
                method: .ambiguousAlias,
                canonicalName: nil,
                confidence: 0,
                candidates: candidates,
                warning: "Input is intentionally ambiguous and must be confirmed by the app or user."
            )
        }
        let canonicalInput = normalized.replacingOccurrences(of: " ", with: "_")
        if vocabulary.contains(canonicalInput) {
            return resolved(input: input, normalized: normalized, canonicalName: canonicalInput, method: .exact, confidence: 1)
        }
        if let alias = aliases[normalized], vocabulary.contains(alias) {
            return resolved(input: input, normalized: normalized, canonicalName: alias, method: .alias, confidence: 0.96)
        }
        if let singular = Self.safeSingularCandidate(canonicalInput), vocabulary.contains(singular) {
            return resolved(input: input, normalized: normalized, canonicalName: singular, method: .safeSingular, confidence: 0.92)
        }
        return unmapped(input: input, normalized: normalized, warning: "No exact, alias, or safe singular match.")
    }

    public func resolveIngredients(_ inputs: [String]) -> [FoodGraphResolvedIngredient] {
        inputs.map(resolveIngredient)
    }

    public func suggestPairings(
        ingredients: [String],
        model: FoodGraphModelKey = .core,
        limit: Int = 8
    ) -> [FoodGraphPairingSuggestion] {
        let boundedLimit = Self.boundedLimit(limit, max: 32)
        let canonical = Set(resolveIngredients(ingredients).compactMap(\.canonicalName))
        guard !canonical.isEmpty else { return [] }
        var aggregate: [String: (score: Double, via: Set<String>)] = [:]
        let modelNeighbors = neighbors[model] ?? [:]
        for ingredient in canonical {
            for neighbor in modelNeighbors[ingredient] ?? [] {
                guard !canonical.contains(neighbor.name) else { continue }
                var current = aggregate[neighbor.name] ?? (score: 0, via: [])
                current.score += neighbor.score
                current.via.insert(ingredient)
                aggregate[neighbor.name] = current
            }
        }
        return aggregate.map { name, value in
            let viaCount = max(1, value.via.count)
            let boost = min(0.16, Double(value.via.count - 1) * 0.08)
            return FoodGraphPairingSuggestion(
                name: name,
                score: Self.roundScore(value.score / Double(viaCount) + boost),
                model: model,
                via: value.via.sorted()
            )
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score { return lhs.name < rhs.name }
            return lhs.score > rhs.score
        }
        .prefix(boundedLimit)
        .map { $0 }
    }

    public func similarMeals(
        meal: FoodGraphMealInput,
        history: [FoodGraphMealInput],
        model: FoodGraphModelKey = .core,
        limit: Int = 5
    ) -> [FoodGraphSimilarMeal] {
        let boundedLimit = Self.boundedLimit(limit, max: 50)
        let base = Set(resolveIngredients(meal.ingredients).compactMap(\.canonicalName))
        guard !base.isEmpty else { return [] }
        let related = relatedSet(for: base, model: model)
        return history.compactMap { candidate in
            let candidateSet = Set(resolveIngredients(candidate.ingredients).compactMap(\.canonicalName))
            let shared = base.intersection(candidateSet).sorted()
            let relatedIngredients = related.intersection(candidateSet).subtracting(shared).sorted()
            let unionCount = max(1, base.union(candidateSet).count)
            let score = Double(shared.count) / Double(unionCount) + Double(relatedIngredients.count) / Double(max(1, candidateSet.count)) * 0.35
            guard score > 0 else { return nil }
            return FoodGraphSimilarMeal(
                mealID: candidate.mealID,
                label: candidate.label,
                score: Self.roundScore(score),
                sharedIngredients: shared,
                relatedIngredients: relatedIngredients
            )
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score { return (lhs.label ?? "") < (rhs.label ?? "") }
            return lhs.score > rhs.score
        }
        .prefix(boundedLimit)
        .map { $0 }
    }

    public func sourceRef(for resolutions: [FoodGraphResolvedIngredient]) -> FoodGraphSourceRef {
        FoodGraphSourceRef(
            foodGraph: FoodGraphSourceRef.Payload(
                artifactID: manifest.artifactID,
                advisoryOnly: true,
                mayChangeKcal: false,
                mayChangeRecordTrust: false,
                mayChangeNutritionConfidence: false,
                resolvedIngredients: resolutions.compactMap { item in
                    guard item.status == .resolved, let canonical = item.canonicalName else { return nil }
                    return FoodGraphSourceRef.Payload.Resolved(
                        input: item.input,
                        canonicalName: canonical,
                        method: item.method,
                        confidence: item.confidence
                    )
                },
                ambiguousInputs: resolutions.compactMap { item in
                    guard item.status == .ambiguous else { return nil }
                    return FoodGraphSourceRef.Payload.Ambiguous(input: item.input, candidates: item.candidates)
                },
                unmappedInputs: resolutions.compactMap { item in
                    item.status == .unmapped ? item.input : nil
                }
            )
        )
    }

    private func relatedSet(for base: Set<String>, model: FoodGraphModelKey) -> Set<String> {
        var out: Set<String> = []
        let modelNeighbors = neighbors[model] ?? [:]
        for name in base {
            for neighbor in (modelNeighbors[name] ?? []).prefix(8) {
                out.insert(neighbor.name)
            }
        }
        return out
    }

    private func resolved(
        input: String,
        normalized: String,
        canonicalName: String,
        method: FoodGraphMatchMethod,
        confidence: Double
    ) -> FoodGraphResolvedIngredient {
        FoodGraphResolvedIngredient(
            input: input,
            normalized: normalized,
            status: .resolved,
            method: method,
            canonicalName: canonicalName,
            confidence: confidence,
            candidates: [canonicalName],
            warning: nil
        )
    }

    private func unmapped(input: String, normalized: String, warning: String) -> FoodGraphResolvedIngredient {
        FoodGraphResolvedIngredient(
            input: input,
            normalized: normalized,
            status: .unmapped,
            method: .unmapped,
            canonicalName: nil,
            confidence: 0,
            candidates: [],
            warning: warning
        )
    }

    private func assertArtifactPolicy() throws {
        let policy = manifest.runtimePolicy
        guard policy.noNetworkRequired,
              policy.advisoryOnly,
              !policy.mayChangeKcal,
              !policy.mayChangeRecordTrust,
              !policy.mayChangeNutritionConfidence,
              policy.photoPersistencePolicy == "forbidden",
              policy.rawVectorPersistence == "forbidden" else {
            throw FoodGraphError.invalidArtifactPolicy
        }
    }

    private static func decodeBundled<T: Decodable>(
        _ type: T.Type,
        name: String,
        bundle: Bundle,
        directory: String
    ) throws -> T {
        let url = bundle.url(forResource: name, withExtension: "json", subdirectory: directory)
            ?? bundle.url(forResource: name, withExtension: "json")
        guard let url else {
            throw FoodGraphError.missingBundledResource("\(directory)/\(name).json")
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }

    public static func normalize(_ input: String) -> String {
        let folded = input
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
        let scalars = folded.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return String(scalars)
            .split(separator: " ")
            .joined(separator: " ")
    }

    private static func safeSingularCandidate(_ canonicalInput: String) -> String? {
        guard canonicalInput.count >= 4 else { return nil }
        if canonicalInput.hasSuffix("ies") {
            return String(canonicalInput.dropLast(3)) + "y"
        }
        if canonicalInput.hasSuffix("oes") || canonicalInput.hasSuffix("ses") {
            return String(canonicalInput.dropLast(2))
        }
        if canonicalInput.hasSuffix("s") && !canonicalInput.hasSuffix("ss") {
            return String(canonicalInput.dropLast())
        }
        return nil
    }

    private static func boundedLimit(_ value: Int, max: Int) -> Int {
        Swift.max(1, Swift.min(value, max))
    }

    private static func roundScore(_ value: Double) -> Double {
        (value * 1_000_000).rounded() / 1_000_000
    }
}

private struct AliasFile: Decodable {
    let aliases: [String: String]
    let ambiguousAliases: [String: [String]]

    enum CodingKeys: String, CodingKey {
        case aliases
        case ambiguousAliases = "ambiguous_aliases"
    }
}

private struct Manifest: Decodable {
    let artifactID: String
    let runtimePolicy: RuntimePolicy

    enum CodingKeys: String, CodingKey {
        case artifactID = "artifact_id"
        case runtimePolicy = "runtime_policy"
    }
}

private struct RuntimePolicy: Decodable {
    let noNetworkRequired: Bool
    let advisoryOnly: Bool
    let mayChangeKcal: Bool
    let mayChangeRecordTrust: Bool
    let mayChangeNutritionConfidence: Bool
    let photoPersistencePolicy: String
    let rawVectorPersistence: String

    enum CodingKeys: String, CodingKey {
        case noNetworkRequired = "no_network_required"
        case advisoryOnly = "advisory_only"
        case mayChangeKcal = "may_change_kcal"
        case mayChangeRecordTrust = "may_change_record_trust"
        case mayChangeNutritionConfidence = "may_change_nutrition_confidence"
        case photoPersistencePolicy = "raw_photo_persistence"
        case rawVectorPersistence = "raw_vector_persistence"
    }
}
