import { createHash, randomBytes } from "node:crypto";

import { SdkError } from "./errors.js";

export type Json = null | boolean | number | string | Json[] | { [k: string]: Json };

export function decodeB64(value: string): Uint8Array {
  return new Uint8Array(Buffer.from(value, "base64"));
}

export function isBase64Standard(value: string): boolean {
  if (value.length === 0) {
    return true;
  }
  if (value.length % 4 !== 0) {
    return false;
  }
  if (!/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(value)) {
    return false;
  }
  return Buffer.from(value, "base64").toString("base64") === value;
}

export function requireBase64Standard(value: string, code: string, message: string): string {
  if (!isBase64Standard(value)) {
    throw new SdkError(code, message);
  }
  return value;
}

export function decodeB64Strict(value: string, code: string, message: string): Uint8Array {
  requireBase64Standard(value, code, message);
  return decodeB64(value);
}

export function encodeB64(bytes: Uint8Array): string {
  return Buffer.from(bytes).toString("base64");
}

export function sha256(bytes: Uint8Array): Uint8Array {
  return new Uint8Array(createHash("sha256").update(bytes).digest());
}

export function sha256Hex(bytes: Uint8Array): string {
  return Buffer.from(sha256(bytes)).toString("hex");
}

export function bytesEq(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i += 1) {
    if (a[i] !== b[i]) return false;
  }
  return true;
}

export function compareBytesLex(a: Uint8Array, b: Uint8Array): number {
  const n = Math.min(a.length, b.length);
  for (let i = 0; i < n; i += 1) {
    if (a[i] !== b[i]) return a[i] - b[i];
  }
  return a.length - b.length;
}

export function randomBytes32(): Uint8Array {
  try {
    return new Uint8Array(randomBytes(32));
  } catch {
    throw new SdkError("SDK_ERR_CSPRNG_UNAVAILABLE", "CSPRNG unavailable for cap_id generation");
  }
}

export function stableStringify(value: Json): string {
  return JSON.stringify(sortJson(value));
}

function sortJson(value: Json): Json {
  if (Array.isArray(value)) {
    return value.map((x) => sortJson(x as Json));
  }
  if (value !== null && typeof value === "object") {
    const entries = Object.entries(value as Record<string, Json>).sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0));
    const out: Record<string, Json> = {};
    for (const [k, v] of entries) {
      out[k] = sortJson(v);
    }
    return out;
  }
  return value;
}

export function toUtf8(s: string): Uint8Array {
  return new TextEncoder().encode(s);
}
