export type FoodGraphModelKey = "cooc" | "core" | "chem";

export type FoodGraphMatchStatus = "resolved" | "ambiguous" | "unmapped";

export type FoodGraphMatchMethod =
  | "exact"
  | "alias"
  | "safe_singular"
  | "ambiguous_alias"
  | "unmapped";

export type FoodGraphRuntimePolicy = {
  no_network_required: true;
  advisory_only: true;
  may_change_kcal: false;
  may_change_record_trust: false;
  may_change_nutrition_confidence: false;
  raw_photo_persistence: "forbidden";
  raw_vector_persistence: "forbidden";
};

export type FoodGraphArtifactManifest = {
  schema: "mealmark.food_graph.artifact.v1";
  artifact_id: string;
  created_by: string;
  source: {
    name: string;
    paper: string;
    models: Record<FoodGraphModelKey, { repo: string; revision: string }>;
    license: string;
  };
  runtime_policy: FoodGraphRuntimePolicy;
  vocabulary_count: number;
  neighbor_limit: number;
  files: Record<string, { sha256: string; bytes: number }>;
};

export type FoodGraphNeighbor = {
  name: string;
  score: number;
};

export type FoodGraphArtifact = {
  manifest: FoodGraphArtifactManifest;
  vocabulary: readonly string[];
  aliases: ReadonlyMap<string, string>;
  ambiguousAliases: ReadonlyMap<string, readonly string[]>;
  neighbors: ReadonlyMap<FoodGraphModelKey, ReadonlyMap<string, readonly FoodGraphNeighbor[]>>;
};

export type FoodGraphResolvedIngredient = {
  input: string;
  normalized: string;
  status: FoodGraphMatchStatus;
  method: FoodGraphMatchMethod;
  canonicalName?: string;
  confidence: number;
  candidates: readonly string[];
  warning?: string;
};

export type FoodGraphPairingSuggestion = {
  name: string;
  score: number;
  model: FoodGraphModelKey;
  via: readonly string[];
  advisoryOnly: true;
};

export type FoodGraphMealInput = {
  mealId?: string;
  label?: string;
  ingredients: readonly string[];
};

export type FoodGraphSimilarMeal = {
  mealId?: string;
  label?: string;
  score: number;
  sharedIngredients: readonly string[];
  relatedIngredients: readonly string[];
  advisoryOnly: true;
};

export type FoodGraphSourceRef = {
  food_graph: {
    artifact_id: string;
    advisory_only: true;
    may_change_kcal: false;
    may_change_record_trust: false;
    may_change_nutrition_confidence: false;
    resolved_ingredients: readonly {
      input: string;
      canonical_name: string;
      method: FoodGraphMatchMethod;
      confidence: number;
    }[];
    ambiguous_inputs: readonly {
      input: string;
      candidates: readonly string[];
    }[];
    unmapped_inputs: readonly string[];
  };
};
