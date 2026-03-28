#!/usr/bin/env node
import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { execSync } from "node:child_process";
import { WASI } from "node:wasi";

import { evaluateVector } from "../src/expect.js";
import type { Json, OperationActual, VectorFile } from "../src/types.js";
import { repoPath, repoRoot, runnerPath } from "./runtime.js";

type WasmExports = {
  memory: WebAssembly.Memory;
  grain_alloc: (len: number) => number;
  grain_dealloc: (ptr: number, len: number) => void;
  grain_run_vector: (ptr: number, len: number) => bigint | number;
};

function listVectors(root: string): Map<string, string> {
  const out = new Map<string, string>();
  const cmd = "find conformance/vectors -name '*.json' -type f | sort";
  const lines = execSync(cmd, { cwd: root, encoding: "utf8" })
    .split("\n")
    .map((x) => x.trim())
    .filter(Boolean);
  for (const rel of lines) {
    const full = resolve(root, rel);
    const vector = JSON.parse(readFileSync(full, "utf8")) as VectorFile;
    out.set(vector.vector_id, full);
  }
  return out;
}

function toActual(raw: unknown): OperationActual {
  if (typeof raw !== "object" || raw === null) {
    return { accepted: false, diag: ["GRAIN_ERR_SCHEMA"], out: {} };
  }
  const accepted = (raw as { accepted?: unknown }).accepted;
  const diag = (raw as { diag?: unknown }).diag;
  const out = (raw as { out?: unknown }).out;
  return {
    accepted: accepted === true,
    diag: Array.isArray(diag) ? diag.filter((d): d is string => typeof d === "string") : ["GRAIN_ERR_SCHEMA"],
    out: typeof out === "object" && out !== null && !Array.isArray(out) ? (out as Record<string, Json>) : {}
  };
}

function decodePacked(raw: bigint | number): { ptr: number; len: number } {
  const value = typeof raw === "bigint" ? raw : BigInt(raw);
  const ptr = Number((value >> 32n) & 0xffffffffn);
  const len = Number(value & 0xffffffffn);
  return { ptr, len };
}

function runVector(exportsObj: WasmExports, vector: VectorFile): OperationActual {
  const input = Buffer.from(JSON.stringify(vector), "utf8");
  const inputPtr = exportsObj.grain_alloc(input.length);
  const memoryIn = new Uint8Array(exportsObj.memory.buffer, inputPtr, input.length);
  memoryIn.set(input);

  const packed = exportsObj.grain_run_vector(inputPtr, input.length);
  exportsObj.grain_dealloc(inputPtr, input.length);

  const { ptr, len } = decodePacked(packed);
  const outBytes = Buffer.from(new Uint8Array(exportsObj.memory.buffer, ptr, len));
  exportsObj.grain_dealloc(ptr, len);
  return toActual(JSON.parse(outBytes.toString("utf8")));
}

async function main(): Promise<number> {
  const root = repoRoot;
  const profilePath = repoPath("runner", "typescript", "profiles", "wasm-subset.json");
  const wasmPath = repoPath("core", "rust", "target", "wasm32-wasip1", "release", "grain_core_wasm.wasm");
  const outPath = runnerPath(".wasm-subset-last-run.json");

  const profile = JSON.parse(readFileSync(profilePath, "utf8")) as { vector_ids: string[]; name?: string };
  const vectors = listVectors(root);

  const wasmBytes = readFileSync(wasmPath);
  const wasi = new WASI({ version: "preview1" });
  const wasm = await WebAssembly.instantiate(wasmBytes, wasi.getImportObject() as WebAssembly.Imports);
  wasi.initialize(wasm.instance as WebAssembly.Instance);
  const exportsObj = wasm.instance.exports as unknown as WasmExports;

  const failures: Array<{ vector_id: string; diag: string[]; out: unknown }> = [];
  let passed = 0;

  for (const id of profile.vector_ids) {
    const path = vectors.get(id);
    if (!path) {
      failures.push({ vector_id: id, diag: ["WASM_VECTOR_NOT_FOUND"], out: {} });
      continue;
    }
    const vector = JSON.parse(readFileSync(path, "utf8")) as VectorFile;
    const actual = runVector(exportsObj, vector);
    const verdict = evaluateVector(vector, actual);
    if (verdict.pass) {
      passed += 1;
    } else {
      failures.push({ vector_id: id, diag: verdict.diag, out: verdict.out });
    }
  }

  const summary = {
    profile: profile.name ?? "wasm-read-verify-v1",
    total: profile.vector_ids.length,
    passed,
    failed: failures.length,
    failures
  };

  writeFileSync(outPath, `${JSON.stringify(summary, null, 2)}\n`, "utf8");
  process.stdout.write(`${JSON.stringify(summary, null, 2)}\n`);
  return failures.length === 0 ? 0 : 1;
}

main().then((code) => process.exit(code));
