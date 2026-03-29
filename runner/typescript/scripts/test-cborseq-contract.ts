import assert from "node:assert/strict";

import { executeOperation } from "../src/ops.js";
import type { Json } from "../src/types.js";

function main(): void {
  const cborseq = {
    stream_kind: "ledger",
    cborseq_b64: "oWFhAaFhYgI="
  } satisfies Record<string, Json>;

  const segments = {
    stream_kind: "ledger",
    segments_b64: ["oWFhAaFhYgI="]
  } satisfies Record<string, Json>;

  const emptySegments = {
    stream_kind: "manifest",
    segments_b64: []
  } satisfies Record<string, Json>;

  assert.deepEqual(
    executeOperation("parse_cborseq_stream_v1", cborseq, true),
    executeOperation("parse_cborseq_stream_v1", segments, true)
  );

  assert.deepEqual(
    executeOperation("parse_cborseq_stream_v1", emptySegments, true),
    {
      accepted: true,
      diag: [],
      out: { item_sha256_hex: [] }
    }
  );

  assert.throws(
    () =>
      executeOperation(
        "parse_cborseq_stream_v1",
        {
          stream_kind: "bogus",
          cborseq_b64: "oWFhAaFhYgI="
        } satisfies Record<string, Json>,
        true
      ),
    (err: unknown) => isDiagError(err, "GRAIN_ERR_SCHEMA")
  );

  assert.throws(
    () =>
      executeOperation(
        "parse_cborseq_stream_v1",
        {
          stream_kind: "ledger",
          cborseq_b64: "oWFhAaFhYgI=",
          segments_b64: ["oWFhAaFhYgI="]
        } satisfies Record<string, Json>,
        true
      ),
    (err: unknown) => isDiagError(err, "GRAIN_ERR_SCHEMA")
  );

  assert.throws(
    () =>
      executeOperation(
        "parse_cborseq_stream_v1",
        {
          stream_kind: "ledger"
        } satisfies Record<string, Json>,
        true
      ),
    (err: unknown) => isDiagError(err, "GRAIN_ERR_SCHEMA")
  );

  process.stdout.write("test-cborseq-contract: PASS\n");
}

function isDiagError(err: unknown, code: string): boolean {
  return err instanceof Error && "code" in err && (err as { code?: unknown }).code === code;
}

main();
