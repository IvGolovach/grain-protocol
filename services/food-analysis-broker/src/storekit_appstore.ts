import { BrokerError } from "./errors.js";
import { runtimeFetch, type RuntimeEnv, type RuntimeFetch } from "./runtime.js";
import type { StoreKitEnvironment, StoreKitTransactionVerifier, VerifiedStoreKitTransaction } from "./storekit.js";

type AppStoreServerApiVerifierOptions = {
  bundleId: string;
  environment: StoreKitEnvironment;
  issuerId: string;
  keyId: string;
  privateKeyPem: string;
  baseUrl?: string;
  fetchFn?: RuntimeFetch;
  nowSeconds?: () => number;
};

const APP_STORE_PRODUCTION_BASE_URL = "https://api.storekit.apple.com";
const APP_STORE_SANDBOX_BASE_URL = "https://api.storekit-sandbox.apple.com";

export class AppStoreServerApiTransactionVerifier implements StoreKitTransactionVerifier {
  private readonly fetchFn: RuntimeFetch;
  private readonly nowSeconds: () => number;
  private signingKeyPromise?: Promise<CryptoKey>;

  constructor(private readonly options: AppStoreServerApiVerifierOptions) {
    this.fetchFn = options.fetchFn ?? runtimeFetch;
    this.nowSeconds = options.nowSeconds ?? (() => Math.floor(Date.now() / 1000));
  }

  async verifySignedTransaction(input: { signedTransaction: string }): Promise<VerifiedStoreKitTransaction> {
    const requested = decodeJwsPayload(input.signedTransaction);
    const requestedTransactionId = requiredPayloadString(requested.transactionId, "transactionId");
    const token = await this.createBearerToken();
    const fetchFn = this.fetchFn;
    const response = await fetchFn(`${this.baseUrl()}/inApps/v1/transactions/${encodeURIComponent(requestedTransactionId)}`, {
      method: "GET",
      headers: {
        "accept": "application/json",
        "authorization": `Bearer ${token}`,
        "user-agent": "mealmark-food-analysis-broker/0.1"
      }
    });
    if (!response.ok) {
      throw new BrokerError(502, "UPSTREAM_ERROR", "App Store transaction verification failed", {
        status: response.status
      });
    }

    const body = await response.json() as Record<string, unknown>;
    const signedTransactionInfo = requiredPayloadString(body.signedTransactionInfo, "signedTransactionInfo");
    const payload = decodeJwsPayload(signedTransactionInfo);
    const verifiedTransactionId = requiredPayloadString(payload.transactionId, "transactionId");
    if (verifiedTransactionId !== requestedTransactionId) {
      throw new BrokerError(502, "UPSTREAM_ERROR", "App Store transaction response did not match request");
    }

    const bundleId = optionalPayloadString(payload.bundleId);
    if (bundleId && bundleId !== this.options.bundleId) {
      throw new BrokerError(403, "FORBIDDEN", "StoreKit transaction belongs to a different app bundle");
    }

    return {
      transactionId: verifiedTransactionId,
      originalTransactionId: requiredPayloadString(payload.originalTransactionId, "originalTransactionId"),
      productId: requiredPayloadString(payload.productId, "productId"),
      environment: normalizeEnvironment(requiredPayloadString(payload.environment, "environment")),
      purchaseDateMs: requiredPayloadInteger(payload.purchaseDate, "purchaseDate"),
      ...(payload.expiresDate === undefined ? {} : { expiresDateMs: requiredPayloadInteger(payload.expiresDate, "expiresDate") }),
      ...(payload.revocationDate === undefined ? {} : { revocationDateMs: requiredPayloadInteger(payload.revocationDate, "revocationDate") }),
      ...(optionalPayloadString(payload.appAccountToken) ? { appAccountToken: optionalPayloadString(payload.appAccountToken)! } : {})
    };
  }

  private baseUrl(): string {
    return this.options.baseUrl ??
      (this.options.environment === "Production" ? APP_STORE_PRODUCTION_BASE_URL : APP_STORE_SANDBOX_BASE_URL);
  }

  private async createBearerToken(): Promise<string> {
    const now = this.nowSeconds();
    const header = base64UrlEncodeJson({ alg: "ES256", kid: this.options.keyId, typ: "JWT" });
    const payload = base64UrlEncodeJson({
      iss: this.options.issuerId,
      iat: now,
      exp: now + 300,
      aud: "appstoreconnect-v1",
      bid: this.options.bundleId
    });
    const signingInput = `${header}.${payload}`;
    const signature = await globalThis.crypto.subtle.sign(
      { name: "ECDSA", hash: "SHA-256" },
      await this.signingKey(),
      new TextEncoder().encode(signingInput)
    );
    return `${signingInput}.${base64UrlEncode(ecdsaSignatureToJose(new Uint8Array(signature)))}`;
  }

  private signingKey(): Promise<CryptoKey> {
    if (!this.signingKeyPromise) {
      this.signingKeyPromise = importP8PrivateKey(this.options.privateKeyPem);
    }
    return this.signingKeyPromise;
  }
}

export function appStoreServerApiVerifierFromEnv(env: RuntimeEnv): StoreKitTransactionVerifier | undefined {
  const bundleId = normalizedEnvString(env.APP_STORE_BUNDLE_ID);
  const issuerId = normalizedEnvString(env.APP_STORE_CONNECT_ISSUER_ID);
  const keyId = normalizedEnvString(env.APP_STORE_CONNECT_KEY_ID);
  const privateKeyPem = normalizedEnvString(env.APP_STORE_CONNECT_PRIVATE_KEY_P8);
  if (!bundleId || !issuerId || !keyId || !privateKeyPem) return undefined;

  return new AppStoreServerApiTransactionVerifier({
    bundleId,
    environment: normalizeConfiguredEnvironment(env.APP_STORE_SERVER_ENVIRONMENT),
    issuerId,
    keyId,
    privateKeyPem,
    ...(normalizedEnvString(env.APP_STORE_SERVER_API_BASE_URL) ? { baseUrl: normalizedEnvString(env.APP_STORE_SERVER_API_BASE_URL)! } : {})
  });
}

function normalizeConfiguredEnvironment(value: string | undefined): StoreKitEnvironment {
  if (value === undefined || value.trim() === "") return "Sandbox";
  return normalizeEnvironment(value);
}

function normalizeEnvironment(value: string): StoreKitEnvironment {
  if (value === "Sandbox" || value.toLowerCase() === "sandbox") return "Sandbox";
  if (value === "Production" || value.toLowerCase() === "production") return "Production";
  throw new BrokerError(502, "UPSTREAM_ERROR", "StoreKit environment is invalid");
}

function decodeJwsPayload(jws: string): Record<string, unknown> {
  const parts = jws.split(".");
  if (parts.length !== 3 || !parts[1]) {
    throw new BrokerError(400, "BAD_REQUEST", "signed_transaction_info must be a compact JWS");
  }
  try {
    const json = new TextDecoder().decode(base64UrlDecode(parts[1]));
    const parsed = JSON.parse(json) as unknown;
    if (!isRecord(parsed)) {
      throw new Error("payload is not an object");
    }
    return parsed;
  } catch {
    throw new BrokerError(400, "BAD_REQUEST", "signed_transaction_info payload is invalid");
  }
}

async function importP8PrivateKey(privateKeyPem: string): Promise<CryptoKey> {
  const normalized = privateKeyPem
    .replace(/\\n/g, "\n")
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  if (!normalized) {
    throw new BrokerError(503, "PROVIDER_NOT_CONFIGURED", "App Store Connect private key is not configured");
  }
  return globalThis.crypto.subtle.importKey(
    "pkcs8",
    arrayBufferFrom(base64Decode(normalized)),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );
}

function ecdsaSignatureToJose(signature: Uint8Array): Uint8Array {
  if (signature.byteLength === 64) return signature;
  if (signature[0] !== 0x30) return signature;

  let offset = 2;
  if (signature[1] & 0x80) {
    offset = 2 + (signature[1] & 0x7f);
  }
  const first = readDerInteger(signature, offset);
  const second = readDerInteger(signature, first.nextOffset);
  const jose = new Uint8Array(64);
  jose.set(leftPad32(first.bytes), 0);
  jose.set(leftPad32(second.bytes), 32);
  return jose;
}

function readDerInteger(bytes: Uint8Array, offset: number): { bytes: Uint8Array; nextOffset: number } {
  if (bytes[offset] !== 0x02) {
    throw new BrokerError(500, "INTERNAL_ERROR", "ECDSA signature is not DER encoded");
  }
  const length = bytes[offset + 1];
  const start = offset + 2;
  return { bytes: bytes.slice(start, start + length), nextOffset: start + length };
}

function leftPad32(bytes: Uint8Array): Uint8Array {
  let trimmed = bytes;
  while (trimmed.length > 32 && trimmed[0] === 0) {
    trimmed = trimmed.slice(1);
  }
  if (trimmed.length > 32) {
    throw new BrokerError(500, "INTERNAL_ERROR", "ECDSA signature integer is too large");
  }
  const padded = new Uint8Array(32);
  padded.set(trimmed, 32 - trimmed.length);
  return padded;
}

function base64UrlEncodeJson(value: Record<string, unknown>): string {
  return base64UrlEncode(new TextEncoder().encode(JSON.stringify(value)));
}

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return globalThis.btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/u, "");
}

function base64UrlDecode(value: string): Uint8Array {
  const padded = value.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(value.length / 4) * 4, "=");
  return base64Decode(padded);
}

function base64Decode(value: string): Uint8Array {
  const binary = globalThis.atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

function arrayBufferFrom(bytes: Uint8Array): ArrayBuffer {
  return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
}

function requiredPayloadString(value: unknown, fieldName: string): string {
  const trimmed = optionalPayloadString(value);
  if (!trimmed) {
    throw new BrokerError(502, "UPSTREAM_ERROR", `App Store transaction ${fieldName} is invalid`);
  }
  return trimmed;
}

function optionalPayloadString(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  return trimmed ? trimmed : undefined;
}

function requiredPayloadInteger(value: unknown, fieldName: string): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) {
    throw new BrokerError(502, "UPSTREAM_ERROR", `App Store transaction ${fieldName} is invalid`);
  }
  return value;
}

function normalizedEnvString(value: string | undefined): string | undefined {
  const trimmed = value?.trim();
  return trimmed ? trimmed : undefined;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
