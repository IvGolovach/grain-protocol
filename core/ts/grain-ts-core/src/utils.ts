import { createHash } from "node:crypto";

import { GrainDiagError } from "./types.js";

type DecodeB64Options = {
  allowEmpty?: boolean;
};

export function decodeB64(value: unknown, options: DecodeB64Options = {}): Uint8Array {
  if (typeof value !== "string") {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }
  if (!isBase64Standard(value) || (options.allowEmpty === false && value.length === 0)) {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }
  return new Uint8Array(Buffer.from(value, "base64"));
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

function isBase64Standard(value: string): boolean {
  if (value.length === 0) return true;
  if (value.length % 4 !== 0) return false;
  if (!/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(value)) {
    return false;
  }
  return Buffer.from(value, "base64").toString("base64") === value;
}
