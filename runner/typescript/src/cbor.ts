import { GrainDiagError, LIMITS } from "./types.js";
import type { CborNode, ParseOptions } from "./types.js";
import { compareBytesLex, compareCanonicalMapKey, decodeUtf8 } from "./utils.js";

type ParseResult = {
  node: CborNode;
  used: number;
};

type ParserState = {
  bytes: Uint8Array;
  pos: number;
  options: ParseOptions;
};

export const STRICT_DAG_CBOR_OPTIONS: ParseOptions = {
  enforceCanonical: true,
  dagCborStrict: true,
  allowOnlyTag42: true
};

export const GENERIC_CBOR_CANONICAL_OPTIONS: ParseOptions = {
  enforceCanonical: true,
  dagCborStrict: false,
  allowOnlyTag42: false
};

export const GENERIC_CBOR_LENIENT_OPTIONS: ParseOptions = {
  enforceCanonical: false,
  dagCborStrict: false,
  allowOnlyTag42: false
};

export function parseOne(bytes: Uint8Array, options: ParseOptions): ParseResult {
  const st: ParserState = { bytes, pos: 0, options };
  const node = parseItem(st, 0);
  return { node, used: st.pos };
}

export function parseExact(bytes: Uint8Array, options: ParseOptions): CborNode {
  let parsed: ParseResult;
  try {
    parsed = parseOne(bytes, options);
  } catch (err) {
    if (err instanceof GrainDiagError && err.code === "CBOR_TRUNCATED_INTERNAL") {
      throw new GrainDiagError("GRAIN_ERR_NONCANONICAL");
    }
    throw err;
  }
  if (parsed.used !== bytes.length) {
    throw new GrainDiagError("GRAIN_ERR_NONCANONICAL");
  }
  return parsed.node;
}

export function encodeCanonical(node: CborNode): Uint8Array {
  const out: number[] = [];
  encodeNode(node, out);
  return new Uint8Array(out);
}

function encodeNode(node: CborNode, out: number[]): void {
  switch (node.kind) {
    case "u":
      writeTypeArg(0, node.value, out);
      return;
    case "n": {
      if (node.value >= 0n) {
        throw new GrainDiagError("GRAIN_ERR_SCHEMA");
      }
      writeTypeArg(1, -1n - node.value, out);
      return;
    }
    case "b":
      writeTypeArg(2, BigInt(node.value.length), out);
      pushBytes(out, node.value);
      return;
    case "t":
      writeTypeArg(3, BigInt(node.bytes.length), out);
      pushBytes(out, node.bytes);
      return;
    case "a":
      writeTypeArg(4, BigInt(node.items.length), out);
      for (const item of node.items) {
        encodeNode(item, out);
      }
      return;
    case "m":
      writeTypeArg(5, BigInt(node.entries.length), out);
      for (const entry of node.entries) {
        encodeNode(entry.key, out);
        encodeNode(entry.value, out);
      }
      return;
    case "tag":
      writeTypeArg(6, node.tag, out);
      encodeNode(node.inner, out);
      return;
    case "bool":
      out.push(node.value ? 0xf5 : 0xf4);
      return;
    case "null":
      out.push(0xf6);
      return;
    case "undef":
      out.push(0xf7);
      return;
    case "simple":
      if (node.value < 0 || node.value > 255) {
        throw new GrainDiagError("GRAIN_ERR_SCHEMA");
      }
      if (node.value < 24) {
        out.push(0xe0 | node.value);
      } else {
        out.push(0xf8, node.value);
      }
      return;
    default:
      throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }
}

function writeTypeArg(major: number, value: bigint, out: number[]): void {
  if (value < 0n) {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }

  const mt = (major & 0x07) << 5;
  if (value <= 23n) {
    out.push(mt | Number(value));
    return;
  }
  if (value <= 0xffn) {
    out.push(mt | 24);
    out.push(Number(value));
    return;
  }
  if (value <= 0xffffn) {
    out.push(mt | 25);
    out.push(Number((value >> 8n) & 0xffn));
    out.push(Number(value & 0xffn));
    return;
  }
  if (value <= 0xffffffffn) {
    out.push(mt | 26);
    for (let i = 3; i >= 0; i -= 1) {
      out.push(Number((value >> BigInt(i * 8)) & 0xffn));
    }
    return;
  }

  out.push(mt | 27);
  for (let i = 7; i >= 0; i -= 1) {
    out.push(Number((value >> BigInt(i * 8)) & 0xffn));
  }
}

function pushBytes(out: number[], bytes: Uint8Array): void {
  for (const b of bytes) {
    out.push(b);
  }
}

function parseItem(st: ParserState, depth: number): CborNode {
  if (depth > LIMITS.CBL_MAX_CBOR_NESTING_DEPTH) {
    throw new GrainDiagError("GRAIN_ERR_LIMIT");
  }
  const initial = readU8(st, "GRAIN_ERR_NONCANONICAL");
  const major = initial >> 5;
  const ai = initial & 0x1f;

  if (major === 0) {
    return { kind: "u", value: parseUintArg(st, ai) };
  }

  if (major === 1) {
    const v = parseUintArg(st, ai);
    return { kind: "n", value: -1n - v };
  }

  if (major === 2) {
    const len = toSafeNumber(parseUintArg(st, ai));
    const b = readExact(st, len, "GRAIN_ERR_NONCANONICAL");
    return { kind: "b", value: b };
  }

  if (major === 3) {
    const len = toSafeNumber(parseUintArg(st, ai));
    if (len > LIMITS.CBL_MAX_TSTR_UTF8_BYTES) {
      throw new GrainDiagError("GRAIN_ERR_LIMIT");
    }
    const b = readExact(st, len, "GRAIN_ERR_NONCANONICAL");
    decodeUtf8(b);
    return { kind: "t", bytes: b };
  }

  if (major === 4) {
    const len = toSafeNumber(parseUintArg(st, ai));
    if (len > LIMITS.CBL_MAX_CBOR_ARRAY_LENGTH) {
      throw new GrainDiagError("GRAIN_ERR_LIMIT");
    }
    const items: CborNode[] = [];
    for (let i = 0; i < len; i += 1) {
      items.push(parseItem(st, depth + 1));
    }
    return { kind: "a", items };
  }

  if (major === 5) {
    const len = toSafeNumber(parseUintArg(st, ai));
    if (len > LIMITS.CBL_MAX_CBOR_MAP_PAIRS) {
      throw new GrainDiagError("GRAIN_ERR_LIMIT");
    }

    const entries: { key: CborNode; keyBytes: Uint8Array; value: CborNode }[] = [];
    let prevKeyBytes: Uint8Array | null = null;
    const seen = new Set<string>();

    for (let i = 0; i < len; i += 1) {
      const keyStart = st.pos;
      const key = parseItem(st, depth + 1);
      const keyEnd = st.pos;
      const keyBytes = st.bytes.slice(keyStart, keyEnd);

      if (st.options.dagCborStrict && key.kind !== "t") {
        throw new GrainDiagError("GRAIN_ERR_NONCANONICAL");
      }

      const keyHex = Buffer.from(keyBytes).toString("hex");
      if (seen.has(keyHex)) {
        throw new GrainDiagError("GRAIN_ERR_DUP_MAP_KEY");
      }
      seen.add(keyHex);

      if (st.options.enforceCanonical && prevKeyBytes !== null) {
        const cmp = compareCanonicalMapKey(prevKeyBytes, keyBytes);
        if (cmp > 0) {
          throw new GrainDiagError("GRAIN_ERR_NONCANONICAL");
        }
        if (cmp === 0) {
          throw new GrainDiagError("GRAIN_ERR_DUP_MAP_KEY");
        }
      }
      prevKeyBytes = keyBytes;

      const value = parseItem(st, depth + 1);
      entries.push({ key, keyBytes, value });
    }

    return { kind: "m", entries };
  }

  if (major === 6) {
    const tag = parseUintArg(st, ai);
    if (st.options.allowOnlyTag42 && tag !== 42n) {
      throw new GrainDiagError("GRAIN_ERR_TAG_FORBIDDEN");
    }
    const inner = parseItem(st, depth + 1);
    if (st.options.dagCborStrict && tag === 42n) {
      if (inner.kind !== "b" || inner.value.length === 0 || inner.value[0] !== 0x00) {
        throw new GrainDiagError("GRAIN_ERR_BAD_CID_LINK");
      }
    }
    return { kind: "tag", tag, inner };
  }

  if (major === 7) {
    if (ai === 20) return { kind: "bool", value: false };
    if (ai === 21) return { kind: "bool", value: true };
    if (ai === 22) return { kind: "null" };
    if (ai === 23) return { kind: "undef" };
    if (ai === 24) {
      const v = readU8(st, "GRAIN_ERR_NONCANONICAL");
      return { kind: "simple", value: v };
    }
    if (ai === 25 || ai === 26 || ai === 27 || ai === 31) {
      throw new GrainDiagError("GRAIN_ERR_NONCANONICAL");
    }
    return { kind: "simple", value: ai };
  }

  throw new GrainDiagError("GRAIN_ERR_NONCANONICAL");
}

function parseUintArg(st: ParserState, ai: number): bigint {
  if (ai <= 23) {
    return BigInt(ai);
  }
  if (ai === 24) {
    const v = BigInt(readU8(st, "GRAIN_ERR_NONCANONICAL"));
    if (st.options.enforceCanonical && v < 24n) {
      throw new GrainDiagError("GRAIN_ERR_NONCANONICAL");
    }
    return v;
  }
  if (ai === 25) {
    const b = readExact(st, 2, "GRAIN_ERR_NONCANONICAL");
    const v = BigInt((b[0] << 8) | b[1]);
    if (st.options.enforceCanonical && v <= 0xffn) {
      throw new GrainDiagError("GRAIN_ERR_NONCANONICAL");
    }
    return v;
  }
  if (ai === 26) {
    const b = readExact(st, 4, "GRAIN_ERR_NONCANONICAL");
    const v = BigInt((b[0] * 2 ** 24) + (b[1] << 16) + (b[2] << 8) + b[3]);
    if (st.options.enforceCanonical && v <= 0xffffn) {
      throw new GrainDiagError("GRAIN_ERR_NONCANONICAL");
    }
    return v;
  }
  if (ai === 27) {
    const b = readExact(st, 8, "GRAIN_ERR_NONCANONICAL");
    let v = 0n;
    for (const x of b) {
      v = (v << 8n) | BigInt(x);
    }
    if (st.options.enforceCanonical && v <= 0xffffffffn) {
      throw new GrainDiagError("GRAIN_ERR_NONCANONICAL");
    }
    return v;
  }
  throw new GrainDiagError("GRAIN_ERR_NONCANONICAL");
}

function readU8(st: ParserState, code: string): number {
  if (st.pos >= st.bytes.length) {
    throw new GrainDiagError("CBOR_TRUNCATED_INTERNAL");
  }
  const b = st.bytes[st.pos];
  st.pos += 1;
  return b;
}

function readExact(st: ParserState, n: number, code: string): Uint8Array {
  if (st.bytes.length - st.pos < n) {
    throw new GrainDiagError("CBOR_TRUNCATED_INTERNAL");
  }
  const s = st.bytes.slice(st.pos, st.pos + n);
  st.pos += n;
  return s;
}

function toSafeNumber(v: bigint): number {
  const n = Number(v);
  if (!Number.isSafeInteger(n) || n < 0) {
    throw new GrainDiagError("GRAIN_ERR_LIMIT");
  }
  return n;
}

export function mapGet(node: CborNode, key: string): CborNode | undefined {
  if (node.kind !== "m") return undefined;
  const keyBytes = new TextEncoder().encode(key);
  for (const entry of node.entries) {
    if (entry.key.kind === "t" && compareBytesLex(entry.key.bytes, keyBytes) === 0) {
      return entry.value;
    }
  }
  return undefined;
}

export function nodeAsText(node: CborNode | undefined): string | undefined {
  if (!node || node.kind !== "t") return undefined;
  return decodeUtf8(node.bytes);
}

export function nodeAsU(node: CborNode | undefined): bigint | undefined {
  if (!node || node.kind !== "u") return undefined;
  return node.value;
}

export function nodeAsBytes(node: CborNode | undefined): Uint8Array | undefined {
  if (!node || node.kind !== "b") return undefined;
  return node.value;
}

export function validateSetArrayUtf8(node: CborNode, maxEntries?: number): { orderOk: boolean; uniqueOk: boolean } {
  if (node.kind !== "a") {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }
  if (maxEntries !== undefined && node.items.length > maxEntries) {
    throw new GrainDiagError("GRAIN_ERR_LIMIT");
  }

  let prev: Uint8Array | undefined;
  const seen = new Set<string>();

  for (const item of node.items) {
    if (item.kind !== "t") {
      throw new GrainDiagError("GRAIN_ERR_SCHEMA");
    }
    const cur = item.bytes;

    if (prev) {
      const cmp = compareBytesLex(prev, cur);
      if (cmp > 0) return { orderOk: false, uniqueOk: true };
      if (cmp === 0) return { orderOk: true, uniqueOk: false };
    }

    const key = Buffer.from(cur).toString("hex");
    if (seen.has(key)) {
      return { orderOk: true, uniqueOk: false };
    }
    seen.add(key);
    prev = cur;
  }

  return { orderOk: true, uniqueOk: true };
}
