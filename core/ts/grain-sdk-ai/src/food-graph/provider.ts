import type {
  FoodGraphArtifact,
  FoodGraphMealInput,
  FoodGraphModelKey,
  FoodGraphPairingSuggestion,
  FoodGraphResolvedIngredient,
  FoodGraphSimilarMeal,
  FoodGraphSourceRef
} from "./types.js";

export type FoodGraphPairingOptions = {
  model?: FoodGraphModelKey;
  limit?: number;
};

export type FoodGraphSimilarMealOptions = {
  limit?: number;
  model?: FoodGraphModelKey;
};

export class LocalFoodGraphProvider {
  private readonly vocabulary: ReadonlySet<string>;

  constructor(private readonly artifact: FoodGraphArtifact) {
    this.vocabulary = new Set(artifact.vocabulary);
  }

  artifactId(): string {
    return this.artifact.manifest.artifact_id;
  }

  resolveIngredient(input: string): FoodGraphResolvedIngredient {
    const normalized = normalizeIngredientInput(input);
    if (normalized.length === 0) {
      return unmapped(input, normalized, "empty ingredient input");
    }

    const ambiguous = this.artifact.ambiguousAliases.get(normalized);
    if (ambiguous) {
      return {
        input,
        normalized,
        status: "ambiguous",
        method: "ambiguous_alias",
        confidence: 0,
        candidates: ambiguous,
        warning: "Input is intentionally ambiguous and must be confirmed by the app or user."
      };
    }

    const canonicalInput = normalized.replaceAll(" ", "_");
    if (this.vocabulary.has(canonicalInput)) {
      return resolved(input, normalized, canonicalInput, "exact", 1);
    }

    const alias = this.artifact.aliases.get(normalized);
    if (alias && this.vocabulary.has(alias)) {
      return resolved(input, normalized, alias, "alias", 0.96);
    }

    const singular = safeSingularCandidate(canonicalInput);
    if (singular && this.vocabulary.has(singular)) {
      return resolved(input, normalized, singular, "safe_singular", 0.92);
    }

    return unmapped(input, normalized, "No exact, alias, or safe singular match.");
  }

  resolveIngredients(inputs: string | readonly string[]): readonly FoodGraphResolvedIngredient[] {
    const items = typeof inputs === "string" ? splitIngredientText(inputs) : inputs;
    return items.map((item) => this.resolveIngredient(item));
  }

  suggestPairings(
    ingredients: string | readonly string[],
    options: FoodGraphPairingOptions = {}
  ): readonly FoodGraphPairingSuggestion[] {
    const model = options.model ?? "core";
    const limit = boundedLimit(options.limit, 8, 32);
    const resolvedIngredients = this.resolvedCanonicalNames(this.resolveIngredients(ingredients));
    const existing = new Set(resolvedIngredients);
    const modelNeighbors = this.requireNeighbors(model);
    const aggregate = new Map<string, { score: number; via: Set<string> }>();

    for (const canonical of resolvedIngredients) {
      for (const neighbor of modelNeighbors.get(canonical) ?? []) {
        if (existing.has(neighbor.name)) continue;
        const current = aggregate.get(neighbor.name) ?? { score: 0, via: new Set<string>() };
        current.score += neighbor.score;
        current.via.add(canonical);
        aggregate.set(neighbor.name, current);
      }
    }

    return [...aggregate.entries()]
      .map(([name, value]) => ({
        name,
        score: roundScore((value.score / Math.max(1, value.via.size)) + Math.min(0.16, (value.via.size - 1) * 0.08)),
        model,
        via: [...value.via].sort(),
        advisoryOnly: true as const
      }))
      .sort((a, b) => b.score - a.score || a.name.localeCompare(b.name))
      .slice(0, limit);
  }

  similarMeals(
    meal: FoodGraphMealInput,
    history: readonly FoodGraphMealInput[],
    options: FoodGraphSimilarMealOptions = {}
  ): readonly FoodGraphSimilarMeal[] {
    const model = options.model ?? "core";
    const limit = boundedLimit(options.limit, 5, 50);
    const base = new Set(this.resolvedCanonicalNames(this.resolveIngredients(meal.ingredients)));
    if (base.size === 0) return [];

    const baseRelated = this.relatedSet(base, model);
    return history
      .map((candidate) => {
        const candidateSet = new Set(this.resolvedCanonicalNames(this.resolveIngredients(candidate.ingredients)));
        const shared = intersection(base, candidateSet);
        const related = intersection(baseRelated, candidateSet).filter((name) => !shared.includes(name));
        const unionSize = new Set([...base, ...candidateSet]).size;
        const sharedScore = shared.length / Math.max(1, unionSize);
        const relatedScore = related.length / Math.max(1, candidateSet.size) * 0.35;
        return {
          mealId: candidate.mealId,
          label: candidate.label,
          score: roundScore(sharedScore + relatedScore),
          sharedIngredients: shared,
          relatedIngredients: related,
          advisoryOnly: true as const
        };
      })
      .filter((result) => result.score > 0)
      .sort((a, b) => b.score - a.score || (a.label ?? "").localeCompare(b.label ?? ""))
      .slice(0, limit);
  }

  sourceRefFor(resolutions: readonly FoodGraphResolvedIngredient[]): FoodGraphSourceRef {
    return {
      food_graph: {
        artifact_id: this.artifact.manifest.artifact_id,
        advisory_only: true,
        may_change_kcal: false,
        may_change_record_trust: false,
        may_change_nutrition_confidence: false,
        resolved_ingredients: resolutions
          .filter((item) => item.status === "resolved" && item.canonicalName)
          .map((item) => ({
            input: item.input,
            canonical_name: item.canonicalName!,
            method: item.method,
            confidence: item.confidence
          })),
        ambiguous_inputs: resolutions
          .filter((item) => item.status === "ambiguous")
          .map((item) => ({
            input: item.input,
            candidates: item.candidates
          })),
        unmapped_inputs: resolutions
          .filter((item) => item.status === "unmapped")
          .map((item) => item.input)
      }
    };
  }

  private resolvedCanonicalNames(resolutions: readonly FoodGraphResolvedIngredient[]): readonly string[] {
    return [...new Set(
      resolutions
        .filter((item) => item.status === "resolved" && item.canonicalName)
        .map((item) => item.canonicalName!)
    )].sort();
  }

  private relatedSet(base: ReadonlySet<string>, model: FoodGraphModelKey): ReadonlySet<string> {
    const out = new Set<string>();
    const modelNeighbors = this.requireNeighbors(model);
    for (const name of base) {
      for (const neighbor of (modelNeighbors.get(name) ?? []).slice(0, 8)) {
        out.add(neighbor.name);
      }
    }
    return out;
  }

  private requireNeighbors(model: FoodGraphModelKey) {
    const neighbors = this.artifact.neighbors.get(model);
    if (!neighbors) {
      throw new Error(`Food graph artifact is missing ${model} neighbors`);
    }
    return neighbors;
  }
}

export function normalizeIngredientInput(input: string): string {
  return input
    .normalize("NFKC")
    .toLowerCase()
    .replace(/['']/g, "")
    .replace(/[^a-z0-9]+/g, " ")
    .trim()
    .replace(/\s+/g, " ");
}

function splitIngredientText(input: string): readonly string[] {
  return input
    .split(/,|\band\b|\+|;/i)
    .map((item) => item.trim())
    .filter(Boolean);
}

function safeSingularCandidate(canonicalInput: string): string | undefined {
  if (canonicalInput.length < 4) return undefined;
  if (canonicalInput.endsWith("ies")) return `${canonicalInput.slice(0, -3)}y`;
  if (canonicalInput.endsWith("oes")) return canonicalInput.slice(0, -2);
  if (canonicalInput.endsWith("ses")) return canonicalInput.slice(0, -2);
  if (canonicalInput.endsWith("s") && !canonicalInput.endsWith("ss")) return canonicalInput.slice(0, -1);
  return undefined;
}

function resolved(
  input: string,
  normalized: string,
  canonicalName: string,
  method: FoodGraphResolvedIngredient["method"],
  confidence: number
): FoodGraphResolvedIngredient {
  return {
    input,
    normalized,
    status: "resolved",
    method,
    canonicalName,
    confidence,
    candidates: [canonicalName]
  };
}

function unmapped(input: string, normalized: string, warning: string): FoodGraphResolvedIngredient {
  return {
    input,
    normalized,
    status: "unmapped",
    method: "unmapped",
    confidence: 0,
    candidates: [],
    warning
  };
}

function boundedLimit(value: number | undefined, fallback: number, max: number): number {
  if (value === undefined) return fallback;
  if (!Number.isSafeInteger(value) || value < 1) {
    throw new Error("Food graph limit must be a positive safe integer");
  }
  return Math.min(value, max);
}

function intersection(a: ReadonlySet<string>, b: ReadonlySet<string>): string[] {
  return [...a].filter((item) => b.has(item)).sort();
}

function roundScore(value: number): number {
  return Math.round(value * 1_000_000) / 1_000_000;
}
