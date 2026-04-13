import { parseExactJson } from "./exact-json.js";
import type { VectorFile } from "./types.js";

export function parseVectorFile(text: string): VectorFile {
  return parseExactJson<VectorFile>(text);
}
