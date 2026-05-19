export const MAX_JSON_BODY_BYTES = 4 * 1024 * 1024;
export const MAX_IMAGE_BYTES = 3 * 1024 * 1024;

const NUTRITION_LABEL_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: [
    "is_visible",
    "calories_per_container",
    "calories_per_serving",
    "servings_per_container",
    "serving_size_text",
    "container_size_text",
    "source_text"
  ],
  properties: {
    is_visible: { type: "boolean" },
    calories_per_container: { anyOf: [{ type: "integer", minimum: 0, maximum: 10000 }, { type: "null" }] },
    calories_per_serving: { anyOf: [{ type: "integer", minimum: 0, maximum: 10000 }, { type: "null" }] },
    servings_per_container: { anyOf: [{ type: "number", minimum: 0, maximum: 100 }, { type: "null" }] },
    serving_size_text: { anyOf: [{ type: "string", minLength: 1, maxLength: 80 }, { type: "null" }] },
    container_size_text: { anyOf: [{ type: "string", minLength: 1, maxLength: 80 }, { type: "null" }] },
    source_text: { anyOf: [{ type: "string", minLength: 1, maxLength: 160 }, { type: "null" }] }
  }
} as const;

export const FOOD_OBSERVATION_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: [
    "items",
    "total_kcal",
    "kcal_variance",
    "nutrition_label",
    "serving_g",
    "amount_g",
    "servings",
    "confidence",
    "rationale"
  ],
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
    nutrition_label: { anyOf: [NUTRITION_LABEL_SCHEMA, { type: "null" }] },
    serving_g: { anyOf: [{ type: "integer", minimum: 0, maximum: 10000 }, { type: "null" }] },
    amount_g: { anyOf: [{ type: "integer", minimum: 0, maximum: 10000 }, { type: "null" }] },
    servings: { anyOf: [{ type: "integer", minimum: 0, maximum: 100 }, { type: "null" }] },
    confidence: { type: "number", minimum: 0, maximum: 1 },
    rationale: { type: "string", maxLength: 240 }
  }
} as const;
