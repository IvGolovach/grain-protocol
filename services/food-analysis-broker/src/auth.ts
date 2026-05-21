import { BrokerError } from "./errors.js";
import { sha256Hex } from "./runtime.js";

export type BrokerAuthMode = "anonymous" | "dev_bearer" | "session";

export type BrokerAuthConfig = {
  mode: BrokerAuthMode;
  devBearerToken?: string;
  sessionHmacSecret?: string;
};

export type BrokerAuthContext = {
  mode: BrokerAuthMode;
  accountId: string;
  deviceId?: string;
  tier: "free" | "pro";
};

export type SessionTokenPayload = {
  account_id: string;
  device_id?: string;
  tier?: "free" | "pro";
  scope?: string;
  iat_ms: number;
  exp_ms: number;
};

export async function authenticateBrokerRequest(request: Request, config: BrokerAuthConfig): Promise<BrokerAuthContext> {
  if (config.mode === "anonymous") {
    return { mode: "anonymous", accountId: "anonymous", tier: "free" };
  }

  const bearerToken = bearerTokenFrom(request.headers.get("authorization"));
  if (!bearerToken) {
    throw new BrokerError(401, "UNAUTHORIZED", "authorization bearer token is required");
  }

  if (config.mode === "dev_bearer") {
    if (!config.devBearerToken || !(await constantTimeEqual(bearerToken, config.devBearerToken))) {
      throw new BrokerError(401, "UNAUTHORIZED", "valid broker bearer token is required");
    }
    return { mode: "dev_bearer", accountId: "local-dev", tier: "pro" };
  }

  const payload = await verifySignedSessionToken(bearerToken, config.sessionHmacSecret);
  return {
    mode: "session",
    accountId: payload.account_id,
    ...(payload.device_id ? { deviceId: payload.device_id } : {}),
    tier: payload.tier ?? "free"
  };
}

export async function createSignedSessionToken(payload: SessionTokenPayload, secret: string): Promise<string> {
  const encodedPayload = base64UrlEncode(new TextEncoder().encode(JSON.stringify(payload)));
  const signature = await signSessionPayload(encodedPayload, secret);
  return `mm_sess.${encodedPayload}.${signature}`;
}

export async function verifySignedSessionToken(token: string, secret: string | undefined): Promise<SessionTokenPayload> {
  if (!secret?.trim()) {
    throw new BrokerError(503, "PROVIDER_NOT_CONFIGURED", "session auth is not configured");
  }
  const parts = token.split(".");
  if (parts.length !== 3 || parts[0] !== "mm_sess") {
    throw new BrokerError(401, "UNAUTHORIZED", "session token is not valid");
  }
  const [_, payloadB64, signature] = parts;
  const expectedSignature = await signSessionPayload(payloadB64, secret);
  if (!(await constantTimeEqual(signature, expectedSignature))) {
    throw new BrokerError(401, "UNAUTHORIZED", "session token signature is not valid");
  }

  let payload: unknown;
  try {
    payload = JSON.parse(new TextDecoder().decode(base64UrlDecode(payloadB64)));
  } catch {
    throw new BrokerError(401, "UNAUTHORIZED", "session token payload is not valid");
  }
  if (!isSessionPayload(payload)) {
    throw new BrokerError(401, "UNAUTHORIZED", "session token payload is not valid");
  }
  if (payload.exp_ms <= Date.now()) {
    throw new BrokerError(401, "UNAUTHORIZED", "session token expired");
  }
  return payload;
}

function bearerTokenFrom(value: string | null): string | null {
  if (!value) return null;
  const match = value.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() || null;
}

async function signSessionPayload(payloadB64: string, secret: string): Promise<string> {
  const key = await globalThis.crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = await globalThis.crypto.subtle.sign("HMAC", key, new TextEncoder().encode(payloadB64));
  return base64UrlEncode(new Uint8Array(signature));
}

async function constantTimeEqual(left: string, right: string): Promise<boolean> {
  const leftDigest = await sha256Hex(left);
  const rightDigest = await sha256Hex(right);
  return leftDigest.length === rightDigest.length && leftDigest === rightDigest;
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
  const binary = globalThis.atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

function isSessionPayload(value: unknown): value is SessionTokenPayload {
  if (!isRecord(value)) return false;
  if (typeof value.account_id !== "string" || value.account_id.trim() === "") return false;
  if (value.device_id !== undefined && typeof value.device_id !== "string") return false;
  if (value.tier !== undefined && value.tier !== "free" && value.tier !== "pro") return false;
  if (typeof value.iat_ms !== "number" || !Number.isSafeInteger(value.iat_ms)) return false;
  if (typeof value.exp_ms !== "number" || !Number.isSafeInteger(value.exp_ms)) return false;
  return true;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
