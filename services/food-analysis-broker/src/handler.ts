import type { AccountRecord } from "./accounts.js";
import { authenticateBrokerRequest, requireBearerToken } from "./auth.js";
import type { BrokerDependencies } from "./dependencies.js";
import type { EntitlementRecord } from "./entitlements.js";
import { BrokerError, errorShape, internalError } from "./errors.js";
import type { IssuedSession, SessionRecord } from "./sessions.js";
import { ingestStoreKitTransaction } from "./storekit.js";
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
  if (url.pathname === "/v1/auth/bootstrap") {
    assertMethod(request, "POST");
    assertJsonContentType(request);
    const parsed = await readJsonBody(request, dependencies.maxBodyBytes);
    return handleAuthBootstrap(parsed, dependencies);
  }
  if (url.pathname === "/v1/auth/refresh") {
    assertMethod(request, "POST");
    return handleAuthRefresh(request, dependencies);
  }
  if (url.pathname === "/v1/auth/logout") {
    assertMethod(request, "POST");
    return handleAuthLogout(request, dependencies);
  }
  if (url.pathname === "/v1/account/me") {
    assertMethod(request, "GET");
    return handleAccountMe(request, dependencies);
  }
  if (url.pathname === "/v1/account/delete") {
    assertMethod(request, "POST");
    return handleAccountDelete(request, dependencies);
  }
  if (url.pathname === "/v1/storekit/transactions") {
    assertMethod(request, "POST");
    assertJsonContentType(request);
    const auth = await authenticateRequestWithSessionStore(request, dependencies);
    const parsed = await readJsonBody(request, dependencies.maxBodyBytes);
    return handleStoreKitTransaction(parsed, auth.accountId, dependencies);
  }

  if (url.pathname !== "/v1/food/analyze-photo" && url.pathname !== "/v1/food/search") {
    throw new BrokerError(404, "NOT_FOUND", "route not found");
  }
  assertMethod(request, "POST");
  assertJsonContentType(request);

  const auth = await authenticateRequestWithSessionStore(request, dependencies, {
    allowAnonymous: url.pathname === "/v1/food/search" && dependencies.auth.allowAnonymousFoodSearch === true
  });
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

async function handleAuthBootstrap(parsed: unknown, dependencies: BrokerDependencies): Promise<Response> {
  const request = parseBootstrapRequest(parsed);
  const nowMs = Date.now();
  const account = await dependencies.accountStore.bootstrapAccount({
    ...(request.deviceIdHash ? { deviceIdHash: request.deviceIdHash } : {}),
    ...(request.appAccountToken ? { appAccountToken: request.appAccountToken } : {}),
    nowMs
  });
  const entitlement = await dependencies.entitlementStore.getActiveEntitlement(account.accountId, nowMs);
  const session = await dependencies.sessionStore.createSession({
    accountId: account.accountId,
    tier: entitlement.tier,
    nowMs
  });
  return jsonResponse(200, authSessionShape(account, session, entitlement));
}

async function handleAuthRefresh(request: Request, dependencies: BrokerDependencies): Promise<Response> {
  const token = requireBearerToken(request);
  const nowMs = Date.now();
  const currentSession = await requireCurrentSession(token, dependencies, nowMs);
  const account = await requireActiveAccount(currentSession.accountId, dependencies);
  const entitlement = await dependencies.entitlementStore.getActiveEntitlement(account.accountId, nowMs);
  await dependencies.sessionStore.revokeSessionByToken(token, nowMs);
  const nextSession = await dependencies.sessionStore.createSession({
    accountId: account.accountId,
    ...(currentSession.deviceId ? { deviceId: currentSession.deviceId } : {}),
    tier: entitlement.tier,
    nowMs
  });
  return jsonResponse(200, authSessionShape(account, nextSession, entitlement));
}

async function handleAuthLogout(request: Request, dependencies: BrokerDependencies): Promise<Response> {
  const token = requireBearerToken(request);
  const nowMs = Date.now();
  await requireCurrentSession(token, dependencies, nowMs);
  await dependencies.sessionStore.revokeSessionByToken(token, nowMs);
  return jsonResponse(200, { ok: true });
}

async function handleAccountMe(request: Request, dependencies: BrokerDependencies): Promise<Response> {
  const auth = await authenticateRequestWithSessionStore(request, dependencies);
  const nowMs = Date.now();
  const account = await requireActiveAccount(auth.accountId, dependencies);
  const entitlement = await dependencies.entitlementStore.getActiveEntitlement(account.accountId, nowMs);
  return jsonResponse(200, {
    ok: true,
    account: accountShape(account),
    session: {
      ...(auth.sessionId ? { session_id: auth.sessionId } : {}),
      ...(auth.sessionExpiresAtMs === undefined ? {} : { expires_at_ms: auth.sessionExpiresAtMs })
    },
    entitlement: entitlementShape(entitlement)
  });
}

async function handleAccountDelete(request: Request, dependencies: BrokerDependencies): Promise<Response> {
  const auth = await authenticateRequestWithSessionStore(request, dependencies);
  const nowMs = Date.now();
  await requireActiveAccount(auth.accountId, dependencies);
  const deleted = await dependencies.accountStore.deleteAccount(auth.accountId, nowMs);
  await dependencies.sessionStore.revokeSessionsByAccount(auth.accountId, nowMs);
  return jsonResponse(200, {
    ok: true,
    account: deleted ? accountShape(deleted) : { account_id: auth.accountId, status: "deleted" }
  });
}

async function handleStoreKitTransaction(
  parsed: unknown,
  accountId: string,
  dependencies: BrokerDependencies
): Promise<Response> {
  const body = parseStoreKitTransactionRequest(parsed);
  const account = await requireActiveAccount(accountId, dependencies);
  const result = await ingestStoreKitTransaction({
    accountId,
    ...(account.appAccountToken ? { expectedAppAccountToken: account.appAccountToken } : {}),
    signedTransactionInfo: body.signedTransactionInfo,
    verifier: dependencies.storeKitVerifier,
    transactionStore: dependencies.storeKitTransactionStore,
    entitlementStore: dependencies.entitlementStore,
    nowMs: Date.now()
  });
  return jsonResponse(200, {
    ok: true,
    account: accountShape(account),
    transaction: {
      transaction_id: result.transaction.transactionId,
      original_transaction_id: result.transaction.originalTransactionId,
      product_id: result.transaction.productId,
      environment: result.transaction.environment,
      verified_at_ms: result.transaction.verifiedAtMs,
      ...(result.transaction.expiresAtMs === undefined ? {} : { expires_at_ms: result.transaction.expiresAtMs })
    },
    entitlement: entitlementShape(result.entitlement)
  });
}

async function authenticateRequestWithSessionStore(
  request: Request,
  dependencies: BrokerDependencies,
  options: { allowAnonymous?: boolean } = {}
) {
  return authenticateBrokerRequest(request, dependencies.auth, {
    allowAnonymous: options.allowAnonymous,
    sessionVerifier: {
      async authenticateSessionToken(token) {
        const nowMs = Date.now();
        const session = await requireCurrentSession(token, dependencies, nowMs);
        await requireActiveAccount(session.accountId, dependencies);
        const entitlement = await dependencies.entitlementStore.getActiveEntitlement(session.accountId, nowMs);
        return {
          mode: "session",
          accountId: session.accountId,
          ...(session.deviceId ? { deviceId: session.deviceId } : {}),
          sessionId: session.sessionId,
          sessionExpiresAtMs: session.expiresAtMs,
          tier: entitlement.tier
        };
      }
    }
  });
}

async function requireCurrentSession(
  token: string,
  dependencies: BrokerDependencies,
  nowMs: number
): Promise<SessionRecord> {
  const session = await dependencies.sessionStore.getSessionByToken(token, nowMs);
  if (!session) {
    throw new BrokerError(401, "UNAUTHORIZED", "session token is not valid");
  }
  return session;
}

async function requireActiveAccount(accountId: string, dependencies: BrokerDependencies): Promise<AccountRecord> {
  const account = await dependencies.accountStore.getAccount(accountId);
  if (!account || account.status !== "active") {
    throw new BrokerError(401, "UNAUTHORIZED", "account is not active");
  }
  return account;
}

function parseBootstrapRequest(value: unknown): { deviceIdHash?: string; appAccountToken?: string } {
  if (!isRecord(value)) {
    throw new BrokerError(400, "BAD_REQUEST", "request body must be a JSON object");
  }
  const deviceIdHash = optionalString(value.device_id_hash, "device_id_hash") ??
    optionalString(value.device_id, "device_id");
  const appAccountToken = optionalString(value.app_account_token, "app_account_token");
  if (deviceIdHash && deviceIdHash.length > 256) {
    throw new BrokerError(400, "BAD_REQUEST", "device_id_hash is too long");
  }
  if (appAccountToken && !isUuid(appAccountToken)) {
    throw new BrokerError(400, "BAD_REQUEST", "app_account_token must be a UUID string");
  }
  return {
    ...(deviceIdHash ? { deviceIdHash } : {}),
    ...(appAccountToken ? { appAccountToken } : {})
  };
}

function parseStoreKitTransactionRequest(value: unknown): { signedTransactionInfo: string } {
  if (!isRecord(value)) {
    throw new BrokerError(400, "BAD_REQUEST", "request body must be a JSON object");
  }
  return {
    signedTransactionInfo: requiredString(
      value.signed_transaction_info ?? value.signed_transaction_b64,
      "signed_transaction_info"
    )
  };
}

function authSessionShape(account: AccountRecord, issued: IssuedSession, entitlement: EntitlementRecord): Record<string, unknown> {
  return {
    ok: true,
    account: accountShape(account),
    session: {
      access_token: issued.accessToken,
      token_type: issued.tokenType,
      expires_at_ms: issued.session.expiresAtMs
    },
    entitlement: entitlementShape(entitlement)
  };
}

function accountShape(account: AccountRecord): Record<string, unknown> {
  return {
    account_id: account.accountId,
    status: account.status,
    created_at_ms: account.createdAtMs,
    updated_at_ms: account.updatedAtMs
  };
}

function entitlementShape(entitlement: EntitlementRecord): Record<string, unknown> {
  return {
    tier: entitlement.tier,
    source: entitlement.source,
    ...(entitlement.productId ? { product_id: entitlement.productId } : {}),
    ...(entitlement.originalTransactionId ? { original_transaction_id: entitlement.originalTransactionId } : {}),
    effective_at_ms: entitlement.effectiveAtMs,
    ...(entitlement.expiresAtMs === undefined ? {} : { expires_at_ms: entitlement.expiresAtMs })
  };
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

function assertMethod(request: Request, expected: "GET" | "POST"): void {
  if (request.method !== expected) {
    throw new BrokerError(405, "METHOD_NOT_ALLOWED", `${expected} is required`);
  }
}

function assertJsonContentType(request: Request): void {
  if (!contentTypeIsJson(request.headers.get("content-type"))) {
    throw new BrokerError(400, "BAD_REQUEST", "content-type must be application/json");
  }
}

function contentTypeIsJson(value: string | null): boolean {
  if (!value) return false;
  return value.toLowerCase().split(";")[0].trim() === "application/json";
}

function requiredString(value: unknown, fieldName: string): string {
  if (typeof value !== "string" || value.trim() === "") {
    throw new BrokerError(400, "BAD_REQUEST", `${fieldName} must be a non-empty string`);
  }
  return value.trim();
}

function optionalString(value: unknown, fieldName: string): string | undefined {
  if (value === undefined || value === null) return undefined;
  if (typeof value !== "string") {
    throw new BrokerError(400, "BAD_REQUEST", `${fieldName} must be a string`);
  }
  const trimmed = value.trim();
  return trimmed ? trimmed : undefined;
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu.test(value);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
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
