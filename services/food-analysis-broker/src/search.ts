import type {
  FoodSearchMatchType,
  FoodSearchPer100gNutrition,
  FoodSearchProvider,
  FoodSearchRequest,
  FoodSearchResult,
  FoodSearchTrustLabel
} from "./types.js";

type FixtureFood = {
  fixtureId: string;
  primaryLabel: string;
  genericLabel: string;
  brandLabel: string | null;
  category: string;
  aliases: string[];
  barcode?: string;
  trustLabel: FoodSearchTrustLabel;
  servingSizeG: number | null;
  servingLabel: string | null;
  per100g: FoodSearchPer100gNutrition;
};

type ScoredFixture = {
  fixture: FixtureFood;
  matchType: FoodSearchMatchType;
  score: number;
  providerId: string;
};

const DEFAULT_LIMIT = 8;
const MAX_LIMIT = 20;

const FIXTURES: FixtureFood[] = [
  {
    fixtureId: "fixture-fuji-apple",
    primaryLabel: "Fuji apple",
    genericLabel: "apple",
    brandLabel: null,
    category: "common_food",
    aliases: ["apple", "fuji apple", "raw apple", "common apple"],
    trustLabel: "fixture_verified",
    servingSizeG: 182,
    servingLabel: "1 medium apple (182 g)",
    per100g: { kcal: 63, protein_g: 0.2, carbohydrate_g: 15.2, fat_g: 0.2, fiber_g: 2.1 }
  },
  {
    fixtureId: "fixture-banana",
    primaryLabel: "Banana",
    genericLabel: "banana",
    brandLabel: null,
    category: "common_food",
    aliases: ["banana", "raw banana", "common banana"],
    trustLabel: "fixture_verified",
    servingSizeG: 118,
    servingLabel: "1 medium banana (118 g)",
    per100g: { kcal: 89, protein_g: 1.1, carbohydrate_g: 22.8, fat_g: 0.3, fiber_g: 2.6 }
  },
  {
    fixtureId: "fixture-cooked-oatmeal",
    primaryLabel: "Cooked oatmeal",
    genericLabel: "oatmeal",
    brandLabel: null,
    category: "common_food",
    aliases: ["oatmeal", "cooked oatmeal", "porridge", "oats"],
    trustLabel: "fixture_verified",
    servingSizeG: 234,
    servingLabel: "1 cup cooked (234 g)",
    per100g: { kcal: 71, protein_g: 2.5, carbohydrate_g: 12, fat_g: 1.5, fiber_g: 1.7 }
  },
  {
    fixtureId: "fixture-white-rice",
    primaryLabel: "Cooked white rice",
    genericLabel: "white rice",
    brandLabel: null,
    category: "common_food",
    aliases: ["rice", "white rice", "cooked white rice", "plain rice"],
    trustLabel: "fixture_verified",
    servingSizeG: 158,
    servingLabel: "1 cup cooked (158 g)",
    per100g: { kcal: 130, protein_g: 2.7, carbohydrate_g: 28.2, fat_g: 0.3, fiber_g: 0.4 }
  },
  {
    fixtureId: "fixture-casein-protein",
    primaryLabel: "Casein protein powder",
    genericLabel: "casein protein powder",
    brandLabel: null,
    category: "supplement",
    aliases: ["casein", "casein protein", "casein protein powder", "micellar casein"],
    trustLabel: "fixture_verified",
    servingSizeG: 30,
    servingLabel: "1 scoop (30 g)",
    per100g: { kcal: 367, protein_g: 80, carbohydrate_g: 7, fat_g: 2 }
  },
  {
    fixtureId: "fixture-kombucha-bottle",
    primaryLabel: "Ginger lemon kombucha",
    genericLabel: "kombucha",
    brandLabel: "Grain Fixture Kitchen",
    category: "packaged_beverage",
    aliases: ["kombucha", "ginger lemon kombucha", "kombucha bottle", "packaged kombucha"],
    barcode: "012345678905",
    trustLabel: "fixture_verified",
    servingSizeG: 473,
    servingLabel: "1 bottle (473 ml)",
    per100g: { kcal: 17, protein_g: 0, carbohydrate_g: 4.2, fat_g: 0 }
  }
];

export class FixtureFoodSearchProvider implements FoodSearchProvider {
  async search(request: FoodSearchRequest): Promise<FoodSearchResult[]> {
    const limit = clampLimit(request.limit);
    const barcode = normalizeBarcode(request.barcode);
    const query = request.query?.trim() ?? "";
    const barcodeLikeQuery = normalizeBarcode(query);

    const scored = FIXTURES
      .flatMap((fixture) => scoreFixture(fixture, query, barcode || barcodeLikeQuery))
      .sort((left, right) => right.score - left.score || left.fixture.primaryLabel.localeCompare(right.fixture.primaryLabel))
      .slice(0, limit);

    return scored.map(toSearchResult);
  }
}

function scoreFixture(fixture: FixtureFood, query: string, barcode: string): ScoredFixture[] {
  if (barcode && fixture.barcode === barcode) {
    return [{ fixture, matchType: "barcode", score: 1, providerId: barcode }];
  }

  const queryTerms = tokenize(query);
  if (queryTerms.length === 0) return [];

  let score = 0;
  for (const alias of [fixture.primaryLabel, fixture.genericLabel, ...fixture.aliases]) {
    const aliasTerms = tokenize(alias);
    const matchedTerms = queryTerms.filter((term) => aliasTerms.includes(term)).length;
    if (matchedTerms === 0) continue;
    const exactBoost = alias.toLowerCase() === query.trim().toLowerCase() ? 0.28 : 0;
    score = Math.max(score, matchedTerms / Math.max(aliasTerms.length, queryTerms.length) + exactBoost);
  }

  if (score === 0) return [];
  return [{ fixture, matchType: "name", score: roundScore(Math.min(0.98, score)), providerId: fixture.fixtureId }];
}

function toSearchResult(scored: ScoredFixture): FoodSearchResult {
  const { fixture, matchType, score, providerId } = scored;
  const trustLabel = matchType === "barcode" ? "barcode_fixture" : fixture.trustLabel;
  return {
    result_id: `food-search:${fixture.fixtureId}`,
    primary_label: fixture.primaryLabel,
    generic_label: fixture.genericLabel,
    brand_label: fixture.brandLabel,
    category: fixture.category,
    source_label: "deterministic_fixture",
    trust_label: trustLabel,
    match: {
      type: matchType,
      score
    },
    serving: {
      basis: "per_100g",
      serving_size_g: fixture.servingSizeG,
      serving_label: fixture.servingLabel
    },
    nutrition: {
      per_100g: fixture.per100g
    },
    provider_evidence: [
      {
        provider: "deterministic_fixture",
        provider_id: providerId,
        matched_name: fixture.primaryLabel,
        match_type: matchType,
        source_label: "curated_fixture",
        trust_label: trustLabel
      }
    ],
    user_confirmation_required: true
  };
}

function clampLimit(value: number | undefined): number {
  if (value === undefined) return DEFAULT_LIMIT;
  return Math.min(MAX_LIMIT, Math.max(1, value));
}

function normalizeBarcode(value: string | undefined): string {
  if (!value) return "";
  const normalized = value.replace(/[\s-]+/gu, "");
  return /^\d{8,14}$/u.test(normalized) ? normalized : "";
}

function tokenize(value: string): string[] {
  return value.toLowerCase().split(/[^a-z0-9]+/u).filter((term) => term.length > 1);
}

function roundScore(value: number): number {
  return Math.round(value * 100) / 100;
}
