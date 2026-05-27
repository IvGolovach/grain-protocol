export { defaultMealMarkFoodGraphArtifactDir, loadLocalFoodGraphArtifact } from "./artifact.js";
export { LocalFoodGraphProvider, normalizeIngredientInput } from "./provider.js";

export type {
  FoodGraphArtifact,
  FoodGraphArtifactManifest,
  FoodGraphMealInput,
  FoodGraphModelKey,
  FoodGraphNeighbor,
  FoodGraphPairingSuggestion,
  FoodGraphResolvedIngredient,
  FoodGraphRuntimePolicy,
  FoodGraphSimilarMeal,
  FoodGraphSourceRef
} from "./types.js";
