import { executeOperation } from "../src/ops.js";
import type { Json } from "../src/types.js";

function expectDiag(name: string, run: () => void, expected: string): void {
  try {
    run();
  } catch (err) {
    if (err instanceof Error && "code" in err && (err as { code?: unknown }).code === expected) {
      return;
    }
    throw new Error(`${name}: expected ${expected}, got ${err instanceof Error ? err.message : String(err)}`);
  }
  throw new Error(`${name}: expected ${expected}, got success`);
}

expectDiag(
  "malformed e2e input base64",
  () =>
    executeOperation(
      "e2e_derive_v1",
      {
        sync_secret_b64: "!!!!",
        cap_id_b64: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
        cid_link_bstr_b64: "AAFx"
      } satisfies Record<string, Json>,
      true
    ),
  "GRAIN_ERR_SCHEMA"
);

expectDiag(
  "base64 trailing junk",
  () =>
    executeOperation(
      "dagcbor_validate",
      {
        bytes_b64: "AA==!!!!"
      } satisfies Record<string, Json>,
      true
    ),
  "GRAIN_ERR_SCHEMA"
);

expectDiag(
  "empty protocol base64",
  () =>
    executeOperation(
      "e2e_derive_v1",
      {
        sync_secret_b64: "",
        cap_id_b64: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
        cid_link_bstr_b64: "AAFx"
      } satisfies Record<string, Json>,
      true
    ),
  "GRAIN_ERR_SCHEMA"
);

process.stdout.write("test-base64-contract: PASS\n");
