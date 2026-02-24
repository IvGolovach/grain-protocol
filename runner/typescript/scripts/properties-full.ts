import { writeFileSync } from "node:fs";

import { executeOperation } from "../src/ops.ts";
import { stable } from "./shared.ts";

const rng = makeRng(0x5eedc0de);

type LedgerEvent = {
  t: string;
  ak: string;
  seq: number;
  payload_cid: string;
  body: Record<string, unknown>;
};

const results: { name: string; cases: number; pass: boolean; failure?: string }[] = [];

runProperty("ledger_order_independence", 120, () => {
  const base = generateLedgerCase(rng);
  const shuffled = shuffle([...base], rng);

  const r1 = executeOperation("ledger_reduce", { root_kid: "root", events: base }, true);
  const r2 = executeOperation("ledger_reduce", { root_kid: "root", events: shuffled }, true);

  assertSameOperation(r1, r2, "ledger order independence mismatch");
});

runProperty("ledger_idempotence", 120, () => {
  const base = generateLedgerCase(rng);
  const dup = [...base, ...base];

  const r1 = executeOperation("ledger_reduce", { root_kid: "root", events: base }, true);
  const r2 = executeOperation("ledger_reduce", { root_kid: "root", events: dup }, true);

  assertSameOperation(r1, r2, "ledger idempotence mismatch");
});

runProperty("manifest_order_independence", 120, () => {
  const input = generateManifestCase(rng);

  const a = executeOperation("manifest_resolve", input, true);
  const b = executeOperation(
    "manifest_resolve",
    {
      ...input,
      eligible_records: shuffle([...(input.eligible_records as unknown[])], rng),
      eligible_tombstones: shuffle([...(input.eligible_tombstones as unknown[])], rng)
    },
    true
  );

  assertSameOperation(a, b, "manifest order independence mismatch");
});

runProperty("manifest_ineligible_exclusion", 120, () => {
  const input = generateManifestCase(rng);

  const withIneligible = executeOperation("manifest_resolve", input, true);
  const withoutIneligible = executeOperation(
    "manifest_resolve",
    {
      cid_b64: input.cid_b64,
      eligible_records: input.eligible_records,
      eligible_tombstones: input.eligible_tombstones,
      ineligible_records: [],
      ineligible_tombstones: []
    },
    true
  );

  assertSameOperation(withIneligible, withoutIneligible, "manifest ineligible exclusion mismatch");
});

const failed = results.filter((r) => !r.pass);
const summary = {
  profile: "full",
  strict: true,
  property_tests: results,
  failed: failed.length
};

writeFileSync("runner/typescript/.properties-full.json", `${JSON.stringify(summary, null, 2)}\n`, "utf-8");
process.stdout.write(`${JSON.stringify(summary, null, 2)}\n`);

if (failed.length > 0) {
  process.exit(1);
}

function runProperty(name: string, cases: number, fn: () => void): void {
  try {
    for (let i = 0; i < cases; i += 1) {
      fn();
    }
    results.push({ name, cases, pass: true });
  } catch (err) {
    results.push({ name, cases, pass: false, failure: err instanceof Error ? err.message : String(err) });
  }
}

function assertSameOperation(a: unknown, b: unknown, msg: string): void {
  if (stable(a) !== stable(b)) {
    throw new Error(msg);
  }
}

function generateLedgerCase(rand: () => number): LedgerEvent[] {
  const events: LedgerEvent[] = [
    {
      t: "DeviceKeyGrant",
      ak: "root",
      seq: 1,
      payload_cid: randomCid(rand),
      body: { grant_ak: "dev1" }
    }
  ];

  const intakeCount = 1 + Math.floor(rand() * 5);
  for (let i = 0; i < intakeCount; i += 1) {
    const conflict = rand() < 0.15;
    const seq = conflict ? 1 : i + 1;
    events.push({
      t: "IntakeEvent",
      ak: "dev1",
      seq,
      payload_cid: randomCid(rand),
      body: {
        mean: { kcal: Math.floor(rand() * 500) - 50 },
        var: { kcal: Math.floor(rand() * 40) }
      }
    });
  }

  if (rand() < 0.2) {
    events.push({
      t: "DeviceKeyRevoke",
      ak: "root",
      seq: 2,
      payload_cid: randomCid(rand),
      body: { revoke_ak: "dev1" }
    });
  }

  return events;
}

function generateManifestCase(rand: () => number): Record<string, unknown> {
  const cid = toB64(fillBytes(32, 0xaa));
  const eligibleRecords: Record<string, unknown>[] = [];
  const ineligibleRecords: Record<string, unknown>[] = [];

  const puts = 1 + Math.floor(rand() * 4);
  for (let i = 0; i < puts; i += 1) {
    eligibleRecords.push({
      op: "put",
      cap_id_b64: toB64(fillBytes(32, i + 1)),
      chash_b64: toB64(fillBytes(32, 10 + i))
    });
  }

  if (rand() < 0.35) {
    const cap = toB64(fillBytes(32, 1));
    eligibleRecords.push({ op: "put", cap_id_b64: cap, chash_b64: toB64(fillBytes(32, 200)) });
  }

  const ineligiblePuts = Math.floor(rand() * 3);
  for (let i = 0; i < ineligiblePuts; i += 1) {
    ineligibleRecords.push({
      op: "put",
      cap_id_b64: toB64(fillBytes(32, 100 + i)),
      chash_b64: toB64(fillBytes(32, 150 + i))
    });
  }

  const tombstones: Record<string, unknown>[] = rand() < 0.2 ? [{ op: "del" }] : [];
  const ineligibleTombstones: Record<string, unknown>[] = rand() < 0.2 ? [{ op: "del" }] : [];

  return {
    cid_b64: cid,
    eligible_records: eligibleRecords,
    eligible_tombstones: tombstones,
    ineligible_records: ineligibleRecords,
    ineligible_tombstones: ineligibleTombstones
  };
}

function makeRng(seed: number): () => number {
  let state = seed >>> 0;
  return () => {
    state = (state * 1664525 + 1013904223) >>> 0;
    return state / 0x100000000;
  };
}

function shuffle<T>(arr: T[], rand: () => number): T[] {
  for (let i = arr.length - 1; i > 0; i -= 1) {
    const j = Math.floor(rand() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

function randomCid(rand: () => number): string {
  const bytes = new Uint8Array(16);
  for (let i = 0; i < bytes.length; i += 1) {
    bytes[i] = Math.floor(rand() * 256);
  }
  return Buffer.from(bytes).toString("hex");
}

function fillBytes(n: number, seed: number): Uint8Array {
  const out = new Uint8Array(n);
  out.fill(seed & 0xff);
  return out;
}

function toB64(bytes: Uint8Array): string {
  return Buffer.from(bytes).toString("base64");
}
