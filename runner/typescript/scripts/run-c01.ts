import { writeFileSync } from "node:fs";

import { loadC01Vectors, runTsVector } from "./shared.ts";

const vectors = loadC01Vectors();

let passed = 0;
let failed = 0;
const failures: { vector: string; output: string }[] = [];

for (const vector of vectors) {
  try {
    const out = runTsVector(vector);
    const parsed = JSON.parse(out) as { pass: boolean };
    if (parsed.pass) {
      passed += 1;
    } else {
      failed += 1;
      failures.push({ vector, output: out });
    }
  } catch (err) {
    failed += 1;
    const output = err instanceof Error ? err.message : String(err);
    failures.push({ vector, output });
  }
}

const summary = {
  profile: "c01",
  strict: true,
  total: vectors.length,
  passed,
  failed,
  failures
};

writeFileSync("runner/typescript/.c01-last-run.json", `${JSON.stringify(summary, null, 2)}\n`, "utf-8");
process.stdout.write(`${JSON.stringify(summary, null, 2)}\n`);

if (failed > 0) {
  process.exit(1);
}
