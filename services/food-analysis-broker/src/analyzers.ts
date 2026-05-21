import { BrokerError } from "./errors.js";
import type { RuntimeEnv } from "./runtime.js";
import { FOOD_OBSERVATION_SCHEMA } from "./schema.js";
import { assertObservation } from "./validation.js";
import type { FoodAnalyzePhotoRequest, FoodAnalyzer, FoodObservation } from "./types.js";

const OPENAI_RESPONSES_URL = "https://api.openai.com/v1/responses";
const DEFAULT_MODEL = "gpt-5.5";
const DEFAULT_TIMEOUT_MS = 30_000;

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
        recognition_status: "food_detected",
        non_food_reason: null,
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

export class MissingFoodAnalyzer implements FoodAnalyzer {
  async analyze(): Promise<{ mode: "mock"; modelId: string; observation: FoodObservation }> {
    throw new BrokerError(
      503,
      "PROVIDER_NOT_CONFIGURED",
      "OpenAI food analysis is not configured; set OPENAI_API_KEY or explicitly enable FOOD_ANALYSIS_MOCK=1"
    );
  }
}

export class OpenAiFoodAnalyzer implements FoodAnalyzer {
  private readonly apiKey: string;
  private readonly model: string;
  private readonly fetchFn: FetchFn;
  private readonly timeoutMs: number;

  constructor(options: { apiKey: string; model?: string; fetchFn?: FetchFn; timeoutMs?: number }) {
    this.apiKey = options.apiKey;
    this.model = options.model ?? DEFAULT_MODEL;
    this.fetchFn = options.fetchFn ?? fetch;
    this.timeoutMs = options.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  }

  async analyze(input: {
    request: FoodAnalyzePhotoRequest;
    imageBytes: Uint8Array;
    photoSha25616: string;
  }): Promise<{ mode: "openai"; modelId: string; observation: FoodObservation }> {
    const body = this.buildResponsesRequest(input.request);
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.timeoutMs);
    let response: Response;
    try {
      response = await this.fetchFn(OPENAI_RESPONSES_URL, {
        method: "POST",
        headers: {
          "authorization": `Bearer ${this.apiKey}`,
          "content-type": "application/json"
        },
        body: JSON.stringify(body),
        signal: controller.signal
      });
    } catch (error) {
      if (isAbortError(error)) {
        throw new BrokerError(504, "UPSTREAM_TIMEOUT", "OpenAI food observation request timed out");
      }
      throw new BrokerError(502, "UPSTREAM_ERROR", "OpenAI food observation request failed");
    } finally {
      clearTimeout(timeout);
    }

    if (!response.ok) {
      throw new BrokerError(502, "UPSTREAM_ERROR", "OpenAI food observation request failed", {
        upstream_status: response.status
      });
    }

    let responseJson: unknown;
    try {
      responseJson = await response.json() as unknown;
    } catch {
      throw new BrokerError(502, "UPSTREAM_ERROR", "OpenAI food observation response was not valid JSON");
    }
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
        "If the image does not clearly show food, drink, or a readable nutrition label for a packaged product, set recognition_status to no_food, items to [], total_kcal and kcal_variance to 0, all portion fields to null, confidence to 0, and explain the visible non-food scene in non_food_reason.",
        "If food might be present but you cannot identify it well enough for a user-reviewable nutrition draft, set recognition_status to uncertain and keep items empty unless a specific visible food item is identifiable.",
        "Never invent a generic item such as captured meal, meal, food, plate, or unknown just to satisfy the schema.",
        "Only set recognition_status to food_detected when a specific food, drink, or nutrition label is visible enough to review.",
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

export function analyzerFromEnv(env: RuntimeEnv = {}): FoodAnalyzer {
  if (env.FOOD_ANALYSIS_MOCK === "1") {
    return new MockFoodAnalyzer();
  }
  if (env.OPENAI_API_KEY && env.OPENAI_API_KEY.trim().length > 0) {
    return new OpenAiFoodAnalyzer({
      apiKey: env.OPENAI_API_KEY,
      model: env.OPENAI_MODEL || undefined,
      timeoutMs: parseTimeoutMs(env.FOOD_ANALYSIS_TIMEOUT_MS)
    });
  }
  return new MissingFoodAnalyzer();
}

function parseTimeoutMs(value: string | undefined): number | undefined {
  if (!value) return undefined;
  const parsed = Number.parseInt(value, 10);
  return Number.isSafeInteger(parsed) && parsed >= 1_000 && parsed <= 120_000 ? parsed : undefined;
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

function isAbortError(value: unknown): boolean {
  return value instanceof Error && (value.name === "AbortError" || value.message.toLowerCase().includes("abort"));
}
