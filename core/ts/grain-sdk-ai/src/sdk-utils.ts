import { createHash } from "node:crypto";

export function decodeB64(value: string): Uint8Array {
  return new Uint8Array(Buffer.from(value, "base64"));
}

export function encodeB64(bytes: Uint8Array): string {
  return Buffer.from(bytes).toString("base64");
}

export function isStrictBase64Standard(value: string): boolean {
  if (value.length === 0 || value.length % 4 !== 0) {
    return false;
  }
  if (!/^[A-Za-z0-9+/]*={0,2}$/.test(value)) {
    return false;
  }
  return encodeB64(decodeB64(value)) === value;
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

export function toUtf8(value: string): Uint8Array {
  return new TextEncoder().encode(value);
}
