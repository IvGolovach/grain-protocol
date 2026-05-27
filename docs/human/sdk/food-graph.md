# MealMark Food Graph

MealMark Food Graph is an optional SDK AI sidecar for ingredient-aware product
features. It is not a Grain protocol change and it is not nutrition truth.

The graph can help an app resolve ingredient names, suggest related ingredients,
and find similar meals in a local archive. It must stay outside the proof path:
Grain records still answer what was recorded, by whom, from what source, and
with what nutrition confidence.

## Runtime boundary

- Runtime reads a committed local artifact.
- Runtime must not call Hugging Face, the Epicure Space, or any remote model
  endpoint.
- Runtime must not persist raw photos, raw vectors, prompts, or provider session
  material.
- Runtime output is advisory. It may be shown in UI or stored as app metadata,
  but it does not verify source, calories, macros, or ingredient safety.

## App flow

1. App captures or receives food text, OCR, barcode, or user-entered
   ingredients.
2. Food Graph resolves exact matches, app-owned aliases, and safe singulars.
3. Ambiguous input stays ambiguous. Unknown input stays unmapped.
4. The app may show suggestions or similar meals.
5. The user confirms the meal through the Food Wallet draft boundary.
6. Grain writes only the confirmed Food Wallet event.

## Integration surfaces

TypeScript:

```ts
import { loadLocalFoodGraphArtifact, LocalFoodGraphProvider } from "grain-sdk-ai-ts";

const graph = new LocalFoodGraphProvider(loadLocalFoodGraphArtifact());
const resolved = graph.resolveIngredients(["Greek yogurt", "walnuts", "honey"]);
const sourceRef = graph.sourceRefFor(resolved);
```

Swift:

```swift
import GrainFoodGraph

let graph = try LocalFoodGraph.loadBundledMealMarkGraph()
let similar = graph.similarMeals(
    meal: FoodGraphMealInput(label: "Salmon bowl", ingredients: ["salmon", "rice", "avocado"]),
    history: previousMeals
)
```

## Required checks

```bash
npm --prefix core/ts/grain-sdk-ai run test:food-graph
python3 tools/ci/check_sdk_no_network.py
python3 tools/ci/check_sdk_ai_boundary.py
scripts/sdk/check_swift_package.sh
scripts/sdk/check_food_wallet_contract.sh
```

## Update process

The update-only builder lives at `tools/food_graph/build_mealmark_food_graph.py`.
It pins Epicure model revisions and writes deterministic JSON artifacts. The
builder may depend on Hugging Face tooling; the runtime packages must not.

After rebuilding, run the required checks and review the manifest license,
revision, and checksum changes before committing.
