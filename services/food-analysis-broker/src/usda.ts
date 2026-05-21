import { BrokerError } from "./errors.js";
import type { Per100gNutrients } from "./nutrition.js";

export type NutritionMatch = {
  provider: "deterministic_fixture" | "usda_fdc";
  providerID: string;
  matchedName: string;
  servingBasis: "per_100g";
  per100g: Per100gNutrients;
};

export type NutritionProvider = {
  lookup(query: string): Promise<NutritionMatch | null>;
};

const FIXTURES: NutritionMatch[] = [
  {
    provider: "deterministic_fixture",
    providerID: "1750340",
    matchedName: "Apples, raw, fuji, with skin",
    servingBasis: "per_100g",
    per100g: { kcal: 63, proteinGrams: 0.2, carbohydrateGrams: 15.2, fatGrams: 0.2, fiberGrams: 2.1 }
  },
  {
    provider: "deterministic_fixture",
    providerID: "fixture-risotto-mushroom-components",
    matchedName: "Mushroom risotto, reconstructed from visible components",
    servingBasis: "per_100g",
    per100g: { kcal: 189, proteinGrams: 5.4, carbohydrateGrams: 20.6, fatGrams: 9.4, fiberGrams: 0.4 }
  }
];

export class FixtureNutritionProvider implements NutritionProvider {
  async lookup(query: string): Promise<NutritionMatch | null> {
    const terms = tokenize(query);
    if (terms.length === 0) return null;

    const scored = FIXTURES
      .map((fixture) => ({ fixture, score: scoreFixture(fixture, terms) }))
      .filter((entry) => entry.score > 0)
      .sort((left, right) => right.score - left.score);
    return scored[0]?.fixture ?? null;
  }
}

export class MissingNutritionProvider implements NutritionProvider {
  async lookup(): Promise<NutritionMatch | null> {
    return null;
  }
}

export class LiveUsdaFoodDataCentralProvider implements NutritionProvider {
  private readonly apiKey: string;
  private readonly fetchFn: typeof fetch;
  private readonly baseUrl: string;

  constructor(options: { apiKey: string; fetchFn?: typeof fetch; baseUrl?: string }) {
    this.apiKey = options.apiKey;
    this.fetchFn = options.fetchFn ?? fetch;
    this.baseUrl = options.baseUrl ?? "https://api.nal.usda.gov/fdc/v1";
  }

  async lookup(query: string): Promise<NutritionMatch | null> {
    const trimmed = query.trim();
    if (!trimmed) return null;

    const url = `${this.baseUrl}/foods/search?api_key=${encodeURIComponent(this.apiKey)}`;
    const response = await this.fetchFn(url, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        query: trimmed,
        pageSize: 5,
        dataType: ["Foundation", "SR Legacy", "Survey (FNDDS)", "Branded"]
      })
    });

    if (!response.ok) {
      throw new BrokerError(502, "UPSTREAM_ERROR", "USDA FoodData Central lookup failed", {
        upstream_status: response.status
      });
    }

    const payload = await response.json() as unknown;
    if (!isRecord(payload) || !Array.isArray(payload.foods)) return null;

    for (const food of payload.foods) {
      const match = parseFdcSearchFood(food);
      if (match) return match;
    }
    return null;
  }
}

export function nutritionProviderFromEnv(env: NodeJS.ProcessEnv = process.env): NutritionProvider {
  const apiKey = env.FDC_API_KEY || env.USDA_API_KEY || env.FOODDATA_CENTRAL_API_KEY;
  if (apiKey && apiKey.trim().length > 0) {
    return new LiveUsdaFoodDataCentralProvider({ apiKey });
  }
  if (env.FOOD_NUTRITION_FIXTURES === "1") {
    return new FixtureNutritionProvider();
  }
  return new MissingNutritionProvider();
}

function parseFdcSearchFood(value: unknown): NutritionMatch | null {
  if (!isRecord(value)) return null;
  const fdcId = value.fdcId;
  const description = value.description;
  const nutrients = value.foodNutrients;
  if ((typeof fdcId !== "number" && typeof fdcId !== "string") || typeof description !== "string") return null;
  if (!Array.isArray(nutrients)) return null;

  const per100g = {
    kcal: findNutrient(nutrients, ["Energy"], "KCAL"),
    proteinGrams: findNutrient(nutrients, ["Protein"], "G"),
    carbohydrateGrams: findNutrient(nutrients, ["Carbohydrate, by difference", "Carbohydrate"], "G"),
    fatGrams: findNutrient(nutrients, ["Total lipid (fat)", "Total Fat"], "G"),
    fiberGrams: findNutrient(nutrients, ["Fiber, total dietary", "Fiber"], "G")
  };

  if (per100g.kcal === undefined || per100g.proteinGrams === undefined ||
      per100g.carbohydrateGrams === undefined || per100g.fatGrams === undefined) {
    return null;
  }

  return {
    provider: "usda_fdc",
    providerID: String(fdcId),
    matchedName: description,
    servingBasis: "per_100g",
    per100g: {
      kcal: per100g.kcal,
      proteinGrams: per100g.proteinGrams,
      carbohydrateGrams: per100g.carbohydrateGrams,
      fatGrams: per100g.fatGrams,
      ...(per100g.fiberGrams === undefined ? {} : { fiberGrams: per100g.fiberGrams })
    }
  };
}

function findNutrient(values: unknown[], names: string[], unitName: string): number | undefined {
  for (const value of values) {
    if (!isRecord(value)) continue;
    const nutrientName = String(value.nutrientName ?? value.name ?? "");
    const unit = String(value.unitName ?? "");
    const amount = value.value ?? value.amount;
    if (typeof amount !== "number" || !Number.isFinite(amount) || amount < 0) continue;
    if (unit.toUpperCase() !== unitName) continue;
    if (names.some((name) => nutrientName.toLowerCase().includes(name.toLowerCase()))) {
      return amount;
    }
  }
  return undefined;
}

function scoreFixture(match: NutritionMatch, queryTerms: string[]): number {
  const matchTerms = tokenize(match.matchedName);
  return queryTerms.filter((term) => matchTerms.includes(term)).length;
}

function tokenize(value: string): string[] {
  return value.toLowerCase().split(/[^a-z0-9]+/u).filter((term) => term.length > 1);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
