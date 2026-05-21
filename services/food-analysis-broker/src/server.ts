import { Readable } from "node:stream";
import { createServer, type IncomingMessage, type Server, type ServerResponse } from "node:http";

import type { BrokerAuthConfig } from "./auth.js";
import { createBrokerDependencies, type BrokerDependencyOptions } from "./dependencies.js";
import { handleBrokerRequest } from "./handler.js";
import type { CandidateResolver, FoodAnalyzer, FoodSearchProvider, ObservationResolver } from "./types.js";

export type BrokerServerOptions = {
  analyzer?: FoodAnalyzer;
  authToken?: string;
  candidateResolver?: CandidateResolver;
  searchProvider?: FoodSearchProvider;
  resolver?: ObservationResolver;
  maxBodyBytes?: number;
};

export function createBrokerServer(options: BrokerServerOptions = {}): Server {
  const dependencies = createBrokerDependencies(process.env, nodeDependencyOptions(options));

  return createServer(async (incoming, outgoing) => {
    try {
      const request = nodeRequestFrom(incoming);
      const response = await handleBrokerRequest(request, dependencies);
      await writeNodeResponse(outgoing, response);
    } catch {
      outgoing.statusCode = 500;
      outgoing.setHeader("content-type", "application/json; charset=utf-8");
      outgoing.end(`${JSON.stringify({ ok: false, error: { code: "INTERNAL_ERROR", message: "internal server error" } })}\n`);
    }
  });
}

function nodeDependencyOptions(options: BrokerServerOptions): BrokerDependencyOptions {
  const auth = authOptionsFromLegacyToken(options.authToken);
  return {
    ...(options.analyzer ? { analyzer: options.analyzer } : {}),
    ...(options.candidateResolver ? { candidateResolver: options.candidateResolver } : {}),
    ...(options.searchProvider ? { searchProvider: options.searchProvider } : {}),
    ...(options.resolver ? { resolver: options.resolver } : {}),
    ...(options.maxBodyBytes === undefined ? {} : { maxBodyBytes: options.maxBodyBytes }),
    ...(auth ? { auth } : {})
  };
}

function authOptionsFromLegacyToken(value: string | undefined): Partial<BrokerAuthConfig> | undefined {
  const trimmed = value?.trim();
  if (!trimmed) return undefined;
  return {
    mode: "dev_bearer",
    devBearerToken: trimmed
  };
}

function nodeRequestFrom(incoming: IncomingMessage): Request {
  const host = incoming.headers.host ?? "127.0.0.1";
  const url = new URL(incoming.url ?? "/", `http://${host}`);
  const headers = new Headers();
  for (const [key, value] of Object.entries(incoming.headers)) {
    if (value === undefined) continue;
    if (Array.isArray(value)) {
      for (const entry of value) {
        headers.append(key, entry);
      }
      continue;
    }
    headers.set(key, value);
  }

  const method = incoming.method ?? "GET";
  const init: RequestInit & { duplex?: "half" } = {
    method,
    headers
  };
  if (method !== "GET" && method !== "HEAD") {
    init.body = Readable.toWeb(incoming) as ReadableStream<Uint8Array>;
    init.duplex = "half";
  }
  return new Request(url, init);
}

async function writeNodeResponse(outgoing: ServerResponse, response: Response): Promise<void> {
  outgoing.statusCode = response.status;
  for (const [key, value] of response.headers) {
    outgoing.setHeader(key, value);
  }
  if (!response.body) {
    outgoing.end();
    return;
  }

  const reader = response.body.getReader();
  try {
    for (;;) {
      const chunk = await reader.read();
      if (chunk.done) break;
      outgoing.write(Buffer.from(chunk.value));
    }
    outgoing.end();
  } finally {
    reader.releaseLock();
  }
}
