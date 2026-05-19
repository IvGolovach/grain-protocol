import { readFile } from "node:fs/promises";

export const USDA_FDC_PROVIDER = "usda_fdc";

export const LookupIntent = Object.freeze({
  BARCODE_BRANDED: "barcode_branded",
  SIMPLE_GENERIC: "simple_generic",
  PREPARED_FNDDS: "prepared_fndds",
  MIXED_COMPONENT_RECONSTRUCTION: "mixed_component_reconstruction",
});

export class FixtureBackedUsdaFoodDataCentralProvider {
  constructor({ foods = [] } = {}) {
    this.foods = foods.map((food) => normalizeFixtureFood(food));
  }

  static async fromFixture(path) {
    const raw = await readFile(path, "utf8");
    const parsed = JSON.parse(raw);
    return new FixtureBackedUsdaFoodDataCentralProvider({ foods: parsed.foods ?? [] });
  }

  async lookup(request) {
    const intent = request.intent;
    const candidates = this.foods
      .filter((food) => supportsIntent(food, intent))
      .filter((food) => matchesRequest(food, request))
      .sort((left, right) => scoreFood(right, request) - scoreFood(left, request));

    return candidates[0] ?? null;
  }
}

export class UsdaFoodDataCentralProvider {
  constructor({ apiKey, fetchImpl = globalThis.fetch, baseUrl = "https://api.nal.usda.gov/fdc/v1" } = {}) {
    if (!apiKey) {
      throw new Error("USDA FoodData Central provider requires an apiKey");
    }
    if (typeof fetchImpl !== "function") {
      throw new TypeError("USDA FoodData Central provider requires a fetch implementation");
    }
    this.apiKey = apiKey;
    this.fetchImpl = fetchImpl;
    this.baseUrl = baseUrl;
  }

  async lookup() {
    throw new Error("Live USDA FoodData Central lookup is intentionally not used by default tests");
  }
}

function normalizeFixtureFood(food) {
  return {
    provider: USDA_FDC_PROVIDER,
    fdcId: String(food.fdcId),
    description: food.description,
    dataType: food.dataType,
    barcode: food.barcode ?? null,
    aliases: food.aliases ?? [],
    per100g: food.per100g,
    servingBasis: food.servingBasis ?? "per_100g",
    components: food.components ?? null,
  };
}

function supportsIntent(food, intent) {
  switch (intent) {
    case LookupIntent.BARCODE_BRANDED:
      return food.dataType === "Branded" && Boolean(food.barcode);
    case LookupIntent.SIMPLE_GENERIC:
      return ["Foundation", "SR Legacy", "Survey (FNDDS)"].includes(food.dataType) && !food.components;
    case LookupIntent.PREPARED_FNDDS:
      return food.dataType === "Survey (FNDDS)" && !food.components;
    case LookupIntent.MIXED_COMPONENT_RECONSTRUCTION:
      return Array.isArray(food.components) && food.components.length > 0;
    default:
      return false;
  }
}

function matchesRequest(food, request) {
  if (request.intent === LookupIntent.BARCODE_BRANDED) {
    return request.barcode && food.barcode === request.barcode;
  }

  const queryTerms = tokenize([request.name, request.genericLabel, request.preparedLabel].filter(Boolean).join(" "));
  if (queryTerms.length === 0) {
    return false;
  }

  const foodTerms = tokenize([food.description, ...food.aliases].join(" "));
  const exactAlias = [food.description, ...food.aliases].some(
    (value) => value.toLowerCase() === String(request.name ?? "").toLowerCase(),
  );

  if (
    request.intent === LookupIntent.SIMPLE_GENERIC ||
    request.intent === LookupIntent.PREPARED_FNDDS
  ) {
    return exactAlias || queryTerms.every((term) => foodTerms.includes(term));
  }

  return exactAlias || queryTerms.some((term) => foodTerms.includes(term));
}

function scoreFood(food, request) {
  if (request.barcode && food.barcode === request.barcode) {
    return 1000;
  }

  const queryTerms = tokenize([request.name, request.genericLabel, request.preparedLabel].filter(Boolean).join(" "));
  const foodTerms = tokenize([food.description, ...food.aliases].join(" "));
  const overlap = queryTerms.filter((term) => foodTerms.includes(term)).length;
  const exactAlias = [food.description, ...food.aliases].some(
    (value) => value.toLowerCase() === String(request.name ?? "").toLowerCase(),
  );
  return overlap * 10 + (exactAlias ? 100 : 0);
}

function tokenize(value) {
  return String(value)
    .toLowerCase()
    .split(/[^a-z0-9]+/u)
    .filter((term) => term.length > 1);
}
