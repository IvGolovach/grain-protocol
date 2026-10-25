import { readFileSync, statSync } from "node:fs";
import { verifySignedFoodTransfer } from "../src/signed-food.js";
import { GrainDiagError } from "grain-ts-core/types";

// Trust input is deliberately a separate, application-supplied file.
const [transfer, trustedRoot] = process.argv.slice(2);
try {
  if (!transfer || !trustedRoot || statSync(transfer).size > 16_000_000 || statSync(trustedRoot).size > 128) {
    throw new GrainDiagError("SDK_ERR_SIGNED_FOOD_INVALID");
  }
  const verified = verifySignedFoodTransfer(readFileSync(transfer, "utf8"), readFileSync(trustedRoot, "utf8").trim());
  console.log(JSON.stringify(verified));
} catch (error) {
  console.error(error instanceof GrainDiagError ? error.code : "SDK_ERR_SIGNED_FOOD_FILE");
  process.exitCode = 1;
}
