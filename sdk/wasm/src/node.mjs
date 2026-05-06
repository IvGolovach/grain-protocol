import { readFile } from "node:fs/promises";
import { WASI } from "node:wasi";

import { GrainClient } from "./index.mjs";

export async function createNodeGrainClient({ wasmPath } = {}) {
  if (typeof wasmPath !== "string" || wasmPath.trim().length === 0) {
    throw new TypeError("createNodeGrainClient requires wasmPath");
  }

  const wasmBytes = await readFile(wasmPath);
  const wasi = new WASI({ version: "preview1" });
  const wasm = await WebAssembly.instantiate(wasmBytes, wasi.getImportObject());
  wasi.initialize(wasm.instance);
  return new GrainClient(wasm.instance.exports);
}

export {
  GrainClient,
  GrainCustodyBinding,
  GrainCustodyMaterial,
  GrainCustodyPolicies,
  GrainStaticTrustProvider,
  redactGrainClientLogValue,
} from "./index.mjs";
export {
  GrainIndexedDBSnapshotPersistence,
  GrainMemorySnapshotPersistence,
  GrainSnapshotCoordinator,
  GrainSnapshotPersistenceError,
} from "./browser-storage.mjs";
