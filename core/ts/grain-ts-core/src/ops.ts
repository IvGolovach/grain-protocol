import { GrainDiagError } from "./types.js";
import type { Json, OperationActual } from "./types.js";
import { opCoseVerify } from "./ops/cose.js";
import { opDagCborValidate, opCidDerive } from "./ops/dagcbor.js";
import { opE2eDecrypt, opE2eDerive } from "./ops/e2e.js";
import { opLedgerReduce } from "./ops/ledger.js";
import { opManifestResolve } from "./ops/manifest.js";
import { opParseCborSeq, opQrDecodeGr1 } from "./ops/transport.js";

type OperationHandler = (input: Record<string, Json>) => OperationActual;

const OPERATIONS: Record<string, OperationHandler> = {
  dagcbor_validate: opDagCborValidate,
  cid_derive: opCidDerive,
  cose_verify: opCoseVerify,
  qr_decode_gr1: opQrDecodeGr1,
  parse_cborseq_stream_v1: opParseCborSeq,
  ledger_reduce: opLedgerReduce,
  e2e_derive_v1: opE2eDerive,
  e2e_decrypt: opE2eDecrypt,
  manifest_resolve: opManifestResolve
};

export function executeOperation(op: string, input: Record<string, Json>, strict: boolean): OperationActual {
  if (!strict) {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }

  const handler = OPERATIONS[op];
  if (!handler) {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }
  return handler(input);
}
