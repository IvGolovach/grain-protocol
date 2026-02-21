import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";

export function loadC01Vectors(): string[] {
  const profile = JSON.parse(readFileSync("runner/typescript/profiles/c01.json", "utf-8")) as {
    profile_id: string;
    vector_glob: string;
  };

  if (profile.profile_id !== "c01") {
    throw new Error("invalid c01 profile id");
  }

  const raw = execFileSync("find", ["conformance/vectors", "-name", "*-WA-*.json"], { encoding: "utf-8" });
  return raw
    .split("\n")
    .map((s) => s.trim())
    .filter((s) => s.length > 0)
    .sort();
}

export function runTsVector(vectorPath: string): string {
  return execFileSync(
    process.execPath,
    ["--experimental-strip-types", "runner/typescript/src/cli.ts", "run", "--strict", "--vector", vectorPath],
    { encoding: "utf-8", env: { ...process.env, NODE_NO_WARNINGS: "1" } }
  ).trim();
}

export function stable(value: unknown): string {
  return JSON.stringify(sortValue(value));
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
