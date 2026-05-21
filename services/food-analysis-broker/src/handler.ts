import { authenticateBrokerRequest } from "./auth.js";
import type { BrokerDependencies } from "./dependencies.js";
import { BrokerError, errorShape, internalError } from "./errors.js";
import { randomRequestId } from "./runtime.js";
import { assertUsageAllowed } from "./usage.js";
import { assertObservation, assertReviewableFoodObservation, parseAnalyzePhotoRequest, parseFoodSearchRequest } from "./validation.js";
import type { FoodAnalyzePhotoSuccess, FoodSearchSuccess } from "./types.js";

export async function handleBrokerRequest(request: Request, dependencies: BrokerDependencies): Promise<Response> {
  const requestId = request.headers.get("x-request-id") || randomRequestId();
  try {
    return await routeBrokerRequest(request, dependencies, requestId);
  } catch (error) {
    if (error instanceof BrokerError) {
      return jsonResponse(error.status, errorShape(error, requestId));
    }
    return jsonResponse(500, internalError(requestId));
  }
}

async function routeBrokerRequest(
  request: Request,
  dependencies: BrokerDependencies,
  requestId: string
): Promise<Response> {
  const url = new URL(request.url);
  if (url.pathname === "/healthz" || url.pathname === "/v1/health") {
    return jsonResponse(200, { ok: true, service: "mealmark-food-analysis-broker" });
  }
  if (url.pathname !== "/v1/food/analyze-photo" && url.pathname !== "/v1/food/search") {
    throw new BrokerError(404, "NOT_FOUND", "route not found");
  }
  if (request.method !== "POST") {
    throw new BrokerError(405, "METHOD_NOT_ALLOWED", "POST is required");
  }
  if (!contentTypeIsJson(request.headers.get("content-type"))) {
    throw new BrokerError(400, "BAD_REQUEST", "content-type must be application/json");
  }

  const auth = await authenticateBrokerRequest(request, dependencies.auth);
  const parsed = await readJsonBody(request, dependencies.maxBodyBytes);

  if (url.pathname === "/v1/food/search") {
    const { request: searchRequest, requestId: parsedRequestId } = parseFoodSearchRequest(parsed);
    await assertUsageAllowed(dependencies.usageLimiter, {
      auth,
      feature: "food_search",
      requestId: searchRequest.request_id ?? parsedRequestId
    });
    const results = await dependencies.searchProvider.search(searchRequest);
    const body: FoodSearchSuccess = {
      ok: true,
      request_id: searchRequest.request_id ?? parsedRequestId,
      ...(searchRequest.query ? { query: searchRequest.query } : {}),
      ...(searchRequest.barcode ? { barcode: searchRequest.barcode } : {}),
      results
    };
    return jsonResponse(200, body);
  }

  const { request: analyzeRequest, imageBytes, photoSha25616, requestId: parsedRequestId } =
    await parseAnalyzePhotoRequest(parsed);
  await assertUsageAllowed(dependencies.usageLimiter, {
    auth,
    feature: "photo_analysis",
    requestId: analyzeRequest.request_id ?? parsedRequestId
  });
  const analysis = await dependencies.analyzer.analyze({ request: analyzeRequest, imageBytes, photoSha25616 });
  const observation = assertObservation(analysis.observation);
  assertReviewableFoodObservation(observation);
  const candidate = await dependencies.candidateResolver.resolveCandidate({
    request: analyzeRequest,
    observation,
    photoSha25616,
    modelId: analysis.modelId
  });
  const draft = await dependencies.resolver.resolve({
    request: analyzeRequest,
    observation,
    photoSha25616,
    modelId: analysis.modelId
  });

  const body: FoodAnalyzePhotoSuccess = {
    ok: true,
    request_id: analyzeRequest.request_id ?? parsedRequestId,
    mode: analysis.mode,
    analysis_id: draft.source_ref.estimate_id,
    observation,
    candidate,
    draft,
    privacy: {
      store: false,
      raw_image_logged: false,
      raw_image_persisted: false
    }
  };
  return jsonResponse(200, body);
}

async function readJsonBody(request: Request, maxBodyBytes: number): Promise<unknown> {
  const contentLength = request.headers.get("content-length");
  if (contentLength) {
    const parsedLength = Number.parseInt(contentLength, 10);
    if (Number.isFinite(parsedLength) && parsedLength > maxBodyBytes) {
      throw new BrokerError(413, "PAYLOAD_TOO_LARGE", "request body exceeds JSON byte cap", {
        max_json_body_bytes: maxBodyBytes
      });
    }
  }

  const bodyText = await request.text();
  const byteLength = new TextEncoder().encode(bodyText).byteLength;
  if (byteLength > maxBodyBytes) {
    throw new BrokerError(413, "PAYLOAD_TOO_LARGE", "request body exceeds JSON byte cap", {
      max_json_body_bytes: maxBodyBytes
    });
  }

  try {
    return JSON.parse(bodyText) as unknown;
  } catch {
    throw new BrokerError(400, "BAD_JSON", "request body must be valid JSON");
  }
}

function contentTypeIsJson(value: string | null): boolean {
  if (!value) return false;
  return value.toLowerCase().split(";")[0].trim() === "application/json";
}

function jsonResponse(status: number, body: unknown): Response {
  return new Response(`${JSON.stringify(body)}\n`, {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store"
    }
  });
}
