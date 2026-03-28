#!/usr/bin/env node
import { execFileSync, execSync } from "node:child_process";
import { resolve } from "node:path";

import { packageRoot, repoPath, repoRoot } from "./runtime.js";

const commitSha = execSync("git rev-parse HEAD", { cwd: repoRoot, encoding: "utf8" }).trim();
const out = repoPath("artifacts", "sdk-suite-summary.json");

execFileSync(
  "python3",
  [
    "tools/ci/run_runner_suite.py",
    "--vectors-root",
    "conformance/vectors",
    "--commit-sha",
    commitSha,
    "--out",
    out,
    "--runner-cmd",
    "node",
    resolve(packageRoot, "dist", "src", "cli.js"),
    "run",
    "--strict",
    "--vector"
  ],
  { cwd: repoRoot, stdio: "inherit" }
);
console.log(`SDK protocol suite summary: ${out}`);
