import type { Json, JsonInteger } from "./types.js";

type JsonParseContext = {
  source: string;
};

const MAX_SAFE_INTEGER = BigInt(Number.MAX_SAFE_INTEGER);
const MIN_SAFE_INTEGER = BigInt(Number.MIN_SAFE_INTEGER);

export function parseExactJson<T>(text: string): T {
  let sawSourceContext = false;
  const parsed = JSON.parse(text, function exactNumberReviverWithTracking(this: unknown, key: string, value: unknown, context?: JsonParseContext): unknown {
    const next = exactNumberReviver.call(this, key, value, context);
    if (context?.source) {
      sawSourceContext = true;
    }
    return next;
  }) as T;

  if (sawSourceContext) {
    return parsed;
  }

  return JSON.parse(rewriteUnsafeIntegerLiterals(text)) as T;
}

export function stringifyExactJson(value: unknown): string {
  return JSON.stringify(normalizeExactJsonValue(value));
}

export function stableExactJson(value: unknown): string {
  return stringifyExactJson(sortExactJsonValue(normalizeExactJsonValue(value)));
}

export function jsonIntegerFromBigInt(value: bigint): JsonInteger {
  const numberValue = Number(value);
  if (Number.isSafeInteger(numberValue)) {
    return numberValue;
  }
  return value.toString();
}

function exactNumberReviver(this: unknown, _key: string, value: unknown, context?: JsonParseContext): unknown {
  if (typeof value === "number") {
    if (context?.source && isUnsafeIntegerLiteral(context.source)) {
      return context.source;
    }
  }

  return value;
}

function rewriteUnsafeIntegerLiterals(text: string): string {
  let out = "";
  let i = 0;
  let inString = false;
  let escaped = false;

  while (i < text.length) {
    const ch = text[i];

    if (inString) {
      out += ch;
      if (escaped) {
        escaped = false;
      } else if (ch === "\\") {
        escaped = true;
      } else if (ch === "\"") {
        inString = false;
      }
      i += 1;
      continue;
    }

    if (ch === "\"") {
      inString = true;
      out += ch;
      i += 1;
      continue;
    }

    if (ch === "-" || isDigit(ch)) {
      const start = i;
      if (ch === "-") {
        i += 1;
      }

      if (text[i] === "0") {
        i += 1;
      } else {
        while (i < text.length && isDigit(text[i])) {
          i += 1;
        }
      }

      let isInteger = true;
      if (text[i] === ".") {
        isInteger = false;
        i += 1;
        while (i < text.length && isDigit(text[i])) {
          i += 1;
        }
      }

      if (text[i] === "e" || text[i] === "E") {
        isInteger = false;
        i += 1;
        if (text[i] === "+" || text[i] === "-") {
          i += 1;
        }
        while (i < text.length && isDigit(text[i])) {
          i += 1;
        }
      }

      const token = text.slice(start, i);
      if (isInteger && isUnsafeIntegerLiteral(token)) {
        out += `"${token}"`;
      } else {
        out += token;
      }
      continue;
    }

    out += ch;
    i += 1;
  }

  return out;
}

function normalizeExactJsonValue(value: unknown): unknown {
  if (typeof value === "bigint") {
    return jsonIntegerFromBigInt(value);
  }
  if (Array.isArray(value)) {
    return value.map((item) => normalizeExactJsonValue(item));
  }
  if (value && typeof value === "object") {
    const out: Record<string, Json> = {};
    for (const [key, item] of Object.entries(value as Record<string, unknown>)) {
      out[key] = normalizeExactJsonValue(item) as Json;
    }
    return out;
  }
  return value;
}

function sortExactJsonValue(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map((item) => sortExactJsonValue(item));
  }
  if (value && typeof value === "object") {
    const entries = Object.entries(value as Record<string, unknown>)
      .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
      .map(([key, item]) => [key, sortExactJsonValue(item)]);
    return Object.fromEntries(entries);
  }
  return value;
}

function isUnsafeIntegerLiteral(source: string): boolean {
  if (!/^-?(0|[1-9][0-9]*)$/.test(source)) {
    return false;
  }

  const value = BigInt(source);
  return value > MAX_SAFE_INTEGER || value < MIN_SAFE_INTEGER;
}

function isDigit(ch: string | undefined): boolean {
  return ch !== undefined && ch >= "0" && ch <= "9";
}
