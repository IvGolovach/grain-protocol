import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { relative } from "node:path";

import { repoPath, repoRoot, runnerDistPath } from "./runtime.js";

type ProfileDef = {
  profile_id: string;
  vector_glob: string;
};

export function loadC01Vectors(): string[] {
  return loadProfileVectors(repoPath("runner", "typescript", "profiles", "c01.json"));
}

export function loadFullVectors(): string[] {
  return loadProfileVectors(repoPath("runner", "typescript", "profiles", "full.json"));
}

export function loadProfileVectors(profilePath: string): string[] {
  const profile = JSON.parse(readFileSync(profilePath, "utf-8")) as ProfileDef;

  let findArgs: string[];
  if (profile.vector_glob === "conformance/vectors/**/*-WA-*.json") {
    findArgs = ["conformance/vectors", "-name", "*-WA-*.json"];
  } else if (profile.vector_glob === "conformance/vectors/**/*.json") {
    findArgs = ["conformance/vectors", "-name", "*.json"];
  } else {
    throw new Error(`unsupported profile glob for ${profile.profile_id}: ${profile.vector_glob}`);
  }

  const raw = execFileSync("find", findArgs, { cwd: repoRoot, encoding: "utf-8" });
  return raw
    .split("\n")
    .map((s) => s.trim())
    .filter((s) => s.length > 0)
    .sort();
}

export function runTsVector(vectorPath: string): string {
  return execFileSync(
    process.execPath,
    [runnerDistPath("src", "cli.js"), "run", "--strict", "--vector", vectorPath],
    { cwd: repoRoot, encoding: "utf-8", env: { ...process.env, NODE_NO_WARNINGS: "1" } }
  ).trim();
}

export function stable(value: unknown): string {
  return JSON.stringify(sortValue(value));
}

export function writeVectorList(path: string, vectors: string[]): void {
  writeFileSync(path, `${vectors.join("\n")}\n`, "utf-8");
}

export function runRustVectors(vectors: string[], listPath: string): Map<string, RunnerJson> {
  writeVectorList(listPath, vectors);
  const listPathRel = relative(repoRoot, listPath);
  const rustBinary = process.env.GRAIN_RUST_RUNNER_BIN;
  if (rustBinary && rustBinary.length > 0) {
    const rustMap = new Map<string, RunnerJson>();
    for (const vectorPath of vectors) {
      const payload = execFileSync(
        rustBinary,
        ["run", "--strict", "--vector", vectorPath],
        { cwd: repoRoot, encoding: "utf-8", maxBuffer: 20 * 1024 * 1024 }
      ).trim();
      rustMap.set(vectorPath, JSON.parse(payload) as RunnerJson);
    }
    return rustMap;
  }

  const rustCommand = [
    "run",
    "--rm",
    "-v",
    `${repoRoot}:/work`,
    "-w",
    "/work/core/rust",
    "rust:1.86",
    "bash",
    "-lc",
    `set -euo pipefail; export PATH=/usr/local/cargo/bin:$PATH; while IFS= read -r v; do out=$(cargo run -q -p grain-runner -- run --strict --vector \"/work/$v\"); printf '%s\\t%s\\n' \"$v\" \"$out\"; done < /work/${listPathRel}`
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

  return rustMap;
}

function sortValue(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map(sortValue);
  }
  if (value && typeof value === "object") {
    const entries = Object.entries(value as Record<string, unknown>)
      .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
      .map(([k, v]) => [k, sortValue(v)]);
    return Object.fromEntries(entries);
  }
  return value;
}

export type RunnerJson = {
  vector_id: string;
  pass: boolean;
  diag: string[];
  out: Record<string, unknown>;
};
