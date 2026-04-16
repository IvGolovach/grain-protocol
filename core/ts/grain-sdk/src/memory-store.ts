import { SdkError } from "./errors.js";
import type { GrainSdkStore } from "./store.js";
import type { IdentityBundleV1, LedgerEvent, ManifestRecord } from "./types.js";
import { bytesEq, encodeB64 } from "./utils.js";

function keyHex(bytes: Uint8Array): string {
  return Buffer.from(bytes).toString("hex");
}

function copy(bytes: Uint8Array): Uint8Array {
  return new Uint8Array(bytes);
}

export class InMemorySdkStore implements GrainSdkStore {
  private readonly seqByAk = new Map<string, bigint>();
  private readonly eventsList: LedgerEvent[] = [];
  private readonly objectMap = new Map<string, Uint8Array>();
  private readonly blobMap = new Map<string, { ciphertext: Uint8Array; chash: Uint8Array }>();
  private readonly manifestList: ManifestRecord[] = [];
  private identityBundle: IdentityBundleV1 | null = null;
  private atomicDepth = 0;
  private atomicSnapshot: StoreSnapshot | null = null;

  public readonly atomic = async <T>(mutation: () => Promise<T>): Promise<T> => {
    const outermost = this.atomicDepth === 0;
    if (outermost) {
      this.atomicSnapshot = this.captureSnapshot();
    }
    this.atomicDepth += 1;
    try {
      const result = await mutation();
      this.atomicDepth -= 1;
      if (outermost) {
        this.atomicSnapshot = null;
      }
      return result;
    } catch (err) {
      this.atomicDepth -= 1;
      if (outermost && this.atomicSnapshot) {
        this.restoreSnapshot(this.atomicSnapshot);
        this.atomicSnapshot = null;
      }
      throw err;
    }
  };

  public readonly sequence = {
    reserveNextSeq: async (ak: string): Promise<bigint> => {
      const cur = this.seqByAk.get(ak) ?? 0n;
      const next = cur + 1n;
      this.seqByAk.set(ak, next);
      return next;
    },
    snapshot: async (): Promise<Record<string, string>> => {
      const out: Record<string, string> = {};
      for (const [k, v] of this.seqByAk.entries()) {
        out[k] = v.toString();
      }
      return out;
    },
    importSnapshot: async (snapshot: Record<string, string>): Promise<void> => {
      this.seqByAk.clear();
      for (const [k, v] of Object.entries(snapshot)) {
        this.seqByAk.set(k, BigInt(v));
      }
    }
  };

  public readonly events = {
    append: async (event: LedgerEvent): Promise<void> => {
      this.eventsList.push({ ...event, body: { ...event.body } });
    },
    list: async (): Promise<LedgerEvent[]> => this.eventsList.map((ev) => ({ ...ev, body: { ...ev.body } }))
  };

  public readonly objects = {
    put: async (cid: string, bytes: Uint8Array): Promise<void> => {
      this.objectMap.set(cid, copy(bytes));
    },
    get: async (cid: string): Promise<Uint8Array | null> => {
      const got = this.objectMap.get(cid);
      return got ? copy(got) : null;
    },
    listCids: async (): Promise<string[]> => [...this.objectMap.keys()].sort()
  };

  public readonly blobs = {
    put: async (capId: Uint8Array, ciphertext: Uint8Array, chash: Uint8Array): Promise<void> => {
      const k = keyHex(capId);
      const prev = this.blobMap.get(k);
      if (prev) {
        if (!bytesEq(prev.ciphertext, ciphertext) || !bytesEq(prev.chash, chash)) {
          throw new SdkError("SDK_ERR_CAP_OVERWRITE_OR_CORRUPTION", "cap_id single-assignment violated");
        }
        return;
      }
      this.blobMap.set(k, { ciphertext: copy(ciphertext), chash: copy(chash) });
    },
    get: async (capId: Uint8Array): Promise<{ ciphertext: Uint8Array; chash: Uint8Array } | null> => {
      const got = this.blobMap.get(keyHex(capId));
      if (!got) return null;
      return { ciphertext: copy(got.ciphertext), chash: copy(got.chash) };
    }
  };

  public readonly manifest = {
    append: async (record: ManifestRecord): Promise<void> => {
      this.manifestList.push({
        ...record,
        cap_id: record.cap_id ? copy(record.cap_id) : undefined,
        chash: record.chash ? copy(record.chash) : undefined,
        reason: record.reason
      });
    },
    listByCid: async (cid: string): Promise<ManifestRecord[]> => {
      return this.manifestList
        .filter((x) => x.cid === cid)
        .map((x) => ({ ...x, cap_id: x.cap_id ? copy(x.cap_id) : undefined, chash: x.chash ? copy(x.chash) : undefined }));
    },
    listAll: async (): Promise<ManifestRecord[]> => {
      return this.manifestList.map((x) => ({ ...x, cap_id: x.cap_id ? copy(x.cap_id) : undefined, chash: x.chash ? copy(x.chash) : undefined }));
    }
  };

  public readonly identity = {
    load: async (): Promise<IdentityBundleV1 | null> => {
      if (!this.identityBundle) return null;
      return JSON.parse(JSON.stringify(this.identityBundle)) as IdentityBundleV1;
    },
    save: async (bundle: IdentityBundleV1): Promise<void> => {
      this.identityBundle = JSON.parse(JSON.stringify(bundle)) as IdentityBundleV1;
      this.seqByAk.clear();
      for (const [ak, seq] of Object.entries(bundle.seq_state)) {
        this.seqByAk.set(ak, BigInt(seq));
      }
    }
  };

  public debugDumpBlobs(): Record<string, { ciphertext_b64: string; chash_b64: string }> {
    const out: Record<string, { ciphertext_b64: string; chash_b64: string }> = {};
    for (const [k, v] of this.blobMap.entries()) {
      out[k] = {
        ciphertext_b64: encodeB64(v.ciphertext),
        chash_b64: encodeB64(v.chash)
      };
    }
    return out;
  }

  private captureSnapshot(): StoreSnapshot {
    return {
      seqByAk: new Map(this.seqByAk),
      eventsList: this.eventsList.map((ev) => ({ ...ev, body: { ...ev.body } })),
      objectMap: new Map([...this.objectMap.entries()].map(([cid, bytes]) => [cid, copy(bytes)])),
      blobMap: new Map(
        [...this.blobMap.entries()].map(([cid, value]) => [
          cid,
          { ciphertext: copy(value.ciphertext), chash: copy(value.chash) }
        ])
      ),
      manifestList: this.manifestList.map((record) => ({
        ...record,
        cap_id: record.cap_id ? copy(record.cap_id) : undefined,
        chash: record.chash ? copy(record.chash) : undefined
      })),
      identityBundle: this.identityBundle ? (JSON.parse(JSON.stringify(this.identityBundle)) as IdentityBundleV1) : null
    };
  }

  private restoreSnapshot(snapshot: StoreSnapshot): void {
    this.seqByAk.clear();
    for (const [ak, seq] of snapshot.seqByAk.entries()) {
      this.seqByAk.set(ak, seq);
    }

    this.eventsList.splice(0, this.eventsList.length, ...snapshot.eventsList.map((ev) => ({ ...ev, body: { ...ev.body } })));

    this.objectMap.clear();
    for (const [cid, bytes] of snapshot.objectMap.entries()) {
      this.objectMap.set(cid, copy(bytes));
    }

    this.blobMap.clear();
    for (const [cid, value] of snapshot.blobMap.entries()) {
      this.blobMap.set(cid, { ciphertext: copy(value.ciphertext), chash: copy(value.chash) });
    }

    this.manifestList.splice(
      0,
      this.manifestList.length,
      ...snapshot.manifestList.map((record) => ({
        ...record,
        cap_id: record.cap_id ? copy(record.cap_id) : undefined,
        chash: record.chash ? copy(record.chash) : undefined
      }))
    );

    this.identityBundle = snapshot.identityBundle
      ? (JSON.parse(JSON.stringify(snapshot.identityBundle)) as IdentityBundleV1)
      : null;
  }
}

type StoreSnapshot = {
  seqByAk: Map<string, bigint>;
  eventsList: LedgerEvent[];
  objectMap: Map<string, Uint8Array>;
  blobMap: Map<string, { ciphertext: Uint8Array; chash: Uint8Array }>;
  manifestList: ManifestRecord[];
  identityBundle: IdentityBundleV1 | null;
};
