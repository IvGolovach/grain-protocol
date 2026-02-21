#!/usr/bin/env node

import { readFileSync } from "node:fs";

import { evaluateVector } from "./expect.ts";
import { executeOperation } from "./ops.ts";
import { GrainDiagError } from "./types.ts";
import type { OperationActual, RunnerOutput, VectorFile } from "./types.ts";

function main(): void {
  const argv = process.argv.slice(2);
  if (argv.length < 4 || argv[0] !== "run") {
    printAndExit({ vector_id: "unknown", pass: false, diag: ["GRAIN_ERR_SCHEMA"], out: {} }, 1);
  }

  const strict = argv.includes("--strict");
  const vectorIdx = argv.indexOf("--vector");
  if (vectorIdx === -1 || !argv[vectorIdx + 1]) {
    printAndExit({ vector_id: "unknown", pass: false, diag: ["GRAIN_ERR_SCHEMA"], out: {} }, 1);
  }

  const vectorPath = argv[vectorIdx + 1];
  let vector: VectorFile;
  try {
    vector = JSON.parse(readFileSync(vectorPath, "utf-8")) as VectorFile;
  } catch {
    printAndExit({ vector_id: "unknown", pass: false, diag: ["GRAIN_ERR_SCHEMA"], out: {} }, 1);
    return;
  }

  let output: RunnerOutput;
  let actual: OperationActual;
  try {
    actual = executeOperation(vector.op, vector.input, strict && vector.strict === true);
  } catch (err) {
    const code = err instanceof GrainDiagError ? err.code : "GRAIN_ERR_SCHEMA";
    actual = {
      accepted: false,
      diag: [code],
      out: {}
    };
  }

  output = evaluateVector(vector, actual);
  printAndExit(output, output.pass ? 0 : 1);
}

function printAndExit(output: RunnerOutput, code: number): never {
  process.stdout.write(`${JSON.stringify(output)}\n`);
  process.exit(code);
}

main();
