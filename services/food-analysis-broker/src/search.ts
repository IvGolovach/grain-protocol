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

type FetchFn = (url: string | URL, init?: RequestInit) => Promise<Response>;

const DEFAULT_LIMIT = 8;
const MAX_LIMIT = 20;
const DEFAULT_TIMEOUT_MS = 2500;
const DEFAULT_OPEN_FOOD_FACTS_USER_AGENT = "MealMark/0.1 (https://github.com/IvGolovach/grain-protocol)";
const OPEN_FOOD_FACTS_FIELDS = [
  "code",
  "product_name",
  "generic_name",
  "brands",
  "categories_tags",
  "serving_quantity",
  "serving_size",
  "nutriments"
].join(",");

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

export class CompositeFoodSearchProvider implements FoodSearchProvider {
  constructor(private readonly providers: FoodSearchProvider[]) {}

  async search(request: FoodSearchRequest): Promise<FoodSearchResult[]> {
    const limit = clampLimit(request.limit);
    const seen = new Set<string>();
    const results: FoodSearchResult[] = [];
    for (const provider of this.providers) {
      let providerResults: FoodSearchResult[];
      try {
        providerResults = await provider.search(request);
      } catch {
        continue;
      }
      for (const result of providerResults) {
        if (seen.has(result.result_id)) continue;
        seen.add(result.result_id);
        results.push(result);
        if (results.length >= limit) return results;
      }
    }
    return results;
  }
}

export class OpenFoodFactsSearchProvider implements FoodSearchProvider {
  private readonly baseUrl: string;
  private readonly userAgent: string;
  private readonly fetchFn: FetchFn;
  private readonly timeoutMs: number;

  constructor(options: {
    baseUrl?: string;
    userAgent: string;
    fetchFn?: FetchFn;
    timeoutMs?: number;
  }) {
    this.baseUrl = options.baseUrl ?? "https://world.openfoodfacts.org";
    this.userAgent = options.userAgent;
    this.fetchFn = options.fetchFn ?? fetch;
    this.timeoutMs = options.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  }

  async search(request: FoodSearchRequest): Promise<FoodSearchResult[]> {
    const barcodes = barcodeLookupCandidates(request.barcode ?? request.query);
    for (const barcode of barcodes) {
      const url = new URL(`/api/v2/product/${barcode}.json`, this.baseUrl);
      url.searchParams.set("fields", OPEN_FOOD_FACTS_FIELDS);
      const response = await fetchWithTimeout(this.fetchFn, url, {
        headers: {
          "Accept": "application/json",
          "User-Agent": this.userAgent
        }
      }, this.timeoutMs);
      if (!response.ok) continue;

      const body = await response.json() as OpenFoodFactsResponse;
      if (body.status !== 1 || !body.product) continue;
      const result = openFoodFactsResult(barcode, body.product);
      if (result) return [result];
    }
    return [];
  }
}

export class UsdaBrandedFoodSearchProvider implements FoodSearchProvider {
  private readonly apiKey: string;
  private readonly baseUrl: string;
  private readonly fetchFn: FetchFn;
  private readonly timeoutMs: number;

  constructor(options: {
    apiKey: string;
    baseUrl?: string;
    fetchFn?: FetchFn;
    timeoutMs?: number;
  }) {
    this.apiKey = options.apiKey;
    this.baseUrl = options.baseUrl ?? "https://api.nal.usda.gov/fdc/v1";
    this.fetchFn = options.fetchFn ?? fetch;
    this.timeoutMs = options.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  }

  async search(request: FoodSearchRequest): Promise<FoodSearchResult[]> {
    const barcodes = barcodeLookupCandidates(request.barcode ?? request.query);
    if (barcodes.length === 0) return [];

    const url = new URL("foods/search", ensureTrailingSlash(this.baseUrl));
    url.searchParams.set("api_key", this.apiKey);
    for (const barcode of barcodes) {
      const response = await fetchWithTimeout(this.fetchFn, url, {
        method: "POST",
        headers: {
          "accept": "application/json",
          "content-type": "application/json"
        },
        body: JSON.stringify({
          query: barcode,
          dataType: ["Branded"],
          pageSize: 25
        })
      }, this.timeoutMs);
      if (!response.ok) continue;

      const body = await response.json() as UsdaSearchResponse;
      const foods = Array.isArray(body.foods) ? body.foods : [];
      const exact = foods.find((food) => haveSharedBarcodeCandidate(barcodes, barcodeLookupCandidates(food.gtinUpc)));
      if (!exact) continue;
      const result = usdaBrandedResult(barcode, exact);
      if (result) return [result];
    }
    return [];
  }
}

export class UsdaGenericFoodSearchProvider implements FoodSearchProvider {
  private readonly apiKey: string;
  private readonly baseUrl: string;
  private readonly fetchFn: FetchFn;
  private readonly timeoutMs: number;

  constructor(options: {
    apiKey: string;
    baseUrl?: string;
    fetchFn?: FetchFn;
    timeoutMs?: number;
  }) {
    this.apiKey = options.apiKey;
    this.baseUrl = options.baseUrl ?? "https://api.nal.usda.gov/fdc/v1";
    this.fetchFn = options.fetchFn ?? fetch;
    this.timeoutMs = options.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  }

  async search(request: FoodSearchRequest): Promise<FoodSearchResult[]> {
    const query = cleanText(request.query);
    if (!query || normalizeBarcode(query)) return [];

    const url = new URL("foods/search", ensureTrailingSlash(this.baseUrl));
    url.searchParams.set("api_key", this.apiKey);
    const response = await fetchWithTimeout(this.fetchFn, url, {
      method: "POST",
      headers: {
        "accept": "application/json",
        "content-type": "application/json"
      },
      body: JSON.stringify({
        query,
        dataType: ["Foundation", "SR Legacy", "Survey (FNDDS)"],
        pageSize: clampLimit(request.limit)
      })
    }, this.timeoutMs);
    if (!response.ok) return [];

    const body = await response.json() as UsdaSearchResponse;
    const foods = Array.isArray(body.foods) ? body.foods : [];
    return foods
      .map((food) => usdaGenericResult(query, food))
      .filter((result): result is FoodSearchResult => result !== null)
      .slice(0, clampLimit(request.limit));
  }
}

export function foodSearchProviderFromEnv(env: NodeJS.ProcessEnv = process.env): FoodSearchProvider {
  const providers: FoodSearchProvider[] = [];
  const timeoutMs = parsePositiveInteger(env.FOOD_SEARCH_TIMEOUT_MS) ?? DEFAULT_TIMEOUT_MS;
  if (env.FOOD_SEARCH_LIVE !== "0") {
    providers.push(new OpenFoodFactsSearchProvider({
      baseUrl: env.OPEN_FOOD_FACTS_BASE_URL,
      userAgent: cleanText(env.OPEN_FOOD_FACTS_USER_AGENT) ?? DEFAULT_OPEN_FOOD_FACTS_USER_AGENT,
      timeoutMs
    }));

    const apiKey = foodDataCentralAPIKey(env);
    if (apiKey) {
      providers.push(new UsdaGenericFoodSearchProvider({
        apiKey,
        baseUrl: env.USDA_FDC_BASE_URL,
        timeoutMs
      }));
      providers.push(new UsdaBrandedFoodSearchProvider({
        apiKey,
        baseUrl: env.USDA_FDC_BASE_URL,
        timeoutMs
      }));
    }
  }
  providers.push(new FixtureFoodSearchProvider());
  return providers.length === 1 ? providers[0] : new CompositeFoodSearchProvider(providers);
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

type OpenFoodFactsResponse = {
  status?: number;
  product?: {
    code?: string;
    product_name?: string;
    generic_name?: string;
    brands?: string;
    categories_tags?: unknown;
    serving_quantity?: unknown;
    serving_size?: string;
    nutriments?: Record<string, unknown>;
  };
};

function openFoodFactsResult(barcode: string, product: NonNullable<OpenFoodFactsResponse["product"]>): FoodSearchResult | null {
  const productName = cleanText(product.product_name) ?? cleanText(product.generic_name);
  const nutriments = product.nutriments ?? {};
  const servingSizeG = numeric(product.serving_quantity) ?? servingGramsFromLabel(product.serving_size);
  const kcal = openFoodFactsKcalPer100g(nutriments, servingSizeG);
  if (!productName || kcal === null) return null;

  const category = openFoodFactsCategory(product.categories_tags);
  return {
    result_id: `food-search:open-food-facts:${barcode}`,
    primary_label: productName,
    generic_label: cleanText(product.generic_name) ?? productName.toLowerCase(),
    brand_label: cleanText(product.brands),
    category,
    source_label: "open_food_facts",
    trust_label: "barcode_provider",
    match: {
      type: "barcode",
      score: 1
    },
    serving: {
      basis: "per_100g",
      serving_size_g: servingSizeG,
      serving_label: cleanText(product.serving_size)
    },
    nutrition: {
      per_100g: {
        kcal,
        protein_g: openFoodFactsNutrientPer100g(nutriments, ["proteins", "protein"], servingSizeG) ?? 0,
        carbohydrate_g: openFoodFactsNutrientPer100g(nutriments, ["carbohydrates", "carbohydrate"], servingSizeG) ?? 0,
        fat_g: openFoodFactsNutrientPer100g(nutriments, ["fat"], servingSizeG) ?? 0,
        fiber_g: openFoodFactsNutrientPer100g(nutriments, ["fiber"], servingSizeG) ?? undefined
      }
    },
    provider_evidence: [
      {
        provider: "open_food_facts",
        provider_id: product.code ?? barcode,
        matched_name: productName,
        match_type: "barcode",
        source_label: "open_food_facts_product",
        trust_label: "barcode_provider"
      }
    ],
    user_confirmation_required: true
  };
}

type UsdaSearchResponse = {
  foods?: UsdaSearchFood[];
};

type UsdaSearchFood = {
  fdcId?: number;
  description?: string;
  brandName?: string;
  brandOwner?: string;
  gtinUpc?: string;
  foodCategory?: string;
  servingSize?: unknown;
  servingSizeUnit?: string;
  foodNutrients?: Array<{
    nutrientName?: string;
    nutrientNumber?: string;
    unitName?: string;
    value?: unknown;
  }>;
};

function usdaBrandedResult(barcode: string, food: UsdaSearchFood): FoodSearchResult | null {
  const label = cleanText(food.description);
  const fdcID = food.fdcId?.toString();
  const kcal = usdaNutrient(food, "208", "energy");
  if (!label || !fdcID || kcal === null) return null;

  const servingSizeG = numeric(food.servingSize);
  const servingLabel = servingSizeG === null ? null : `${servingSizeG} ${food.servingSizeUnit ?? "g"}`;
  return {
    result_id: `food-search:usda-fdc:${fdcID}`,
    primary_label: label,
    generic_label: label.toLowerCase(),
    brand_label: cleanText(food.brandName) ?? cleanText(food.brandOwner),
    category: cleanText(food.foodCategory) ?? "branded_food",
    source_label: "usda_fdc",
    trust_label: "barcode_provider",
    match: {
      type: "barcode",
      score: normalizeBarcode(food.gtinUpc) === barcode ? 1 : 0.92
    },
    serving: {
      basis: "per_100g",
      serving_size_g: servingSizeG,
      serving_label: servingLabel
    },
    nutrition: {
      per_100g: {
        kcal,
        protein_g: usdaNutrient(food, "203", "protein") ?? 0,
        carbohydrate_g: usdaNutrient(food, "205", "carbohydrate") ?? 0,
        fat_g: usdaNutrient(food, "204", "lipid") ?? 0,
        fiber_g: usdaNutrient(food, "291", "fiber") ?? undefined
      }
    },
    provider_evidence: [
      {
        provider: "usda_fdc",
        provider_id: fdcID,
        matched_name: label,
        match_type: "barcode",
        source_label: "usda_branded_food",
        trust_label: "barcode_provider"
      }
    ],
    user_confirmation_required: true
  };
}

function usdaGenericResult(query: string, food: UsdaSearchFood): FoodSearchResult | null {
  const label = cleanText(food.description);
  const fdcID = food.fdcId?.toString();
  const kcal = usdaNutrient(food, "208", "energy");
  if (!label || !fdcID || kcal === null) return null;

  return {
    result_id: `food-search:usda-fdc:${fdcID}`,
    primary_label: titleCaseFoodLabel(label),
    generic_label: label.toLowerCase(),
    brand_label: null,
    category: cleanText(food.foodCategory) ?? "common_food",
    source_label: "usda_fdc",
    trust_label: "provider_estimate",
    match: {
      type: "name",
      score: scoreUsdaGenericMatch(query, label)
    },
    serving: {
      basis: "per_100g",
      serving_size_g: 100,
      serving_label: "100 g"
    },
    nutrition: {
      per_100g: {
        kcal,
        protein_g: usdaNutrient(food, "203", "protein") ?? 0,
        carbohydrate_g: usdaNutrient(food, "205", "carbohydrate") ?? 0,
        fat_g: usdaNutrient(food, "204", "lipid") ?? 0,
        fiber_g: usdaNutrient(food, "291", "fiber") ?? undefined
      }
    },
    provider_evidence: [
      {
        provider: "usda_fdc",
        provider_id: fdcID,
        matched_name: label,
        match_type: "name",
        source_label: "usda_generic_food",
        trust_label: "provider_estimate"
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
  const normalized = value.replace(/[^\d]/gu, "");
  return /^\d{8,14}$/u.test(normalized) ? normalized : "";
}

function barcodeLookupCandidates(value: string | undefined): string[] {
  const barcode = normalizeBarcode(value);
  if (!barcode) return [];
  const candidates: string[] = [];
  addBarcodeCandidate(candidates, barcode);
  const expandedUpcE = expandUpcE(barcode);
  if (expandedUpcE) {
    addBarcodeCandidate(candidates, expandedUpcE);
  }
  return Array.from(new Set(candidates.filter((candidate) => /^\d{8,14}$/u.test(candidate))));
}

function addBarcodeCandidate(candidates: string[], barcode: string): void {
  candidates.push(barcode);
  if (barcode.length === 13 && barcode.startsWith("0")) {
    candidates.push(barcode.slice(1));
  }
  if (barcode.length === 12) {
    candidates.push(`0${barcode}`);
    candidates.push(`00${barcode}`);
  }
  if (barcode.length === 14 && barcode.startsWith("0")) {
    candidates.push(barcode.replace(/^0+/u, ""));
  }
}

function expandUpcE(value: string): string | null {
  if (!/^[01]\d{7}$/u.test(value)) return null;
  const numberSystem = value[0];
  const x1 = value[1];
  const x2 = value[2];
  const x3 = value[3];
  const x4 = value[4];
  const x5 = value[5];
  const x6 = value[6];
  const checkDigit = value[7];
  let body: string;
  if (["0", "1", "2"].includes(x6)) {
    body = `${numberSystem}${x1}${x2}${x6}0000${x3}${x4}${x5}`;
  } else if (x6 === "3") {
    body = `${numberSystem}${x1}${x2}${x3}00000${x4}${x5}`;
  } else if (x6 === "4") {
    body = `${numberSystem}${x1}${x2}${x3}${x4}00000${x5}`;
  } else {
    body = `${numberSystem}${x1}${x2}${x3}${x4}${x5}0000${x6}`;
  }
  const expanded = `${body}${checkDigit}`;
  return isValidGtin(expanded) ? expanded : null;
}

function isValidGtin(value: string): boolean {
  if (!/^\d{8}$|^\d{12}$|^\d{13}$|^\d{14}$/u.test(value)) return false;
  const digits = [...value].map((digit) => Number(digit));
  const checkDigit = digits.pop();
  if (checkDigit === undefined) return false;
  let sum = 0;
  for (let index = digits.length - 1, weight = 3; index >= 0; index -= 1, weight = weight === 3 ? 1 : 3) {
    sum += digits[index] * weight;
  }
  return (10 - (sum % 10)) % 10 === checkDigit;
}

function haveSharedBarcodeCandidate(left: string[], right: string[]): boolean {
  const rightSet = new Set(right);
  return left.some((candidate) => rightSet.has(candidate));
}

function cleanText(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function titleCaseFoodLabel(value: string): string {
  return value
    .toLowerCase()
    .split(/(\s+|,\s*)/u)
    .map((part) => /^[a-z]/u.test(part) ? part[0].toUpperCase() + part.slice(1) : part)
    .join("")
    .replace(/\s*,\s*/gu, ", ");
}

function scoreUsdaGenericMatch(query: string, label: string): number {
  const queryTerms = tokenize(query);
  const labelTerms = tokenize(label);
  if (queryTerms.length === 0 || labelTerms.length === 0) return 0.7;
  const matched = queryTerms.filter((term) => labelTerms.includes(term)).length;
  const base = matched / queryTerms.length;
  const exactBoost = label.toLowerCase() === query.trim().toLowerCase() ? 0.15 : 0;
  return roundScore(Math.max(0.7, Math.min(0.98, base + exactBoost)));
}

function numeric(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value.replace(",", ".").trim());
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function openFoodFactsKcalPer100g(nutriments: Record<string, unknown>, servingSizeG: number | null): number | null {
  const kcal = numeric(nutriments["energy-kcal_100g"] ?? nutriments["energy_kcal_100g"]);
  if (kcal !== null) return roundNutrition(kcal);
  const kilojoules = numeric(nutriments["energy-kj_100g"] ?? nutriments["energy_100g"]);
  if (kilojoules !== null) return roundNutrition(kilojoules / 4.184);
  const kcalServing = numeric(nutriments["energy-kcal_serving"] ?? nutriments["energy_kcal_serving"]);
  if (kcalServing !== null && servingSizeG !== null && servingSizeG > 0) {
    return roundNutrition((kcalServing * 100) / servingSizeG);
  }
  const kilojoulesServing = numeric(nutriments["energy-kj_serving"] ?? nutriments["energy_serving"]);
  if (kilojoulesServing !== null && servingSizeG !== null && servingSizeG > 0) {
    return roundNutrition((kilojoulesServing / 4.184 * 100) / servingSizeG);
  }
  return null;
}

function openFoodFactsNutrientPer100g(
  nutriments: Record<string, unknown>,
  names: string[],
  servingSizeG: number | null
): number | null {
  for (const name of names) {
    const direct = numeric(nutriments[`${name}_100g`]);
    if (direct !== null) return roundNutrition(direct);
  }
  if (servingSizeG === null || servingSizeG <= 0) return null;
  for (const name of names) {
    const serving = numeric(nutriments[`${name}_serving`]);
    if (serving !== null) return roundNutrition((serving * 100) / servingSizeG);
  }
  return null;
}

function roundNutrition(value: number): number {
  return Math.round(value * 10) / 10;
}

function servingGramsFromLabel(value: string | undefined): number | null {
  if (!value) return null;
  const match = value.match(/(\d+(?:[.,]\d+)?)\s*(g|ml)\b/iu);
  return match ? numeric(match[1]) : null;
}

function openFoodFactsCategory(value: unknown): string {
  if (!Array.isArray(value)) return "packaged_food";
  const last = value.map((item) => cleanText(item)).filter((item): item is string => item !== null).at(-1);
  return last?.replace(/^[a-z]{2}:/u, "").replace(/-/gu, "_") ?? "packaged_food";
}

function usdaNutrient(food: UsdaSearchFood, nutrientNumber: string, nameNeedle: string): number | null {
  for (const nutrient of food.foodNutrients ?? []) {
    const numberMatch = nutrient.nutrientNumber === nutrientNumber;
    const nameMatch = nutrient.nutrientName?.toLowerCase().includes(nameNeedle) ?? false;
    if (numberMatch || nameMatch) {
      const value = numeric(nutrient.value);
      if (value !== null) return value;
    }
  }
  return null;
}

function foodDataCentralAPIKey(env: NodeJS.ProcessEnv): string | null {
  return cleanText(env.FDC_API_KEY) ?? cleanText(env.USDA_API_KEY) ?? cleanText(env.FOODDATA_CENTRAL_API_KEY);
}

function parsePositiveInteger(value: string | undefined): number | null {
  if (!value) return null;
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
}

function ensureTrailingSlash(value: string): string {
  return value.endsWith("/") ? value : `${value}/`;
}

async function fetchWithTimeout(fetchFn: FetchFn, url: URL, init: RequestInit, timeoutMs: number): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetchFn(url, {
      ...init,
      signal: controller.signal
    });
  } finally {
    clearTimeout(timeout);
  }
}

function tokenize(value: string): string[] {
  return value.toLowerCase().split(/[^a-z0-9]+/u).filter((term) => term.length > 1);
}

function roundScore(value: number): number {
  return Math.round(value * 100) / 100;
}
