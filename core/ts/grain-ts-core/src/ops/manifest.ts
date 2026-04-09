import { GrainDiagError } from "../types.js";
import type { Json, OperationActual } from "../types.js";
import { compareBytesLex, decodeB64, encodeB64, normalizeDiag } from "../utils.js";
import { withDiag } from "./helpers.js";

type ManifestRecord = {
  op: "put" | "del";
  capId?: Uint8Array;
  chash?: Uint8Array;
};

export function opManifestResolve(input: Record<string, Json>): OperationActual {
  const eligibleRecords = parseManifestRecords(input.eligible_records);
  const eligibleTombstones = parseManifestRecords(input.eligible_tombstones);
  parseManifestRecords(input.ineligible_records);
  parseManifestRecords(input.ineligible_tombstones);

  if (eligibleTombstones.length > 0) {
    return { accepted: true, diag: [], out: { status: "UNRESOLVABLE" } };
  }

  const puts = eligibleRecords.filter((r) => r.op === "put");
  const capToChash = new Map<string, Set<string>>();

  for (const rec of puts) {
    const capHex = Buffer.from(rec.capId ?? new Uint8Array()).toString("hex");
    const chashHex = Buffer.from(rec.chash ?? new Uint8Array()).toString("hex");
    if (!capToChash.has(capHex)) {
      capToChash.set(capHex, new Set());
    }
    capToChash.get(capHex)?.add(chashHex);
  }

  const conflicted = new Set<string>();
  for (const [capHex, hashes] of capToChash.entries()) {
    if (hashes.size > 1) {
      conflicted.add(capHex);
    }
  }

  const diagnostics: string[] = [];
  const filtered = puts.filter((r) => !conflicted.has(Buffer.from(r.capId ?? new Uint8Array()).toString("hex")));
  if (conflicted.size > 0) {
    diagnostics.push("CAP_CHASH_CONFLICT");
  }

  if (filtered.length === 0) {
    return { accepted: true, diag: normalizeDiag(diagnostics), out: withDiag({ status: "UNRESOLVABLE" }, diagnostics) };
  }

  let min = filtered[0].capId ?? new Uint8Array();
  for (let i = 1; i < filtered.length; i += 1) {
    const cur = filtered[i].capId ?? new Uint8Array();
    if (compareBytesLex(cur, min) < 0) {
      min = cur;
    }
  }

  return {
    accepted: true,
    diag: normalizeDiag(diagnostics),
    out: withDiag({ cap_id_b64: encodeB64(min) }, diagnostics)
  };
}

function parseManifestRecords(value: Json | undefined): ManifestRecord[] {
  if (value === undefined) {
    return [];
  }
  if (!Array.isArray(value)) {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }

  const out: ManifestRecord[] = [];
  for (const rec of value) {
    if (rec === null || typeof rec !== "object" || Array.isArray(rec)) {
      throw new GrainDiagError("GRAIN_ERR_SCHEMA");
    }
    const record = rec as Record<string, Json>;
    const op = record.op;
    if (op !== "put" && op !== "del") {
      throw new GrainDiagError("GRAIN_ERR_MANIFEST_OP");
    }

    const cap = record.cap_id_b64 !== undefined ? decodeB64(record.cap_id_b64) : undefined;
    const chash = record.chash_b64 !== undefined ? decodeB64(record.chash_b64) : undefined;

    if (op === "put") {
      if (!cap || !chash) {
        throw new GrainDiagError("GRAIN_ERR_MANIFEST_OP");
      }
      out.push({ op, capId: cap, chash });
      continue;
    }

    if (cap || chash) {
      throw new GrainDiagError("GRAIN_ERR_MANIFEST_OP");
    }
    out.push({ op });
  }

  return out;
}
