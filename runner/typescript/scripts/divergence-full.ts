import { writeFileSync } from "node:fs";

import { loadFullVectors, runRustVectors, runTsVector, stable, type RunnerJson } from "./shared.ts";

const vectors = loadFullVectors();
const rustMap = runRustVectors(vectors, "runner/typescript/.full-vectors.txt");

const mismatches: {
  vector: string;
  kind: "missing_rust" | "parse" | "output";
  rust?: RunnerJson;
  ts?: RunnerJson;
  details?: string;
}[] = [];

for (const vector of vectors) {
  const rust = rustMap.get(vector);
  if (!rust) {
    mismatches.push({ vector, kind: "missing_rust" });
    continue;
  }

  let ts: RunnerJson;
  try {
    ts = JSON.parse(runTsVector(vector)) as RunnerJson;
  } catch (err) {
    mismatches.push({ vector, kind: "parse", rust, details: err instanceof Error ? err.message : String(err) });
    continue;
  }

  const samePass = rust.pass === ts.pass;
  const sameDiag = stable([...rust.diag].sort()) === stable([...ts.diag].sort());
  const sameOut = stable(rust.out) === stable(ts.out);

  if (!(samePass && sameDiag && sameOut)) {
    mismatches.push({ vector, kind: "output", rust, ts });
  }
}

const divergence = {
  profile: "full",
  strict: true,
  total: vectors.length,
  mismatches: mismatches.length,
  items: mismatches
};

writeFileSync("runner/typescript/.divergence-full.json", `${JSON.stringify(divergence, null, 2)}\n`, "utf-8");

const md = [
  "# Full Divergence (Rust vs TS)",
  "",
  `- Total vectors: ${vectors.length}`,
  `- Mismatches: ${mismatches.length}`,
  ""
];

if (mismatches.length === 0) {
  md.push("No divergences detected.");
} else {
  for (const m of mismatches) {
    md.push(`- ${m.vector}: ${m.kind}`);
    if (m.details) {
      md.push(`  - details: ${m.details}`);
    }
  }
}

writeFileSync("runner/typescript/.divergence-full.md", `${md.join("\n")}\n`, "utf-8");
process.stdout.write(`${JSON.stringify(divergence, null, 2)}\n`);

if (mismatches.length > 0) {
  process.exit(1);
}
