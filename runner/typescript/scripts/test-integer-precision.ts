#!/usr/bin/env node

import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { parseExactJson } from "../src/exact-json.js";
import { parseVectorFile } from "../src/vector-json.js";
import { runTsVector } from "./shared.js";

type Check = {
  name: string;
  pass: boolean;
  detail?: string;
};

const checks: Check[] = [];

function ok(name: string): void {
  checks.push({ name, pass: true });
}

function fail(name: string, detail: string): void {
  checks.push({ name, pass: false, detail });
}

function run(): void {
  const tempDir = mkdtempSync(join(tmpdir(), "grain-ts-precision-"));

  try {
    runCase(tempDir, "seq-precision", SEQ_PRECISION_VECTOR, {
      sum_mean: { kcal: 3 },
      sum_var: { kcal: 0 }
    }, (parsed) => {
      const events = parsed.input.events as Array<Record<string, unknown>>;
      const firstIntake = events[1];
      const secondIntake = events[2];

      if (firstIntake?.seq !== "9007199254740992" || secondIntake?.seq !== "9007199254740993") {
        throw new Error("vector parser did not preserve exact seq values");
      }
    });

    runCase(tempDir, "body-precision", BODY_PRECISION_VECTOR, {
      sum_mean: { kcal: "9007199254740993" },
      sum_var: { kcal: 0 }
    }, (parsed) => {
      const events = parsed.input.events as Array<Record<string, unknown>>;
      const intake = events[1];
      const body = intake?.body as Record<string, unknown> | undefined;
      const mean = body?.mean as Record<string, unknown> | undefined;

      if (mean?.kcal !== "9007199254740993") {
        throw new Error("vector parser did not preserve exact body integer value");
      }
    }, (rawOutput) => {
      if (!rawOutput.includes("\"kcal\":\"9007199254740993\"")) {
        throw new Error(`runner output did not preserve unsafe integer as decimal string: ${rawOutput}`);
      }
    });

    runParsedRawDivergenceCase(
      "raw-output-divergence",
      "{\"vector_id\":\"X\",\"pass\":true,\"diag\":[],\"out\":{\"sum_mean\":{\"kcal\":9007199254740992}}}",
      "{\"vector_id\":\"X\",\"pass\":true,\"diag\":[],\"out\":{\"sum_mean\":{\"kcal\":9007199254740993}}}"
    );

    const failed = checks.filter((c) => !c.pass);
    process.stdout.write(`${JSON.stringify({ total: checks.length, failed: failed.length, checks }, null, 2)}\n`);
    process.exit(failed.length === 0 ? 0 : 1);
  } finally {
    rmSync(tempDir, { recursive: true, force: true });
  }
}

function runCase(
  tempDir: string,
  name: string,
  vectorText: string,
  expectedOut: Record<string, unknown>,
  assertParsedInput: (parsed: ReturnType<typeof parseVectorFile>) => void,
  assertRawOutput?: (rawOutput: string) => void
): void {
  const vectorPath = join(tempDir, `${name}.json`);
  writeFileSync(vectorPath, vectorText, "utf8");

  try {
    const parsed = parseVectorFile(vectorText);
    assertParsedInput(parsed);

    const rawOutput = runTsVector(vectorPath);
    assertRawOutput?.(rawOutput);

    const output = parseExactJson<{
      pass: boolean;
      diag: string[];
      out: Record<string, unknown>;
    }>(rawOutput);

    if (!output.pass) {
      fail(name, `runner reported failure: ${JSON.stringify(output)}`);
      return;
    }

    if (output.diag.length !== 0) {
      fail(name, `unexpected diagnostics: ${JSON.stringify(output.diag)}`);
      return;
    }

    if (!equalJsonLike(output.out, expectedOut)) {
      fail(name, `unexpected output: ${JSON.stringify(output.out)}`);
      return;
    }

    ok(name);
  } catch (err) {
    fail(name, err instanceof Error ? err.message : String(err));
  }
}

function runParsedRawDivergenceCase(name: string, leftRaw: string, rightRaw: string): void {
  try {
    const left = parseExactJson<{ out: unknown }>(leftRaw);
    const right = parseExactJson<{ out: unknown }>(rightRaw);

    if (equalJsonLike(left.out, right.out)) {
      throw new Error("exact JSON parsing still collapses distinct integer outputs");
    }

    ok(name);
  } catch (err) {
    fail(name, err instanceof Error ? err.message : String(err));
  }
}

const SEQ_PRECISION_VECTOR = `{
  "vector_id": "TMP-SEQ-PRECISION-1",
  "op": "ledger_reduce",
  "strict": true,
  "input": {
    "root_kid": "root",
    "events": [
      {
        "t": "DeviceKeyGrant",
        "ak": "root",
        "seq": 1,
        "payload_cid": "grant-cid",
        "body": { "grant_ak": "dev1" }
      },
      {
        "t": "IntakeEvent",
        "ak": "dev1",
        "seq": 9007199254740992,
        "payload_cid": "cid-a",
        "body": { "mean": { "kcal": 1 }, "var": { "kcal": 0 } }
      },
      {
        "t": "IntakeEvent",
        "ak": "dev1",
        "seq": 9007199254740993,
        "payload_cid": "cid-b",
        "body": { "mean": { "kcal": 2 }, "var": { "kcal": 0 } }
      }
    ]
  },
  "expect": {
    "pass": true,
    "out": {
      "sum_mean": { "kcal": 3 },
      "sum_var": { "kcal": 0 }
    }
  }
}`;

const BODY_PRECISION_VECTOR = `{
  "vector_id": "TMP-BODY-PRECISION-1",
  "op": "ledger_reduce",
  "strict": true,
  "input": {
    "root_kid": "root",
    "events": [
      {
        "t": "DeviceKeyGrant",
        "ak": "root",
        "seq": 1,
        "payload_cid": "grant-cid",
        "body": { "grant_ak": "dev1" }
      },
      {
        "t": "IntakeEvent",
        "ak": "dev1",
        "seq": 1,
        "payload_cid": "cid-a",
        "body": { "mean": { "kcal": 9007199254740993 }, "var": { "kcal": 0 } }
      },
      {
        "t": "IntakeEvent",
        "ak": "dev1",
        "seq": 2,
        "payload_cid": "cid-b",
        "body": { "mean": { "kcal": 0 }, "var": { "kcal": 0 } }
      }
    ]
  },
  "expect": {
    "pass": true
  }
}`;

run();

function equalJsonLike(actual: unknown, expected: unknown): boolean {
  if (expected === null || actual === null) {
    return actual === expected;
  }

  if (typeof expected === "string" && typeof actual === "number" && Number.isInteger(actual) && /^-?[0-9]+$/.test(expected)) {
    return expected === actual.toString();
  }

  if (Array.isArray(expected)) {
    if (!Array.isArray(actual) || actual.length !== expected.length) {
      return false;
    }
    for (let i = 0; i < expected.length; i += 1) {
      if (!equalJsonLike(actual[i], expected[i])) {
        return false;
      }
    }
    return true;
  }

  if (typeof expected === "object") {
    if (!actual || typeof actual !== "object" || Array.isArray(actual)) {
      return false;
    }
    const actualObj = actual as Record<string, unknown>;
    const expectedObj = expected as Record<string, unknown>;
    const actualKeys = Object.keys(actualObj);
    const expectedKeys = Object.keys(expectedObj);
    if (actualKeys.length !== expectedKeys.length) {
      return false;
    }
    for (const key of expectedKeys) {
      if (!equalJsonLike(actualObj[key], expectedObj[key])) {
        return false;
      }
    }
    return true;
  }

  return actual === expected;
}
