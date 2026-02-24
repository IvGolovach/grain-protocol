import { executeOperation } from "../../../../runner/typescript/src/ops.ts";
import { evaluateVector } from "../../../../runner/typescript/src/expect.ts";
import type { Json, OperationActual, RunnerOutput, VectorFile } from "../../../../runner/typescript/src/types.ts";
import { SdkError, toSdkError } from "./errors.ts";

export class TsCoreEngine {
  execute(op: string, input: Record<string, Json>, strict = true): OperationActual {
    try {
      return executeOperation(op, input, strict);
    } catch (err) {
      throw toSdkError(err);
    }
  }

  runVector(vector: VectorFile): RunnerOutput {
    let actual: OperationActual;
    try {
      actual = this.execute(vector.op, vector.input, vector.strict === true);
    } catch (err) {
      const sdkErr = toSdkError(err);
      actual = {
        accepted: false,
        diag: [sdkErr.code],
        out: {}
      };
    }

    return evaluateVector(vector, actual);
  }

  assertStrictMode(strict: boolean): void {
    if (!strict) {
      throw new SdkError("SDK_ERR_STRICT_REQUIRED", "SDK runner requires strict mode");
    }
  }
}
