import { readFileSync } from "node:fs";

import { executeOperation } from "../src/ops.js";
import type { Json, VectorFile } from "../src/types.js";
import { decodeB64, encodeB64 } from "../src/utils.js";
import { parseVectorFile } from "../src/vector-json.js";
import { repoPath } from "./runtime.js";

const vector = parseVectorFile(
  readFileSync(repoPath("conformance", "vectors", "e2e", "NEG-E2E-WA-0004.json"), "utf8")
) as VectorFile;

const input = { ...vector.input } as Record<string, Json>;
const encrypted = decodeB64(input.encrypted_object_b64);
tamperCtBstrPayload(encrypted);
input.encrypted_object_b64 = encodeB64(encrypted);

expectDiag(() => executeOperation("e2e_decrypt", input, true), "NONCE_PROFILE_MISMATCH");

process.stdout.write("test-e2e-contract: PASS\n");

function expectDiag(run: () => void, expected: string): void {
  try {
    run();
  } catch (err) {
    if (err instanceof Error && "code" in err && (err as { code?: unknown }).code === expected) {
      return;
    }
    throw new Error(`expected ${expected}, got ${err instanceof Error ? err.message : String(err)}`);
  }
  throw new Error(`expected ${expected}, got success`);
}

function tamperCtBstrPayload(bytes: Uint8Array): void {
  const key = new Uint8Array([0x62, 0x63, 0x74]);
  const keyPos = findSubarray(bytes, key);
  if (keyPos < 0) {
    throw new Error("ct key not found");
  }
  const headerPos = keyPos + key.length;
  const { payloadPos, len } = readBstrPayload(bytes, headerPos);
  if (len === 0) {
    throw new Error("empty ct payload");
  }
  bytes[payloadPos] ^= 0x01;
}

function readBstrPayload(bytes: Uint8Array, headerPos: number): { payloadPos: number; len: number } {
  const header = bytes[headerPos];
  if ((header & 0xe0) !== 0x40) {
    throw new Error(`unexpected ct bstr header 0x${header.toString(16)}`);
  }

  const additional = header & 0x1f;
  if (additional < 24) {
    return checkedBstrPayload(bytes, headerPos + 1, additional);
  }
  if (additional === 24) {
    return checkedBstrPayload(bytes, headerPos + 2, bytes[headerPos + 1]);
  }
  if (additional === 25) {
    return checkedBstrPayload(bytes, headerPos + 3, (bytes[headerPos + 1] << 8) | bytes[headerPos + 2]);
  }
  if (additional === 26) {
    const len =
      bytes[headerPos + 1] * 0x1000000 +
      ((bytes[headerPos + 2] << 16) | (bytes[headerPos + 3] << 8) | bytes[headerPos + 4]);
    return checkedBstrPayload(bytes, headerPos + 5, len);
  }
  if (additional === 27) {
    const len =
      Number(bytes[headerPos + 1]) * 0x100000000000000 +
      Number(bytes[headerPos + 2]) * 0x1000000000000 +
      Number(bytes[headerPos + 3]) * 0x10000000000 +
      Number(bytes[headerPos + 4]) * 0x100000000 +
      Number(bytes[headerPos + 5]) * 0x1000000 +
      ((bytes[headerPos + 6] << 16) | (bytes[headerPos + 7] << 8) | bytes[headerPos + 8]);
    return checkedBstrPayload(bytes, headerPos + 9, len);
  }

  throw new Error(`unsupported ct bstr additional info ${additional}`);
}

function checkedBstrPayload(bytes: Uint8Array, payloadPos: number, len: number): { payloadPos: number; len: number } {
  if (!Number.isSafeInteger(len) || payloadPos + len > bytes.length) {
    throw new Error("ct bstr length exceeds envelope");
  }
  return { payloadPos, len };
}

function findSubarray(bytes: Uint8Array, needle: Uint8Array): number {
  for (let i = 0; i <= bytes.length - needle.length; i += 1) {
    let found = true;
    for (let j = 0; j < needle.length; j += 1) {
      if (bytes[i + j] !== needle[j]) {
        found = false;
        break;
      }
    }
    if (found) {
      return i;
    }
  }
  return -1;
}
