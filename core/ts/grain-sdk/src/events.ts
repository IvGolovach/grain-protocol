import type { Json } from "./utils.js";
import { compareBytesLex, sha256Hex, toUtf8 } from "./utils.js";
import { SdkError } from "./errors.js";
import type { GrainSdkStore } from "./store.js";
import type { AppendEventInput, LedgerEvent, ReduceResult } from "./types.js";
import type { IdentityManager } from "./identity.js";
import type { TsCoreEngine } from "./engine.js";

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
    const out: number[] = [];
    for (const ev of sorted) {
      encodeLedgerEvent(ev, out);
    }
    return new Uint8Array(out);
  }
}

function eventId(ev: LedgerEvent): string {
  return sha256Hex(toUtf8(`${ev.ak}|${ev.seq.toString()}|${ev.payload_cid}|${ev.t}`));
}

function encodeLedgerEvent(ev: LedgerEvent, out: number[]): void {
  encodeCanonicalMap(
    [
      { key: "ak", value: ev.ak },
      { key: "body", value: ev.body },
      { key: "payload_cid", value: ev.payload_cid },
      { key: "seq", value: ev.seq },
      { key: "t", value: ev.t }
    ],
    out
  );
}

function encodeJsonValue(value: Json, out: number[]): void {
  if (value === null) {
    out.push(0xf6);
    return;
  }

  if (typeof value === "boolean") {
    out.push(value ? 0xf5 : 0xf4);
    return;
  }

  if (typeof value === "string") {
    encodeText(value, out);
    return;
  }

  if (typeof value === "number") {
    if (!Number.isFinite(value)) {
      throw new SdkError("SDK_ERR_INTERNAL", "exportDeterministicCborSeq cannot encode non-finite numbers");
    }
    if (Number.isSafeInteger(value)) {
      if (value >= 0) {
        encodeUnsigned(BigInt(value), out);
      } else {
        encodeNegative(BigInt(value), out);
      }
      return;
    }

    pushFloat64(value, out);
    return;
  }

  if (Array.isArray(value)) {
    writeTypeArg(4, BigInt(value.length), out);
    for (const item of value) {
      encodeJsonValue(item as Json, out);
    }
    return;
  }

  if (value !== null && typeof value === "object") {
    encodeCanonicalMap(
      Object.entries(value as Record<string, Json>).map(([key, entry]) => ({ key, value: entry })),
      out
    );
    return;
  }

  throw new SdkError("SDK_ERR_INTERNAL", "exportDeterministicCborSeq encountered unsupported JSON value");
}

function encodeCanonicalMap(entries: Array<{ key: string; value: Json | bigint }>, out: number[]): void {
  const sorted = entries
    .map((entry) => ({
      ...entry,
      keyBytes: toUtf8(entry.key)
    }))
    .sort((a, b) => compareBytesLex(a.keyBytes, b.keyBytes));

  writeTypeArg(5, BigInt(sorted.length), out);
  for (const entry of sorted) {
    encodeText(entry.key, out);
    if (typeof entry.value === "bigint") {
      if (entry.value >= 0n) {
        encodeUnsigned(entry.value, out);
      } else {
        encodeNegative(entry.value, out);
      }
    } else {
      encodeJsonValue(entry.value, out);
    }
  }
}

function encodeText(value: string, out: number[]): void {
  const bytes = toUtf8(value);
  writeTypeArg(3, BigInt(bytes.length), out);
  pushBytes(out, bytes);
}

function encodeUnsigned(value: bigint, out: number[]): void {
  writeTypeArg(0, value, out);
}

function encodeNegative(value: bigint, out: number[]): void {
  writeTypeArg(1, -1n - value, out);
}

function pushFloat64(value: number, out: number[]): void {
  out.push(0xfb);
  const buf = Buffer.allocUnsafe(8);
  buf.writeDoubleBE(value, 0);
  pushBytes(out, buf);
}

function writeTypeArg(major: number, value: bigint, out: number[]): void {
  if (value < 0n) {
    throw new SdkError("SDK_ERR_INTERNAL", "exportDeterministicCborSeq encountered negative CBOR length");
  }

  const mt = (major & 0x07) << 5;
  if (value <= 23n) {
    out.push(mt | Number(value));
    return;
  }
  if (value <= 0xffn) {
    out.push(mt | 24);
    out.push(Number(value));
    return;
  }
  if (value <= 0xffffn) {
    out.push(mt | 25);
    out.push(Number((value >> 8n) & 0xffn));
    out.push(Number(value & 0xffn));
    return;
  }
  if (value <= 0xffffffffn) {
    out.push(mt | 26);
    for (let i = 3; i >= 0; i -= 1) {
      out.push(Number((value >> BigInt(i * 8)) & 0xffn));
    }
    return;
  }

  out.push(mt | 27);
  for (let i = 7; i >= 0; i -= 1) {
    out.push(Number((value >> BigInt(i * 8)) & 0xffn));
  }
}

function pushBytes(out: number[], bytes: Uint8Array): void {
  for (const b of bytes) {
    out.push(b);
  }
}
