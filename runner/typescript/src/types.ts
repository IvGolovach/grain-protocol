export type Json = null | boolean | number | string | Json[] | { [k: string]: Json };

export type VectorFile = {
  vector_id: string;
  op: string;
  strict: boolean;
  input: Record<string, Json>;
  expect: {
    pass: boolean;
    diag_contains?: string[];
    out?: Record<string, Json>;
    out_equals?: Record<string, Json>;
  };
};

export type OperationActual = {
  accepted: boolean;
  diag: string[];
  out: Record<string, Json>;
};

export type RunnerOutput = {
  vector_id: string;
  pass: boolean;
  diag: string[];
  out: Record<string, Json>;
};

export type CborNode =
  | { kind: "u"; value: bigint }
  | { kind: "n"; value: bigint }
  | { kind: "b"; value: Uint8Array }
  | { kind: "t"; bytes: Uint8Array }
  | { kind: "a"; items: CborNode[] }
  | { kind: "m"; entries: { key: CborNode; keyBytes: Uint8Array; value: CborNode }[] }
  | { kind: "tag"; tag: bigint; inner: CborNode }
  | { kind: "bool"; value: boolean }
  | { kind: "null" }
  | { kind: "undef" }
  | { kind: "simple"; value: number };

export type ParseOptions = {
  enforceCanonical: boolean;
  dagCborStrict: boolean;
  allowOnlyTag42: boolean;
};

export class GrainDiagError extends Error {
  public readonly code: string;

  constructor(code: string, message?: string) {
    super(message ?? code);
    this.code = code;
    this.name = "GrainDiagError";
  }
}

export const LIMITS = {
  CBL_MAX_CBOR_NESTING_DEPTH: 32,
  CBL_MAX_CBOR_MAP_PAIRS: 4096,
  CBL_MAX_CBOR_ARRAY_LENGTH: 4096,
  CBL_MAX_TSTR_UTF8_BYTES: 1024,
  CBL_MAX_DAGCBOR_OBJECT_BYTES: 5_000_000,
  CBL_MAX_E2E_CIPHERTEXT_BYTES: 8_000_000,
  CBL_MAX_CBORSEQ_SEGMENT_BYTES: 64_000_000,
  CBL_MAX_CBORSEQ_SEGMENT_ITEMS: 1_000_000
} as const;
