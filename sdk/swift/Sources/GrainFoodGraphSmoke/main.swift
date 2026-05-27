import Foundation
import GrainFoodGraph

@main
struct GrainFoodGraphSmoke {
    static func main() throws {
        let graph = try LocalFoodGraph.loadBundledMealMarkGraph()
        try require(graph.artifactID == "mealmark-food-graph-v0.1", "artifact id mismatch")

        let yogurt = graph.resolveIngredient("Greek yogurt")
        try require(yogurt.status == .resolved, "Greek yogurt should resolve")
        try require(yogurt.canonicalName == "yogurt", "Greek yogurt alias mismatch")

        let walnuts = graph.resolveIngredient("walnuts")
        try require(walnuts.canonicalName == "walnut", "safe singular mismatch")

        let arborio = graph.resolveIngredient("arborio rice")
        try require(arborio.canonicalName == "rice", "arborio rice alias mismatch")
        try require(arborio.canonicalName != "ice", "arborio rice must not resolve to ice")

        let stock = graph.resolveIngredient("stock")
        try require(stock.status == .ambiguous, "stock should stay ambiguous")

        let missing = graph.resolveIngredient("totally unknown ingredient")
        try require(missing.status == .unmapped, "unknown input should stay unmapped")

        let ramen = graph.suggestPairings(
            ingredients: ["ramen noodle", "pork", "egg", "scallion", "miso", "garlic"],
            model: .core,
            limit: 8
        )
        try require(
            ramen.contains { $0.name == "sesame_oil" || $0.name == "oyster_sauce" },
            "ramen pairings should contain useful advisory suggestions"
        )
        try require(ramen.allSatisfy(\.advisoryOnly), "pairings must be advisory-only")

        let similar = graph.similarMeals(
            meal: FoodGraphMealInput(
                mealID: "salmon-bowl",
                label: "Salmon bowl",
                ingredients: ["salmon", "rice", "avocado", "cucumber", "soy sauce", "sesame seed"]
            ),
            history: [
                FoodGraphMealInput(
                    mealID: "salmon-sushi",
                    label: "Salmon sushi roll",
                    ingredients: ["salmon", "rice", "nori", "avocado", "cucumber", "soy sauce"]
                ),
                FoodGraphMealInput(
                    mealID: "yogurt",
                    label: "Greek yogurt, walnuts, honey",
                    ingredients: ["greek yogurt", "walnut", "honey"]
                ),
            ]
        )
        try require(similar.first?.mealID == "salmon-sushi", "similar meals ranking mismatch")
        try require(similar.allSatisfy(\.advisoryOnly), "similar meal results must be advisory-only")

        let sourceRef = graph.sourceRef(for: graph.resolveIngredients(["Greek yogurt", "stock", "not-a-food"]))
        try require(sourceRef.foodGraph.advisoryOnly, "source ref should be advisory-only")
        try require(!sourceRef.foodGraph.mayChangeKcal, "source ref must not change kcal")
        try require(!sourceRef.foodGraph.mayChangeRecordTrust, "source ref must not change record trust")
        try require(!sourceRef.foodGraph.mayChangeNutritionConfidence, "source ref must not change nutrition confidence")
        let encoded = try JSONEncoder().encode(sourceRef)
        let text = String(decoding: encoded, as: UTF8.self)
        for token in ["COSE", "privateKey", "photo_bytes", "\"mean\"", "\"var\"", "recordTrust", "nutritionConfidence"] {
            try require(!text.contains(token), "source ref leaked forbidden token \(token)")
        }

        print("swift food graph smoke: PASS")
    }
}

private func require(_ condition: Bool, _ message: String) throws {
    if !condition {
        throw SmokeError.assertion(message)
    }
}

private enum SmokeError: Error {
    case assertion(String)
}
