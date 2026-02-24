#!/usr/bin/env node
import { execSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";

const here = fileURLToPath(new URL(".", import.meta.url));
const root = resolve(here, "../../../../");
const commitSha = execSync("git rev-parse HEAD", { cwd: root, encoding: "utf8" }).trim();
const out = resolve(root, "artifacts/sdk-suite-summary.json");

const cmd = [
  "python3",
  "tools/ci/run_runner_suite.py",
  "--vectors-root",
  "conformance/vectors",
  "--commit-sha",
  commitSha,
  "--out",
  out,
  "--runner-cmd",
  "node",
  "--experimental-strip-types",
  "core/ts/grain-sdk/src/cli.ts",
  "run",
  "--strict",
  "--vector"
];

execSync(cmd.join(" "), { cwd: root, stdio: "inherit" });
console.log(`SDK protocol suite summary: ${out}`);
