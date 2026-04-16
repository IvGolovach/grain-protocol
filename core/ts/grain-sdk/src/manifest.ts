import type { Json } from "./utils.js";
import { encodeB64 } from "./utils.js";
import type { GrainSdkStore } from "./store.js";
import type { ManifestRecord, ManifestResolution } from "./types.js";
import type { IdentityManager } from "./identity.js";
import type { TsCoreEngine } from "./engine.js";

export class ManifestManager {
  private readonly store: GrainSdkStore;
  private readonly identity: IdentityManager;
  private readonly engine: TsCoreEngine;

  constructor(
    store: GrainSdkStore,
    identity: IdentityManager,
    engine: TsCoreEngine
  ) {
    this.store = store;
    this.identity = identity;
    this.engine = engine;
  }

  async put(plaintextCid: string, capId: Uint8Array, chash: Uint8Array): Promise<ManifestRecord> {
    return this.store.atomic(async () => {
      const ak = await this.identity.requireAuthorizedAk();
      const seq = await this.store.sequence.reserveNextSeq(ak);

      const rec: ManifestRecord = {
        op: "put",
        cid: plaintextCid,
        ak,
        seq,
        cap_id: new Uint8Array(capId),
        chash: new Uint8Array(chash),
        eligible: true
      };
      await this.store.manifest.append(rec);
      return rec;
    });
  }

  async del(plaintextCid: string): Promise<ManifestRecord> {
    return this.store.atomic(async () => {
      const ak = await this.identity.requireAuthorizedAk();
      const seq = await this.store.sequence.reserveNextSeq(ak);

      const rec: ManifestRecord = {
        op: "del",
        cid: plaintextCid,
        ak,
        seq,
        eligible: true
      };
      await this.store.manifest.append(rec);
      return rec;
    });
  }

  async resolve(plaintextCid: string): Promise<ManifestResolution> {
    const all = await this.store.manifest.listByCid(plaintextCid);

    const eligible = all.filter((x) => x.eligible !== false);
    const ineligible = all.filter((x) => x.eligible === false);

    const eligiblePuts = eligible.filter((x) => x.op === "put");
    const eligibleDels = eligible.filter((x) => x.op === "del");
    const ineligiblePuts = ineligible.filter((x) => x.op === "put");
    const ineligibleDels = ineligible.filter((x) => x.op === "del");

    const input: Record<string, Json> = {
      cid_b64: encodeB64(new TextEncoder().encode(plaintextCid)),
      eligible_records: eligiblePuts.map((x) => ({
        op: "put",
        cap_id_b64: encodeB64(x.cap_id ?? new Uint8Array()),
        chash_b64: encodeB64(x.chash ?? new Uint8Array())
      })),
      eligible_tombstones: eligibleDels.map(() => ({ op: "del" })),
      ineligible_records: ineligiblePuts.map((x) => ({
        op: "put",
        cap_id_b64: encodeB64(x.cap_id ?? new Uint8Array()),
        chash_b64: encodeB64(x.chash ?? new Uint8Array())
      })),
      ineligible_tombstones: ineligibleDels.map(() => ({ op: "del" }))
    };

    const actual = this.engine.execute("manifest_resolve", input, true);
    const status = typeof actual.out.status === "string" ? actual.out.status : undefined;

    if (status === "UNRESOLVABLE") {
      if (eligibleDels.length > 0) {
        return { status: "tombstone", diag: actual.diag };
      }
      if (ineligible.some((x) => x.reason === "quarantined")) {
        return { status: "quarantined", diag: actual.diag };
      }
      if (ineligible.some((x) => x.reason === "conflicted_seq" || x.reason === "conflicted")) {
        return { status: "conflicted", diag: actual.diag };
      }
      return { status: "not_found", diag: actual.diag };
    }

    const capId = actual.out.cap_id_b64;
    if (typeof capId === "string") {
      return { status: "found", cap_id_b64: capId, diag: actual.diag };
    }

    return { status: "not_found", diag: actual.diag };
  }
}
