#!/usr/bin/env node
import { readFileSync } from "node:fs";

import type { RunnerOutput, VectorFile } from "../../../../runner/typescript/src/types.ts";
import { GrainSdk } from "./sdk.ts";

function main(argv: string[]): number {
  const cmd = argv[2];
  if (cmd !== "run") {
    printAndExit({
      vector_id: "<none>",
      pass: false,
      diag: ["SDK_ERR_SCHEMA"],
      out: {}
    }, 2);
  }

  const strict = argv.includes("--strict");
  const vectorArgIdx = argv.indexOf("--vector");
  if (vectorArgIdx < 0 || vectorArgIdx + 1 >= argv.length) {
    printAndExit({
      vector_id: "<none>",
      pass: false,
      diag: ["SDK_ERR_SCHEMA"],
      out: {}
    }, 2);
  }

  const vectorPath = argv[vectorArgIdx + 1];
  const vector = JSON.parse(readFileSync(vectorPath, "utf8")) as VectorFile;

  const sdk = new GrainSdk();
  let output: RunnerOutput;
  try {
    sdk.core.assertStrictMode(strict && vector.strict === true);
    output = sdk.core.runVector(vector);
  } catch (err) {
    const code = err && typeof err === "object" && "code" in err && typeof (err as { code: unknown }).code === "string"
      ? (err as { code: string }).code
      : "SDK_ERR_INTERNAL";
    output = {
      vector_id: vector.vector_id,
      pass: false,
      diag: [code],
      out: {}
    };
  }

  printAndExit(output, output.pass ? 0 : 1);
}

function printAndExit(output: RunnerOutput, code: number): never {
  process.stdout.write(`${JSON.stringify(output)}\n`);
  process.exit(code);
}

main(process.argv);
