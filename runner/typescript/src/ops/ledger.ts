import { GrainDiagError } from "../types.js";
import type { Json, OperationActual } from "../types.js";
import { normalizeDiag } from "../utils.js";
import { parseInteger, textFromObjectField, toObject, toText } from "./helpers.js";

const I64_MIN = -(1n << 63n);
const I64_MAX = (1n << 63n) - 1n;

type LedgerEvent = {
  t: string;
  ak: string;
  seq: bigint;
  payloadCid: string;
  body: Record<string, Json>;
};

export function opLedgerReduce(input: Record<string, Json>): OperationActual {
  const rootKid = toText(input.root_kid, "GRAIN_ERR_SCHEMA");
  const events = parseLedgerEvents(input.events);

  const diagnostics = new Set<string>();
  const grants = new Set<string>();
  const revokes = new Set<string>();

  for (const ev of events) {
    if (ev.t === "DeviceKeyGrant") {
      if (ev.ak === rootKid) {
        const grantAk = textFromObjectField(ev.body, "grant_ak");
        if (grantAk) {
          grants.add(grantAk);
        }
      } else {
        diagnostics.add("UNAUTHORIZED_GRANT_IGNORED");
      }
    }

    if (ev.t === "DeviceKeyRevoke") {
      if (ev.ak === rootKid) {
        const revokeAk = textFromObjectField(ev.body, "revoke_ak");
        if (revokeAk) {
          revokes.add(revokeAk);
        }
      } else {
        diagnostics.add("UNAUTHORIZED_GRANT_IGNORED");
      }
    }
  }

  const isAuthorized = (ak: string): boolean => {
    if (ak === rootKid) {
      return true;
    }
    return grants.has(ak) && !revokes.has(ak);
  };

  const authorizedEvents: LedgerEvent[] = [];
  for (const ev of events) {
    if (!isAuthorized(ev.ak)) {
      if (revokes.has(ev.ak)) {
        diagnostics.add("AK_REVOKED");
      }
      continue;
    }
    authorizedEvents.push(ev);
  }

  const conflicted = collectConflictedSequences(authorizedEvents);
  if (conflicted.size > 0) {
    diagnostics.add("SEQ_CONFLICT");
  }

  let sumMean = 0n;
  let sumVar = 0n;
  const seenExact = new Set<string>();

  for (const ev of authorizedEvents) {
    const pairKey = sequenceKey(ev.ak, ev.seq);
    if (conflicted.has(pairKey)) {
      continue;
    }

    const exactKey = `${pairKey}\u0000${ev.payloadCid}`;
    if (seenExact.has(exactKey)) {
      continue;
    }
    seenExact.add(exactKey);

    if (ev.t !== "IntakeEvent") {
      continue;
    }

    const meanKcal = parseBodyI64(ev.body, ["mean", "kcal"]);
    const varKcal = parseBodyI64(ev.body, ["var", "kcal"]);
    if (varKcal < 0n) {
      throw new GrainDiagError("GRAIN_ERR_SCHEMA");
    }

    sumMean += meanKcal;
    sumVar += varKcal;
  }

  if (sumMean > I64_MAX || sumMean < I64_MIN) {
    throw new GrainDiagError("GRAIN_ERR_OVERFLOW");
  }
  if (sumVar > I64_MAX || sumVar < 0n) {
    throw new GrainDiagError("GRAIN_ERR_OVERFLOW");
  }

  const out: Record<string, Json> = {
    sum_mean: { kcal: Number(sumMean) },
    sum_var: { kcal: Number(sumVar) }
  };

  const diagContains = normalizeDiag([...diagnostics]);
  if (diagContains.length > 0) {
    out.diag_contains = diagContains;
  }

  return {
    accepted: true,
    diag: [],
    out
  };
}

function collectConflictedSequences(events: LedgerEvent[]): Set<string> {
  const pairPayloads = new Map<string, Set<string>>();
  for (const ev of events) {
    const key = sequenceKey(ev.ak, ev.seq);
    if (!pairPayloads.has(key)) {
      pairPayloads.set(key, new Set());
    }
    pairPayloads.get(key)?.add(ev.payloadCid);
  }

  const conflicted = new Set<string>();
  for (const [pairKey, payloads] of pairPayloads.entries()) {
    if (payloads.size > 1) {
      conflicted.add(pairKey);
    }
  }
  return conflicted;
}

function sequenceKey(ak: string, seq: bigint): string {
  return `${ak}\u0000${seq.toString()}`;
}

function parseLedgerEvents(value: Json | undefined): LedgerEvent[] {
  if (!Array.isArray(value)) {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }

  const out: LedgerEvent[] = [];
  for (const item of value) {
    if (item === null || typeof item !== "object" || Array.isArray(item)) {
      throw new GrainDiagError("GRAIN_ERR_SCHEMA");
    }

    const obj = item as Record<string, Json>;
    const t = toText(obj.t, "GRAIN_ERR_SCHEMA");
    const ak = toText(obj.ak, "GRAIN_ERR_SCHEMA");
    const payloadCid = toText(obj.payload_cid, "GRAIN_ERR_SCHEMA");
    const seq = parseInteger(obj.seq, "GRAIN_ERR_SCHEMA");
    if (seq < 0n) {
      throw new GrainDiagError("GRAIN_ERR_SCHEMA");
    }

    const body = toObject(obj.body, "GRAIN_ERR_SCHEMA");
    out.push({ t, ak, seq, payloadCid, body });
  }

  return out;
}

function parseBodyI64(body: Record<string, Json>, path: [string, string]): bigint {
  const l1 = body[path[0]];
  if (l1 === null || typeof l1 !== "object" || Array.isArray(l1)) {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }

  const obj = l1 as Record<string, Json>;
  const v = parseInteger(obj[path[1]], "GRAIN_ERR_SCHEMA");
  if (v < I64_MIN || v > I64_MAX) {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }
  return v;
}
