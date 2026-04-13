import type { Json } from "grain-ts-core/types";
import type { TsCoreEngine } from "./engine.js";
import { SdkError } from "./errors.js";
import type { GrainSdkStore } from "./store.js";
import { encodeB64 } from "./utils.js";

export interface GrainSdkAiHost {
  strictValidateDagCbor(bytes: Uint8Array): void;
  deriveCid(bytes: Uint8Array): string;
  putObject(cid: string, bytes: Uint8Array): Promise<void>;
}

export interface GrainSdkAiHostFactory {
  createAiHost(): GrainSdkAiHost;
}

export function createGrainSdkAiHost(core: TsCoreEngine, store: GrainSdkStore): GrainSdkAiHost {
  return {
    strictValidateDagCbor(bytes: Uint8Array): void {
      core.execute("dagcbor_validate", { bytes_b64: encodeB64(bytes) as Json }, true);
    },

    deriveCid(bytes: Uint8Array): string {
      const out = core.execute("cid_derive", { bytes_b64: encodeB64(bytes) as Json }, true);
      const cid = out.out.cid;
      if (typeof cid !== "string" || cid.length === 0) {
        throw new SdkError("SDK_ERR_AI_CID_DERIVE", "cid_derive did not return string cid");
      }
      return cid;
    },

    async putObject(cid: string, bytes: Uint8Array): Promise<void> {
      await store.objects.put(cid, bytes);
    }
  };
}
