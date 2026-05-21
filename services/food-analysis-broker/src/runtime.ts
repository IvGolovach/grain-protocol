import { BrokerError } from "./errors.js";

export type RuntimeEnv = {
  FDC_API_KEY?: string;
  FOOD_ANALYSIS_MOCK?: string;
  FOOD_ANALYSIS_TIMEOUT_MS?: string;
  FOOD_BROKER_DEV_TOKEN?: string;
  FOOD_NUTRITION_FIXTURES?: string;
  FOOD_SEARCH_FIXTURES?: string;
  FOOD_SEARCH_ALLOW_USDA_BARCODE_FALLBACK?: string;
  FOOD_SEARCH_LIVE?: string;
  FOOD_SEARCH_TIMEOUT_MS?: string;
  FOODDATA_CENTRAL_API_KEY?: string;
  APP_STORE_BUNDLE_ID?: string;
  APP_STORE_CONNECT_ISSUER_ID?: string;
  APP_STORE_CONNECT_KEY_ID?: string;
  APP_STORE_CONNECT_PRIVATE_KEY_P8?: string;
  APP_STORE_SERVER_API_BASE_URL?: string;
  APP_STORE_SERVER_ENVIRONMENT?: string;
  MEALMARK_AUTH_MODE?: string;
  MEALMARK_ALLOW_ANONYMOUS_FOOD_SEARCH?: string;
  MEALMARK_SESSION_HMAC_SECRET?: string;
  OPENAI_API_KEY?: string;
  OPENAI_MODEL?: string;
  OPEN_FOOD_FACTS_BASE_URL?: string;
  OPEN_FOOD_FACTS_USER_AGENT?: string;
  USDA_API_KEY?: string;
  USDA_FDC_BASE_URL?: string;
  [key: string]: unknown;
};

export function randomRequestId(): string {
  return globalThis.crypto?.randomUUID?.() ?? fallbackRandomId();
}

export async function sha256Hex(value: Uint8Array | string): Promise<string> {
  const bytes = typeof value === "string" ? new TextEncoder().encode(value) : value;
  const digest = await globalThis.crypto.subtle.digest("SHA-256", arrayBufferFrom(bytes));
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export async function sha256Hex16(value: Uint8Array | string): Promise<string> {
  return (await sha256Hex(value)).slice(0, 16);
}

export async function stableDigest(parts: string[]): Promise<string> {
  return (await sha256Hex(parts.join("\n"))).slice(0, 16);
}

export function decodeCanonicalBase64(value: string, fieldName: string): Uint8Array {
  if (!/^[A-Za-z0-9+/]*={0,2}$/.test(value) || value.length % 4 !== 0) {
    throw new BrokerError(400, "BAD_REQUEST", `${fieldName} must be canonical base64`);
  }
  try {
    const binary = globalThis.atob(value);
    if (binary.length === 0) {
      throw new Error("empty decoded bytes");
    }
    const bytes = new Uint8Array(binary.length);
    for (let index = 0; index < binary.length; index += 1) {
      bytes[index] = binary.charCodeAt(index);
    }
    return bytes;
  } catch {
    throw new BrokerError(400, "BAD_REQUEST", `${fieldName} could not be decoded`);
  }
}

function fallbackRandomId(): string {
  const random = new Uint8Array(16);
  globalThis.crypto.getRandomValues(random);
  random[6] = (random[6] & 0x0f) | 0x40;
  random[8] = (random[8] & 0x3f) | 0x80;
  const hex = Array.from(random).map((byte) => byte.toString(16).padStart(2, "0")).join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

function arrayBufferFrom(bytes: Uint8Array): ArrayBuffer {
  return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
}
