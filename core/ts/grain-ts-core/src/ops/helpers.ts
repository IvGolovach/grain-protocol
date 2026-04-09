import { GrainDiagError } from "../types.js";
import type { Json } from "../types.js";
import { normalizeDiag } from "../utils.js";

export function textFromObjectField(obj: Record<string, Json>, key: string): string | undefined {
  const value = obj[key];
  if (value === undefined) {
    return undefined;
  }
  if (typeof value !== "string") {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }
  return value;
}

export function parseInteger(value: Json | undefined, code: string): bigint {
  if (typeof value === "number") {
    if (!Number.isSafeInteger(value)) {
      throw new GrainDiagError(code);
    }
    return BigInt(value);
  }

  if (typeof value === "string") {
    if (!/^-?[0-9]+$/.test(value)) {
      throw new GrainDiagError(code);
    }
    return BigInt(value);
  }

  throw new GrainDiagError(code);
}

export function toText(value: Json | undefined, code: string): string {
  if (typeof value !== "string") {
    throw new GrainDiagError(code);
  }
  return value;
}

export function toObject(value: Json | undefined, code: string): Record<string, Json> {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new GrainDiagError(code);
  }
  return value as Record<string, Json>;
}

export function withDiag(base: Record<string, Json>, diagnostics: string[]): Record<string, Json> {
  if (diagnostics.length === 0) {
    return base;
  }
  return {
    ...base,
    diag_contains: normalizeDiag(diagnostics)
  };
}
