import { SdkError } from "./errors.js";
import { compareBytesLex } from "./utils.js";

type Brand<T, K extends string> = T & { readonly __brand: K };

export type Cid = Brand<string, "Cid">;
export type Kid = Brand<string, "Kid">;
export type CapId = Brand<Uint8Array, "CapId32">;
export type SetArray<T> = Brand<readonly T[], "SetArray">;

export function asCid(value: string): Cid {
  if (!value || value.length === 0) {
    throw new SdkError("SDK_ERR_CID_INVALID", "CID string must be non-empty");
  }
  return value as Cid;
}

export function asKid(value: string): Kid {
  if (!/^[0-9a-f]{32}$/i.test(value)) {
    throw new SdkError("SDK_ERR_KID_INVALID", "kid must be 16-byte hex (32 hex chars)");
  }
  return value.toLowerCase() as Kid;
}

export function asCapId(value: Uint8Array): CapId {
  if (value.length !== 32) {
    throw new SdkError("SDK_ERR_CAP_ID_LENGTH", "cap_id must be exactly 32 bytes");
  }
  return new Uint8Array(value) as CapId;
}

export function buildSetArray<T>(items: readonly T[], toBytes: (item: T) => Uint8Array): SetArray<T> {
  const rows = items.map((item) => ({ item, bytes: toBytes(item) }));
  rows.sort((a, b) => compareBytesLex(a.bytes, b.bytes));

  for (let i = 1; i < rows.length; i += 1) {
    const prev = rows[i - 1].bytes;
    const cur = rows[i].bytes;
    if (compareBytesLex(prev, cur) === 0) {
      throw new SdkError("GRAIN_ERR_SET_ARRAY_DUP", "duplicate item in set-array builder");
    }
  }

  return rows.map((r) => r.item) as unknown as SetArray<T>;
}
