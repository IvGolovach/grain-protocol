import type { Json, OperationActual, RunnerOutput, VectorFile } from "./types.js";
import { normalizeDiag } from "./utils.js";

export function evaluateVector(vector: VectorFile, actual: OperationActual): RunnerOutput {
  const requiredDiags = new Set<string>(vector.expect.diag_contains ?? []);

  const expectedOut = vector.expect.out ?? vector.expect.out_equals;
  if (expectedOut && isObject(expectedOut)) {
    const fromOut = expectedOut.diag_contains;
    if (Array.isArray(fromOut)) {
      for (const d of fromOut) {
        if (typeof d === "string") requiredDiags.add(d);
      }
    }
  }

  let pass = true;
  if (actual.accepted !== vector.expect.pass) {
    pass = false;
  }

  if (expectedOut !== undefined && !subsetEqual(expectedOut, actual.out, true)) {
    pass = false;
  }

  const actualAllDiags = new Set<string>(normalizeDiag([...actual.diag, ...extractOutDiags(actual.out)]));
  for (const req of requiredDiags) {
    if (!actualAllDiags.has(req)) {
      pass = false;
      break;
    }
  }

  return {
    vector_id: vector.vector_id,
    pass,
    diag: normalizeDiag(actual.diag),
    out: actual.out
  };
}

function extractOutDiags(out: Record<string, Json>): string[] {
  const v = out.diag_contains;
  if (!Array.isArray(v)) return [];
  const codes: string[] = [];
  for (const x of v) {
    if (typeof x === "string") codes.push(x);
  }
  return codes;
}

function subsetEqual(expected: Json, actual: Json, skipDiagContains: boolean): boolean {
  if (isObject(expected) && isObject(actual)) {
    for (const [k, ev] of Object.entries(expected)) {
      if (skipDiagContains && k === "diag_contains") {
        continue;
      }
      if (!(k in actual)) {
        return false;
      }
      if (!subsetEqual(ev, (actual as Record<string, Json>)[k], skipDiagContains)) {
        return false;
      }
    }
    return true;
  }

  if (Array.isArray(expected) && Array.isArray(actual)) {
    if (expected.length !== actual.length) return false;
    for (let i = 0; i < expected.length; i += 1) {
      if (!subsetEqual(expected[i] as Json, actual[i] as Json, skipDiagContains)) {
        return false;
      }
    }
    return true;
  }

  return expected === actual;
}

function isObject(v: unknown): v is Record<string, Json> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}
