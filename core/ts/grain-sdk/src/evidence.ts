import type { GrainSdkStore } from "./store.js";
import type { EvidenceBundle } from "./types.js";
import { encodeB64, sha256Hex, stableStringify, toUtf8, type Json } from "./utils.js";

export class EvidenceBuilder {
  private readonly store: GrainSdkStore;

  constructor(store: GrainSdkStore) {
    this.store = store;
  }

  async generateProofBundle(opts?: { commit_sha?: string; tag?: string; suite_summary?: Record<string, Json> }): Promise<EvidenceBundle> {
    const events = await this.store.events.list();
    const manifest = await this.store.manifest.listAll();
    const cids = await this.store.objects.listCids();
    const seqState = await this.store.sequence.snapshot();
    const identity = await this.store.identity.load();

    const manifestRows = manifest.map((r) => ({
      op: r.op,
      cid: r.cid,
      ak: r.ak,
      seq: r.seq.toString(),
      cap_id_b64: r.cap_id ? encodeB64(r.cap_id) : null,
      chash_b64: r.chash ? encodeB64(r.chash) : null,
      eligible: r.eligible !== false
    }));

    manifestRows.sort((a, b) => {
      const ka = `${a.cid}|${a.ak}|${a.seq}|${a.op}|${a.cap_id_b64 ?? ""}`;
      const kb = `${b.cid}|${b.ak}|${b.seq}|${b.op}|${b.cap_id_b64 ?? ""}`;
      return ka < kb ? -1 : ka > kb ? 1 : 0;
    });

    const eventRows = events
      .map((e) => ({ ...e, seq: e.seq.toString() }))
      .sort((a, b) => {
        const ka = `${a.ak}|${a.seq}|${a.payload_cid}|${a.t}`;
        const kb = `${b.ak}|${b.seq}|${b.payload_cid}|${b.t}`;
        return ka < kb ? -1 : ka > kb ? 1 : 0;
      });

    const summary: Record<string, Json> = {
      schema: "grain-sdk-proof-bundle-v1",
      commit_sha: opts?.commit_sha ?? "",
      tag: opts?.tag ?? "",
      strict: true,
      objects: {
        cids
      },
      events: {
        count: eventRows.length,
        rows: eventRows
      },
      manifest: {
        count: manifestRows.length,
        rows: manifestRows
      },
      identity: identity
        ? {
            root_kid: identity.root_kid,
            active_ak: identity.active_ak,
            device_count: identity.device_keys.length,
            revoked_count: identity.revoked_aks.length,
            seq_state: seqState
          }
        : { initialized: false },
      suite_summary: opts?.suite_summary ?? {}
    };

    const canonical = stableStringify(summary);
    const bytes = toUtf8(canonical);

    return {
      bytes,
      sha256_hex: sha256Hex(bytes),
      manifest: summary
    };
  }
}
