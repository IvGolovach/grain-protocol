import { inflateSync } from "node:zlib";

import { GrainDiagError, LIMITS } from "../types.js";
import type { Json, OperationActual, ParseOptions } from "../types.js";
import { base45Decode } from "../base45.js";
import { GENERIC_CBOR_LENIENT_OPTIONS, parseOne } from "../cbor.js";
import { decodeB64, encodeB64, sha256Hex } from "../utils.js";

export function opQrDecodeGr1(input: Record<string, Json>): OperationActual {
  const qr = input.qr_string;
  if (typeof qr !== "string") {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }
  if (!qr.startsWith("GR1:")) {
    throw new GrainDiagError("GRAIN_ERR_QR_PREFIX");
  }

  const body = qr.slice(4);
  const compressed = base45Decode(body);
  let cose: Uint8Array;
  try {
    cose = new Uint8Array(inflateSync(Buffer.from(compressed)));
  } catch {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }

  return {
    accepted: true,
    diag: [],
    out: {
      cose_b64: encodeB64(cose)
    }
  };
}

export function opParseCborSeq(input: Record<string, Json>): OperationActual {
  const streamKind = input.stream_kind;
  if (streamKind !== "ledger" && streamKind !== "manifest") {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }

  const hasCborseq = Object.hasOwn(input, "cborseq_b64");
  const hasSegments = Object.hasOwn(input, "segments_b64");
  if (hasCborseq === hasSegments) {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }

  const stream = hasCborseq
    ? decodeB64(input.cborseq_b64)
    : decodeSegments(input.segments_b64);

  if (stream.length > LIMITS.CBL_MAX_CBORSEQ_SEGMENT_BYTES) {
    throw new GrainDiagError("GRAIN_ERR_LIMIT");
  }

  const digests: string[] = [];
  if (stream.length === 0) {
    return { accepted: true, diag: [], out: { item_sha256_hex: digests } };
  }

  let pos = 0;
  while (pos < stream.length) {
    try {
      const parsed = parseOne(stream.slice(pos), GENERIC_CBOR_LENIENT_OPTIONS as ParseOptions);
      if (parsed.used <= 0) {
        throw invalidCborSeqTail(pos);
      }

      const item = stream.slice(pos, pos + parsed.used);
      digests.push(sha256Hex(item));
      pos += parsed.used;

      if (digests.length > LIMITS.CBL_MAX_CBORSEQ_SEGMENT_ITEMS) {
        throw new GrainDiagError("GRAIN_ERR_LIMIT");
      }
    } catch (err) {
      throw normalizeCborSeqError(err, pos);
    }
  }

  return { accepted: true, diag: [], out: { item_sha256_hex: digests } };
}

function decodeSegments(value: Json | undefined): Uint8Array {
  if (!Array.isArray(value)) {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }

  const all: number[] = [];
  for (const segment of value) {
    const bytes = decodeB64(segment);
    for (const byte of bytes) {
      all.push(byte);
    }
  }
  return new Uint8Array(all);
}

function invalidCborSeqTail(pos: number): GrainDiagError {
  return new GrainDiagError(pos === 0 ? "GRAIN_ERR_CBORSEQ_INVALID_INITIAL_BYTE" : "GRAIN_ERR_CBORSEQ_GARBAGE_TAIL");
}

function normalizeCborSeqError(err: unknown, pos: number): GrainDiagError {
  if (err instanceof GrainDiagError) {
    if (err.code === "GRAIN_ERR_CBORSEQ_TRUNCATED") {
      return err;
    }
    if (err.code === "CBOR_TRUNCATED_INTERNAL") {
      return new GrainDiagError("GRAIN_ERR_CBORSEQ_TRUNCATED");
    }
    if (err.code === "GRAIN_ERR_NONCANONICAL") {
      return invalidCborSeqTail(pos);
    }
    return err;
  }

  return new GrainDiagError("GRAIN_ERR_CBORSEQ_TRUNCATED");
}
