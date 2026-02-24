import type { Json } from "./utils.ts";
import { compareBytesLex, sha256Hex, toUtf8 } from "./utils.ts";
import { SdkError } from "./errors.ts";
import type { GrainSdkStore } from "./store.ts";
import type { AppendEventInput, LedgerEvent, ReduceResult } from "./types.ts";
import type { IdentityManager } from "./identity.ts";
import type { TsCoreEngine } from "./engine.ts";

export class EventLifecycle {
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

  async append(input: AppendEventInput): Promise<{ event: LedgerEvent; event_id: string }> {
    const ak = await this.identity.requireAuthorizedAk(input.ak);
    const seq = await this.store.sequence.reserveNextSeq(ak);

    const event: LedgerEvent = {
      t: input.t,
      ak,
      seq,
      payload_cid: input.payload_cid,
      body: { ...input.body }
    };

    await this.store.events.append(event);
    return { event, event_id: eventId(event) };
  }

  async void(targetEventId: string, reason = "void"): Promise<{ event: LedgerEvent; event_id: string }> {
    return this.append({
      t: "VoidEvent",
      payload_cid: `void:${targetEventId}`,
      body: { target: targetEventId, reason }
    });
  }

  async correct(targetEventId: string, replacementEvent: AppendEventInput, reason = "correction"): Promise<{ correction: LedgerEvent; replacement: LedgerEvent }> {
    const correction = await this.append({
      t: "CorrectionEvent",
      payload_cid: `corr:${targetEventId}`,
      body: { target: targetEventId, reason }
    });
    const replacement = await this.append(replacementEvent);
    return { correction: correction.event, replacement: replacement.event };
  }

  async merge(streamA: LedgerEvent[], streamB: LedgerEvent[]): Promise<LedgerEvent[]> {
    const byId = new Map<string, LedgerEvent>();
    for (const ev of [...streamA, ...streamB]) {
      byId.set(eventId(ev), { ...ev, body: { ...ev.body } });
    }

    const merged = [...byId.values()];
    merged.sort((a, b) => compareBytesLex(toUtf8(eventId(a)), toUtf8(eventId(b))));
    return merged;
  }

  async reduce(events?: LedgerEvent[]): Promise<ReduceResult> {
    const rootKid = await this.identity.getRootKid();
    const resolved = events ?? (await this.store.events.list());

    const opInput: Record<string, Json> = {
      root_kid: rootKid,
      events: resolved.map((ev) => ({
        t: ev.t,
        ak: ev.ak,
        seq: ev.seq.toString(),
        payload_cid: ev.payload_cid,
        body: ev.body
      }))
    };

    try {
      const actual = this.engine.execute("ledger_reduce", opInput, true);
      return {
        pass: actual.accepted,
        diag: [...actual.diag],
        out: actual.out
      };
    } catch (err) {
      const code = err instanceof SdkError ? err.code : "SDK_ERR_INTERNAL";
      return {
        pass: false,
        diag: [code],
        out: {}
      };
    }
  }

  async exportDeterministicCborSeq(events?: LedgerEvent[]): Promise<Uint8Array> {
    const resolved = events ?? (await this.store.events.list());
    const sorted = [...resolved].sort((a, b) => compareBytesLex(toUtf8(eventId(a)), toUtf8(eventId(b))));

    const rows = sorted
      .map((ev) => JSON.stringify({ ...ev, seq: ev.seq.toString() }))
      .join("\n");

    return toUtf8(rows);
  }
}

function eventId(ev: LedgerEvent): string {
  return sha256Hex(toUtf8(`${ev.ak}|${ev.seq.toString()}|${ev.payload_cid}|${ev.t}`));
}
