export const MAX_JSON_BODY_BYTES = 4 * 1024 * 1024;
export const MAX_IMAGE_BYTES = 3 * 1024 * 1024;

export const FOOD_OBSERVATION_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["items", "total_kcal", "kcal_variance", "serving_g", "amount_g", "servings", "confidence", "rationale"],
  properties: {
    items: {
      type: "array",
      maxItems: 8,
      items: {
        type: "object",
        additionalProperties: false,
        required: ["label", "confidence"],
        properties: {
          label: { type: "string", minLength: 1, maxLength: 80 },
          confidence: { type: "number", minimum: 0, maximum: 1 }
        }
      }
    },
    total_kcal: { type: "integer", minimum: 0, maximum: 10000 },
    kcal_variance: { type: "integer", minimum: 0, maximum: 1000000 },
    serving_g: { anyOf: [{ type: "integer", minimum: 0, maximum: 10000 }, { type: "null" }] },
    amount_g: { anyOf: [{ type: "integer", minimum: 0, maximum: 10000 }, { type: "null" }] },
    servings: { anyOf: [{ type: "integer", minimum: 0, maximum: 100 }, { type: "null" }] },
    confidence: { type: "number", minimum: 0, maximum: 1 },
    rationale: { type: "string", maxLength: 240 }
  }
} as const;
