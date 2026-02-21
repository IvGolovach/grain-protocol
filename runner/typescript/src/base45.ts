import { GrainDiagError } from "./types.ts";

const ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:";
const MAP = new Map<string, number>([...ALPHABET].map((c, i) => [c, i]));

export function base45Decode(input: string): Uint8Array {
  const out: number[] = [];
  let i = 0;
  while (i < input.length) {
    const remain = input.length - i;
    if (remain >= 3) {
      const c0 = getChar(input[i]);
      const c1 = getChar(input[i + 1]);
      const c2 = getChar(input[i + 2]);
      const v = c0 + c1 * 45 + c2 * 45 * 45;
      if (v > 0xffff) {
        throw new GrainDiagError("GRAIN_ERR_SCHEMA");
      }
      out.push((v >> 8) & 0xff, v & 0xff);
      i += 3;
      continue;
    }
    if (remain === 2) {
      const c0 = getChar(input[i]);
      const c1 = getChar(input[i + 1]);
      const v = c0 + c1 * 45;
      if (v > 0xff) {
        throw new GrainDiagError("GRAIN_ERR_SCHEMA");
      }
      out.push(v & 0xff);
      i += 2;
      continue;
    }
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }
  return new Uint8Array(out);
}

function getChar(c: string): number {
  const v = MAP.get(c);
  if (v === undefined) {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }
  return v;
}
