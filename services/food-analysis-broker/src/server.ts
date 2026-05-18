import { randomUUID } from "node:crypto";
import { createServer, type IncomingMessage, type Server, type ServerResponse } from "node:http";

import { analyzerFromEnv } from "./analyzers.js";
import { BrokerError, errorShape, internalError } from "./errors.js";
import { FoodAnalysisCandidateResolver, GrainDraftResolver } from "./resolver.js";
import { MAX_JSON_BODY_BYTES } from "./schema.js";
import { assertObservation, parseAnalyzePhotoRequest } from "./validation.js";
import type { CandidateResolver, FoodAnalyzer, FoodAnalyzePhotoSuccess, ObservationResolver } from "./types.js";

export type BrokerServerOptions = {
  analyzer?: FoodAnalyzer;
  candidateResolver?: CandidateResolver;
  resolver?: ObservationResolver;
  maxBodyBytes?: number;
};

export function createBrokerServer(options: BrokerServerOptions = {}): Server {
  const analyzer = options.analyzer ?? analyzerFromEnv();
  const candidateResolver = options.candidateResolver ?? new FoodAnalysisCandidateResolver();
  const resolver = options.resolver ?? new GrainDraftResolver();
  const maxBodyBytes = options.maxBodyBytes ?? MAX_JSON_BODY_BYTES;

  return createServer(async (req, res) => {
    const requestId = req.headers["x-request-id"]?.toString() || randomUUID();
    try {
      await routeRequest(req, res, { analyzer, candidateResolver, resolver, maxBodyBytes, requestId });
    } catch (err) {
      if (err instanceof BrokerError) {
        writeJson(res, err.status, errorShape(err, requestId));
        return;
      }
      writeJson(res, 500, internalError(requestId));
    }
  });
}

async function routeRequest(
  req: IncomingMessage,
  res: ServerResponse,
  context: {
    analyzer: FoodAnalyzer;
    candidateResolver: CandidateResolver;
    resolver: ObservationResolver;
    maxBodyBytes: number;
    requestId: string;
  }
): Promise<void> {
  if (req.url !== "/v1/food/analyze-photo") {
    throw new BrokerError(404, "NOT_FOUND", "route not found");
  }
  if (req.method !== "POST") {
    throw new BrokerError(405, "METHOD_NOT_ALLOWED", "POST is required");
  }
  if (!contentTypeIsJson(req.headers["content-type"])) {
    throw new BrokerError(400, "BAD_REQUEST", "content-type must be application/json");
  }

  const rawBody = await readBody(req, context.maxBodyBytes);
  let parsed: unknown;
  try {
    parsed = JSON.parse(rawBody);
  } catch {
    throw new BrokerError(400, "BAD_JSON", "request body must be valid JSON");
  }

  const { request, imageBytes, photoSha25616, requestId } = parseAnalyzePhotoRequest(parsed);
  const analysis = await context.analyzer.analyze({ request, imageBytes, photoSha25616 });
  const observation = assertObservation(analysis.observation);
  const candidate = await context.candidateResolver.resolveCandidate({
    request,
    observation,
    photoSha25616,
    modelId: analysis.modelId
  });
  const draft = context.resolver.resolve({
    request,
    observation,
    photoSha25616,
    modelId: analysis.modelId
  });

  const body: FoodAnalyzePhotoSuccess = {
    ok: true,
    request_id: request.request_id ?? requestId,
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
  writeJson(res, 200, body);
}

function readBody(req: IncomingMessage, maxBodyBytes: number): Promise<string> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    let seen = 0;
    let overLimit = false;
    req.on("data", (chunk: Buffer) => {
      seen += chunk.byteLength;
      if (seen > maxBodyBytes) {
        overLimit = true;
        return;
      }
      if (!overLimit) chunks.push(chunk);
    });
    req.on("error", reject);
    req.on("end", () => {
      if (overLimit) {
        reject(new BrokerError(413, "PAYLOAD_TOO_LARGE", "request body exceeds JSON byte cap", {
          max_json_body_bytes: maxBodyBytes
        }));
        return;
      }
      resolve(Buffer.concat(chunks).toString("utf8"));
    });
  });
}

function contentTypeIsJson(value: string | string[] | undefined): boolean {
  if (!value) return false;
  const header = Array.isArray(value) ? value[0] : value;
  return header.toLowerCase().split(";")[0].trim() === "application/json";
}

function writeJson(res: ServerResponse, status: number, body: unknown): void {
  res.statusCode = status;
  res.setHeader("content-type", "application/json; charset=utf-8");
  res.end(`${JSON.stringify(body)}\n`);
}
