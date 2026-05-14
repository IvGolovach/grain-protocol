import type { Json } from "grain-ts-core/types";
import type { TsCoreEngine } from "./engine.js";
import { SdkError } from "./errors.js";
import type { GrainSdkStore } from "./store.js";
import { encodeB64 } from "./utils.js";

export const GRAIN_SDK_AI_HOST: unique symbol = Symbol("grain.sdk.ai-host");

export interface GrainSdkAiHost {
  strictValidateDagCbor(bytes: Uint8Array): void;
  deriveCid(bytes: Uint8Array): string;
  putObject(cid: string, bytes: Uint8Array): Promise<void>;
}

export interface GrainSdkAiHostFactory {
  [GRAIN_SDK_AI_HOST](): GrainSdkAiHost;
}

export function createGrainSdkAiHost(core: TsCoreEngine, store: GrainSdkStore): GrainSdkAiHost {
  const deriveCid = (bytes: Uint8Array): string => {
    const out = core.execute("cid_derive", { bytes_b64: encodeB64(bytes) as Json }, true);
    const cid = out.out.cid;
    if (typeof cid !== "string" || cid.length === 0) {
      throw new SdkError("SDK_ERR_AI_CID_DERIVE", "cid_derive did not return string cid");
    }
    return cid;
  };

  return {
    strictValidateDagCbor(bytes: Uint8Array): void {
      core.execute("dagcbor_validate", { bytes_b64: encodeB64(bytes) as Json }, true);
    },

    deriveCid,

    async putObject(cid: string, bytes: Uint8Array): Promise<void> {
      const actualCid = deriveCid(bytes);
      if (actualCid !== cid) {
        throw new SdkError("SDK_ERR_AI_CID_MISMATCH", "AI object cid must match canonical bytes");
      }
      await store.objects.put(cid, bytes);
    }
  };
}
