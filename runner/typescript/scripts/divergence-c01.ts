import { execFileSync } from "node:child_process";
import { writeFileSync } from "node:fs";

import { loadC01Vectors, runTsVector, stable } from "./shared.ts";

type RunnerJson = {
  vector_id: string;
  pass: boolean;
  diag: string[];
  out: Record<string, unknown>;
};

const vectors = loadC01Vectors();
const repo = process.cwd();

const vectorListPath = "runner/typescript/.c01-vectors.txt";
writeFileSync(`${vectorListPath}`, `${vectors.join("\n")}\n`, "utf-8");

const rustCommand = [
  "run",
  "--rm",
  "-v",
  `${repo}:/work`,
  "-w",
  "/work/core/rust",
  "rust:1.86",
  "bash",
  "-lc",
  "set -euo pipefail; export PATH=/usr/local/cargo/bin:$PATH; while IFS= read -r v; do out=$(cargo run -q -p grain-runner -- run --strict --vector \"/work/$v\"); printf '%s\\t%s\\n' \"$v\" \"$out\"; done < /work/runner/typescript/.c01-vectors.txt"
];

const rustRaw = execFileSync("docker", rustCommand, { encoding: "utf-8", maxBuffer: 20 * 1024 * 1024 });

const rustMap = new Map<string, RunnerJson>();
for (const line of rustRaw.split("\n")) {
  if (!line.trim()) continue;
  const tab = line.indexOf("\t");
  if (tab <= 0) continue;
  const path = line.slice(0, tab);
  const payload = line.slice(tab + 1);
  rustMap.set(path, JSON.parse(payload) as RunnerJson);
}

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
  profile: "c01",
  strict: true,
  total: vectors.length,
  mismatches: mismatches.length,
  items: mismatches
};

writeFileSync("runner/typescript/.divergence-c01.json", `${JSON.stringify(divergence, null, 2)}\n`, "utf-8");

const md = [
  "# C01 Divergence (Rust vs TS)",
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

writeFileSync("runner/typescript/.divergence-c01.md", `${md.join("\n")}\n`, "utf-8");
process.stdout.write(`${JSON.stringify(divergence, null, 2)}\n`);

if (mismatches.length > 0) {
  process.exit(1);
}
