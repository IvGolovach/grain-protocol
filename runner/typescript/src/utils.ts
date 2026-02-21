import { createHash } from "node:crypto";

import { GrainDiagError } from "./types.ts";

export function decodeB64(value: unknown): Uint8Array {
  if (typeof value !== "string") {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }
  try {
    return new Uint8Array(Buffer.from(value, "base64"));
  } catch {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }
}

export function encodeB64(bytes: Uint8Array): string {
  return Buffer.from(bytes).toString("base64");
}

export function decodeUtf8(bytes: Uint8Array): string {
  try {
    return new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  } catch {
    throw new GrainDiagError("GRAIN_ERR_NONCANONICAL");
  }
}

export function compareBytesLex(a: Uint8Array, b: Uint8Array): number {
  const n = Math.min(a.length, b.length);
  for (let i = 0; i < n; i += 1) {
    if (a[i] < b[i]) return -1;
    if (a[i] > b[i]) return 1;
  }
  if (a.length < b.length) return -1;
  if (a.length > b.length) return 1;
  return 0;
}

export function compareCanonicalMapKey(a: Uint8Array, b: Uint8Array): number {
  if (a.length !== b.length) {
    return a.length < b.length ? -1 : 1;
  }
  return compareBytesLex(a, b);
}

export function sha256Hex(bytes: Uint8Array): string {
  return createHash("sha256").update(bytes).digest("hex");
}

export function sha256(bytes: Uint8Array): Uint8Array {
  return new Uint8Array(createHash("sha256").update(bytes).digest());
}

export function normalizeDiag(diag: string[]): string[] {
  return [...new Set(diag)].sort();
}

export function bytesEq(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i += 1) {
    if (a[i] !== b[i]) return false;
  }
  return true;
}
