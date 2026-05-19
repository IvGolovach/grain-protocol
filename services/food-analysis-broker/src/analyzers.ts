import { BrokerError } from "./errors.js";
import { FOOD_OBSERVATION_SCHEMA } from "./schema.js";
import { assertObservation } from "./validation.js";
import type { FoodAnalyzePhotoRequest, FoodAnalyzer, FoodObservation } from "./types.js";

const OPENAI_RESPONSES_URL = "https://api.openai.com/v1/responses";
const DEFAULT_MODEL = "gpt-5.5";

type FetchFn = typeof fetch;

export class MockFoodAnalyzer implements FoodAnalyzer {
  async analyze(input: {
    request: FoodAnalyzePhotoRequest;
    imageBytes: Uint8Array;
    photoSha25616: string;
  }): Promise<{ mode: "mock"; modelId: string; observation: FoodObservation }> {
    const byteSignal = input.imageBytes.reduce((sum, byte) => (sum + byte) % 97, 0);
    return {
      mode: "mock",
      modelId: "deterministic-fixture-food-analyzer-v1",
      observation: {
        items: [
          {
            label: input.request.hints?.meal_context || "fixture meal",
            confidence: 0.74
          }
        ],
        total_kcal: 300 + byteSignal,
        kcal_variance: 64,
        nutrition_label: null,
        serving_g: 220,
        amount_g: 220,
        servings: 1,
        confidence: 0.74,
        rationale: "deterministic fixture observation for local development and tests"
      }
    };
  }
}

export class OpenAiFoodAnalyzer implements FoodAnalyzer {
  private readonly apiKey: string;
  private readonly model: string;
  private readonly fetchFn: FetchFn;

  constructor(options: { apiKey: string; model?: string; fetchFn?: FetchFn }) {
    this.apiKey = options.apiKey;
    this.model = options.model ?? DEFAULT_MODEL;
    this.fetchFn = options.fetchFn ?? fetch;
  }

  async analyze(input: {
    request: FoodAnalyzePhotoRequest;
    imageBytes: Uint8Array;
    photoSha25616: string;
  }): Promise<{ mode: "openai"; modelId: string; observation: FoodObservation }> {
    const body = this.buildResponsesRequest(input.request);
    const response = await this.fetchFn(OPENAI_RESPONSES_URL, {
      method: "POST",
      headers: {
        "authorization": `Bearer ${this.apiKey}`,
        "content-type": "application/json"
      },
      body: JSON.stringify(body)
    });

    if (!response.ok) {
      throw new BrokerError(502, "UPSTREAM_ERROR", "OpenAI food observation request failed", {
        upstream_status: response.status
      });
    }

    const responseJson = await response.json() as unknown;
    const outputText = extractOutputText(responseJson);
    let parsed: unknown;
    try {
      parsed = JSON.parse(outputText);
    } catch {
      throw new BrokerError(502, "UPSTREAM_ERROR", "OpenAI food observation was not valid JSON");
    }

    return {
      mode: "openai",
      modelId: this.model,
      observation: assertObservation(parsed)
    };
  }

  private buildResponsesRequest(request: FoodAnalyzePhotoRequest): Record<string, unknown> {
    const imageUrl = `data:${request.photo.media_type};base64,${request.photo.bytes_b64}`;
    return {
      model: this.model,
      store: false,
      max_output_tokens: 900,
      instructions: [
        "You estimate visible food from one user-provided photo.",
        "When a Nutrition Facts label, menu label, package label, barcode-facing product panel, or other printed nutrition text is visible, read it with OCR and treat those explicit label facts as higher priority than generic visual portion estimates.",
        "If a visible label states calories for the whole bottle, package, container, or plate, set total_kcal to that exact whole-container value, set kcal_variance to 0, and fill nutrition_label.calories_per_container.",
        "If only per-serving calories and servings per container are visible, set total_kcal to calories_per_serving multiplied by servings_per_container, round to the nearest integer, set kcal_variance to 0, and fill the nutrition_label fields.",
        "Do not rescale explicit package-label calories by bottle size, visual ounces, milliliters, grams, or generic USDA-style per-100g nutrition.",
        "Set nutrition_label to null when no explicit visible nutrition label is present.",
        "Return only the requested structured JSON observation.",
        "Do not produce Grain ledger records, drafts, CIDs, signatures, or persistence fields.",
        "Never echo or describe raw image bytes."
      ].join(" "),
      input: [
        {
          role: "user",
          content: [
            {
              type: "input_text",
              text: JSON.stringify({
                task: "Estimate food items and calories from the image.",
                capture_id: request.capture_id ?? null,
                hints: request.hints ?? {},
                output_boundary: "observation_only"
              })
            },
            {
              type: "input_image",
              image_url: imageUrl,
              detail: "high"
            }
          ]
        }
      ],
      text: {
        format: {
          type: "json_schema",
          name: "grain_food_photo_observation_v1",
          strict: true,
          schema: FOOD_OBSERVATION_SCHEMA
        }
      }
    };
  }
}

export function analyzerFromEnv(env: NodeJS.ProcessEnv = process.env): FoodAnalyzer {
  if (env.OPENAI_API_KEY && env.OPENAI_API_KEY.trim().length > 0) {
    return new OpenAiFoodAnalyzer({
      apiKey: env.OPENAI_API_KEY,
      model: env.OPENAI_MODEL || undefined
    });
  }
  return new MockFoodAnalyzer();
}

function extractOutputText(value: unknown): string {
  if (isRecord(value) && typeof value.output_text === "string") {
    return value.output_text;
  }

  if (!isRecord(value) || !Array.isArray(value.output)) {
    throw new BrokerError(502, "UPSTREAM_ERROR", "OpenAI response did not include output text");
  }

  const chunks: string[] = [];
  for (const item of value.output) {
    if (!isRecord(item) || !Array.isArray(item.content)) continue;
    for (const content of item.content) {
      if (isRecord(content) && content.type === "output_text" && typeof content.text === "string") {
        chunks.push(content.text);
      }
    }
  }
  if (chunks.length === 0) {
    throw new BrokerError(502, "UPSTREAM_ERROR", "OpenAI response did not include output text");
  }
  return chunks.join("");
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
