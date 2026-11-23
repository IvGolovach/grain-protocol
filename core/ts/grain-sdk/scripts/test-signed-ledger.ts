import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { GENERIC_CBOR_CANONICAL_OPTIONS, parseExact, STRICT_DAG_CBOR_OPTIONS } from "grain-ts-core/cbor";
import { deriveCidV1DagCborSha256 } from "grain-ts-core/ops/dagcbor";
import { GrainDiagError, type CborNode } from "grain-ts-core/types";
import {
  CidLink,
  coseAuthorKid,
  ed25519SignerFromSeed,
  encodeGrainValue,
  generateEd25519Signer,
  InMemorySignedLedgerStore,
  kidHex,
  SignedLedgerWriter,
  verifySignedLedgerTransfer,
  type GrainSigner,
  type GrainValue,
  type SignedLedgerStore
} from "../src/signed-ledger.js";
import { verifySignedFoodTransfer } from "../src/signed-food.js";

let checks = 0;
const b64 = (bytes: Uint8Array) => Buffer.from(bytes).toString("base64");
const TEST_CODES = { invalid: "TEST_INVALID", trust: "TEST_TRUST", limit: "TEST_LIMIT" };

function payloadOf(encoded: string): Uint8Array {
  const envelope = parseExact(Buffer.from(encoded, "base64"), GENERIC_CBOR_CANONICAL_OPTIONS);
  assert.ok(envelope.kind === "a" && envelope.items[2].kind === "b");
  return envelope.items[2].kind === "b" ? envelope.items[2].value : new Uint8Array();
}

function eventType(encoded: string): string {
  const node: CborNode = parseExact(payloadOf(encoded), STRICT_DAG_CBOR_OPTIONS);
  const t = node.kind === "m" ? node.entries.find((entry) => entry.key.kind === "t" && Buffer.from(entry.key.bytes).toString() === "t")?.value : undefined;
  return t?.kind === "t" ? Buffer.from(t.bytes).toString() : "";
}

async function rejectsWith(code: string, action: () => Promise<unknown> | unknown, label: string): Promise<void> {
  await assert.rejects(async () => { await action(); }, (error: unknown) => error instanceof GrainDiagError && error.code === code, label);
  checks++;
}

function counting(signer: GrainSigner): GrainSigner & { calls: number } {
  const wrapped = { publicKey: signer.publicKey, calls: 0, sign: async (message: Uint8Array) => { wrapped.calls++; return signer.sign(message); } };
  return wrapped;
}

class FlakyStore implements SignedLedgerStore {
  readonly inner = new InMemorySignedLedgerStore();
  failSaves = new Set<number>();
  failLoads = false;
  saves = 0;
  async load(): Promise<string | null> {
    if (this.failLoads) throw new Error("load failed");
    return this.inner.load();
  }
  async save(snapshot: string): Promise<void> {
    this.saves++;
    if (this.failSaves.has(this.saves)) throw new Error("save failed");
    await this.inner.save(snapshot);
  }
}

// Deterministic seeds keep payload CIDs stable across runs; never application keys.
const root = ed25519SignerFromSeed(new Uint8Array(32).fill(71));
const device = ed25519SignerFromSeed(new Uint8Array(32).fill(72));
const rootB64 = b64(root.publicKey);

const profile: GrainValue = {
  v: 1, t: "NutrientProfile", dataset_snapshot_id: "app-estimate-v1", source: "estimated",
  basis: "per_serving", nutr: { kcal: 640 }, uncert: { kcal: 36 }
};
const profileLink = CidLink.to(encodeGrainValue(profile));
const intake = (kcal: number, variance: number, link = profileLink): GrainValue => ({
  v: 1, t: "IntakeEvent", source_class: "estimated", mode: "from_profile", profile: link, servings: 1,
  mean: { kcal }, var: { kcal: variance }
});

// --- Happy path, restart, idempotency -----------------------------------------
const store = new InMemorySignedLedgerStore();
const writer = await SignedLedgerWriter.open({ trustedRootPublicKey: root.publicKey, store });
assert.equal(writer.initialized, false);
await rejectsWith("SDK_ERR_SIGNED_LEDGER_UNINITIALIZED", () => writer.exportTransfer(), "export before genesis");
await rejectsWith("SDK_ERR_SIGNED_LEDGER_UNINITIALIZED", () => writer.grantDevice(root, { operationId: "g", devicePublicKey: device.publicKey }), "grant before genesis");
await rejectsWith("SDK_ERR_SIGNED_LEDGER_TRUST", () => writer.initialize(device), "genesis by a non-root key");

const genesis = await writer.initialize(root);
assert.deepEqual([genesis.status, genesis.seq, genesis.t], ["committed", 0n, "LedgerGenesis"]);
assert.equal((await writer.initialize(root)).status, "already_committed");
checks += 2;

await rejectsWith("SDK_ERR_UNAUTHORIZED_AK", () => writer.append(device, { operationId: "early", t: "IntakeEvent", body: intake(1, 0), objects: [profile] }), "ungranted device");
const grant = await writer.grantDevice(root, { operationId: "grant-phone", devicePublicKey: device.publicKey });
assert.equal(grant.seq, 1n);
await rejectsWith("SDK_ERR_UNAUTHORIZED_AK", () => writer.grantDevice(device, { operationId: "self", devicePublicKey: device.publicKey }), "device cannot grant");

const meal = await writer.append(device, { operationId: "meal-001", t: "IntakeEvent", body: intake(640, 36), objects: [profile], tsMs: 1767225600000 });
assert.deepEqual([meal.status, meal.seq, meal.ak], ["committed", 1n, kidHex(device.publicKey)]);
const retry = await writer.append(device, { operationId: "meal-001", t: "IntakeEvent", body: intake(640, 36), objects: [profile], tsMs: 1767225600000 });
assert.deepEqual([retry.status, retry.payloadCid, retry.seq], ["already_committed", meal.payloadCid, 1n]);
checks += 2;
await rejectsWith("SDK_ERR_SIGNED_LEDGER_OPERATION_CONFLICT",
  () => writer.append(device, { operationId: "meal-001", t: "IntakeEvent", body: intake(700, 36), objects: [profile] }), "changed input under a committed ID");

const opaque = await writer.append(device, { operationId: "count-001", t: "InventoryCountEvent", body: {
  source_class: "counted", sku: "sku-001", quantity_count: 42, unit: "each", observed_at_ms: 1767225600000,
  // Kcal-shaped fields on an unknown type must not reach totals (NES §6.9).
  mean: { kcal: 1_000_000 }, var: { kcal: 1 }
} });
const voided = await writer.append(device, { operationId: "void-001", t: "VoidEvent", body: {
  v: 1, t: "VoidEvent", target: { ak: Buffer.from(meal.ak, "hex"), seq: meal.seq }, reason: "duplicate entry"
} });
assert.deepEqual([opaque.seq, voided.seq], [2n, 3n]);
checks++;
await rejectsWith("SDK_ERR_SIGNED_LEDGER_INVALID", () => writer.append(device, { operationId: "fake-grant", t: "DeviceKeyGrant", body: {} }), "root-only type through append");
await rejectsWith("GRAIN_ERR_SCHEMA", () => writer.append(device, { operationId: "bad-void", t: "VoidEvent", body: { v: 1, t: "VoidEvent" } }), "known type must match CDDL");
await rejectsWith("SDK_ERR_SIGNED_LEDGER_INVALID", () => writer.append(device, { operationId: "bad id!", t: "Note", body: {} }), "operation ID format");

const transfer = await writer.exportTransfer();
const verified = verifySignedLedgerTransfer(transfer, rootB64);
assert.equal(verified.rootKid, kidHex(root.publicKey));
assert.equal(verified.events.length, 5);
assert.deepEqual(verified.events.map((event) => event.payloadCid), [...verified.events.map((event) => event.payloadCid)].sort());
assert.deepEqual(new Set(verified.events.map((event) => event.t)), new Set(["LedgerGenesis", "DeviceKeyGrant", "IntakeEvent", "InventoryCountEvent", "VoidEvent"]));
assert.ok(verified.events.every((event) => event.status === "counted"));
assert.deepEqual([verified.sumMeanKcal, verified.sumVarKcal, verified.diagnostics], [640, 36, []]);
assert.deepEqual(verified.authorizedAks, [kidHex(root.publicKey), kidHex(device.publicKey)].sort());
assert.deepEqual(Object.keys(verified.objects), [profileLink.cid]);
const mealEvent = verified.events.find((event) => event.payloadCid === meal.payloadCid)!;
assert.equal(mealEvent.tsMs, 1767225600000n);
assert.ok(((mealEvent.body as Record<string, GrainValue>).profile as CidLink).cid === profileLink.cid);
checks += 11;

const reopened = await SignedLedgerWriter.open({ trustedRootPublicKey: root.publicKey, store });
assert.equal(await reopened.exportTransfer(), transfer);
assert.equal((await reopened.append(device, { operationId: "meal-001", t: "IntakeEvent", body: intake(640, 36), objects: [profile], tsMs: 1767225600000 })).status, "already_committed");
const afterRestart = await reopened.append(device, { operationId: "meal-002", t: "IntakeEvent", body: intake(320, 16), objects: [profile] });
assert.equal(afterRestart.seq, 4n);
checks += 3;
await rejectsWith("SDK_ERR_SIGNED_LEDGER_INVALID", () => SignedLedgerWriter.open({ trustedRootPublicKey: device.publicKey, store }), "snapshot under another root");

// The food profile verifier rejects generic ledgers it does not cover.
assert.throws(() => verifySignedFoodTransfer(transfer, rootB64), (error: unknown) => error instanceof GrainDiagError && error.code.startsWith("SDK_ERR_SIGNED_FOOD_"));
checks++;

// --- Revocation is retroactive ------------------------------------------------
await reopened.revokeDevice(root, { operationId: "revoke-phone", ak: kidHex(device.publicKey) });
const revoked = verifySignedLedgerTransfer(await reopened.exportTransfer(), rootB64);
assert.deepEqual([revoked.sumMeanKcal, revoked.diagnostics], [0, ["AK_REVOKED"]]);
assert.ok(revoked.events.filter((event) => event.ak === kidHex(device.publicKey)).every((event) => event.status === "unauthorized"));
assert.deepEqual(revoked.revokedAks, [kidHex(device.publicKey)]);
checks += 3;
await rejectsWith("SDK_ERR_UNAUTHORIZED_AK", () => reopened.append(device, { operationId: "late", t: "Note", body: { text: "after revoke" } }), "revoked device");
await rejectsWith("SDK_ERR_SIGNED_LEDGER_INVALID", () => reopened.grantDevice(root, { operationId: "regrant", devicePublicKey: device.publicKey }), "re-grant of a revoked key");
await rejectsWith("SDK_ERR_SIGNED_LEDGER_INVALID", () => reopened.revokeDevice(root, { operationId: "revoke-root", ak: kidHex(root.publicKey) }), "root cannot be revoked");

// A finalized receipt survives revocation without granting permission for new work.
assert.deepEqual(await reopened.append(device, { operationId: "meal-001", t: "IntakeEvent",
  body: intake(640, 36), objects: [profile], tsMs: 1767225600000 }), { ...meal, status: "already_committed" });
assert.deepEqual(await reopened.grantDevice(root, { operationId: "grant-phone", devicePublicKey: device.publicKey }),
  { ...grant, status: "already_committed" });
checks += 2;

// Admission uses the projected ledger, before the store or the signer sees the operation.
{
  const store = new FlakyStore();
  const signer = counting(root);
  const journal = await SignedLedgerWriter.open({ trustedRootPublicKey: root.publicKey, store });
  await journal.initialize(signer);
  const appendIntake = (operationId: string, body: GrainValue) => journal.append(signer, { operationId, t: "IntakeEvent", body });
  const values = intake(12, 1) as Record<string, GrainValue>;
  for (const field of ["mean", "var"]) {
    await rejectsWith("GRAIN_ERR_SCHEMA", () => appendIntake("meal", { ...values, [field]: { protein_g: 2 } }), field + " missing kcal");
  }
  assert.deepEqual([signer.calls, store.saves, journal.pendingOperation], [1, 2, null]);
  const top = await appendIntake("meal", { ...values, mean: { kcal: (1n << 63n) - 1n } });
  const before = await journal.exportTransfer();
  await rejectsWith("GRAIN_ERR_OVERFLOW", () => appendIntake("overflow", values), "aggregate overflow");
  assert.equal(await journal.exportTransfer(), before);
  assert.equal(top.seq, 1n);
  const held = await appendIntake("future", { ...values, crit: ["future.units"] });
  const verified = await journal.verify();
  assert.equal(verified.events.find((ev) => ev.payloadCid === held.payloadCid)?.status, "quarantined");
  assert.equal(verified.sumMeanKcal, "9223372036854775807");
  assert.deepEqual([signer.calls, store.saves, held.seq], [3, 6, 2n]);
  checks += 6;
}

// Each attachment is legal by itself. Crossing the transfer limit must leave the last valid export intact.
{
  const store = new InMemorySignedLedgerStore();
  const signer = counting(root);
  const journal = await SignedLedgerWriter.open({ trustedRootPublicKey: root.publicKey, store });
  await journal.initialize(signer);
  const add = (index: number, length: number) => journal.append(signer, { operationId: "archive-" + index,
    t: "Archive", body: { index }, objects: [{ index, data: new Uint8Array(length) }] });
  await add(1, 4_100_000);
  await add(2, 4_100_000);
  const before = await journal.exportTransfer();
  await rejectsWith("SDK_ERR_SIGNED_LEDGER_LIMIT", () => add(3, 4_100_000), "total transfer byte limit");
  assert.equal(signer.calls, 3);
  assert.equal(journal.pendingOperation, null);
  assert.equal(await journal.exportTransfer(), before);
  assert.equal((await add(3, 3_790_000)).seq, 3n);
  const reopened = await SignedLedgerWriter.open({ trustedRootPublicKey: root.publicKey, store });
  assert.equal((await reopened.verify()).events.length, 4);
  checks += 5;
}

// A repeated CID is one stored attachment; the original input (including repeated entries) still binds the operation ID.
{
  const store = new FlakyStore();
  const opts = { trustedRootPublicKey: root.publicKey, store };
  const signer = counting(root);
  let journal = await SignedLedgerWriter.open(opts);
  await journal.initialize(signer);
  const base = (await store.load())!;
  const record = { operationId: "repeated", t: "Note", body: 42, objects: [profile, profile] };
  store.failSaves.add(store.saves + 2);
  await rejectsWith("SDK_ERR_SIGNED_LEDGER_STORE", () => journal.append(signer, record), "pending duplicate attachments");
  const pendingSnapshot = JSON.parse((await store.load())!);
  journal = await SignedLedgerWriter.open(opts);
  const receipt = await journal.append(signer, record);
  journal = await SignedLedgerWriter.open(opts);
  assert.deepEqual(await journal.append(signer, record), { ...receipt, status: "already_committed" });
  assert.deepEqual(Object.keys((await journal.verify()).objects), [profileLink.cid]);
  await rejectsWith("SDK_ERR_SIGNED_LEDGER_OPERATION_CONFLICT", () => journal.append(signer, { ...record, objects: [profile] }), "changed v1 input digest");

  // Mix a stale pending reservation with a completed snapshot. Open must fail closed.
  const other = new InMemorySignedLedgerStore();
  await other.save(base);
  const sibling = await SignedLedgerWriter.open({ trustedRootPublicKey: root.publicKey, store: other });
  await sibling.append(root, { operationId: "other-note", t: "Note", body: 7 });
  const mixed = JSON.parse((await other.load())!);
  mixed.pending = pendingSnapshot.pending;
  await other.save(JSON.stringify(mixed));
  await rejectsWith("SDK_ERR_SIGNED_LEDGER_INVALID", () => SignedLedgerWriter.open({ trustedRootPublicKey: root.publicKey, store: other }),
    "pending slot occupied by another operation");
  assert.equal(signer.calls, 3);
  checks += 3;
}

// --- Durability ordering ------------------------------------------------------
{
  const flaky = new FlakyStore();
  const signer = counting(root);
  const journal = await SignedLedgerWriter.open({ trustedRootPublicKey: root.publicKey, store: flaky });
  flaky.failSaves.add(1);
  await rejectsWith("SDK_ERR_SIGNED_LEDGER_STORE", () => journal.initialize(signer), "reservation save fails");
  assert.equal(signer.calls, 0, "never signs before the reservation is durable");
  assert.equal(journal.pendingOperation, null);
  await journal.initialize(signer);

  // Save of the committed event fails after signing: the reservation survives restart.
  flaky.failSaves.add(flaky.saves + 2);
  await rejectsWith("SDK_ERR_SIGNED_LEDGER_STORE", () => journal.append(signer, { operationId: "note-1", t: "Note", body: { text: "hello" } }), "commit save fails");
  const restarted = await SignedLedgerWriter.open({ trustedRootPublicKey: root.publicKey, store: flaky });
  assert.deepEqual(restarted.pendingOperation, { operationId: "note-1", ak: kidHex(root.publicKey), seq: 1n, t: "Note" });
  await rejectsWith("SDK_ERR_SIGNED_LEDGER_PENDING", () => restarted.append(signer, { operationId: "note-2", t: "Note", body: { text: "other" } }), "pending blocks other operations");
  await rejectsWith("SDK_ERR_SIGNED_LEDGER_OPERATION_CONFLICT", () => restarted.append(signer, { operationId: "note-1", t: "Note", body: { text: "changed" } }), "pending input is fixed");
  const resumed = await restarted.append(signer, { operationId: "note-1", t: "Note", body: { text: "hello" } });
  assert.deepEqual([resumed.status, resumed.seq], ["committed", 1n]);
  checks += 3;

  // A snapshot whose pending bytes no longer match the input cannot make the key sign them.
  {
    const tamperStore = new FlakyStore();
    const tamperSigner = counting(root);
    const tamperJournal = await SignedLedgerWriter.open({ trustedRootPublicKey: root.publicKey, store: tamperStore });
    await tamperJournal.initialize(tamperSigner);
    tamperStore.failSaves.add(tamperStore.saves + 2);
    await rejectsWith("SDK_ERR_SIGNED_LEDGER_STORE", () => tamperJournal.append(tamperSigner, { operationId: "pay", t: "Transfer", body: { amount: 10 } }), "commit save fails before tamper");
    const saved = JSON.parse((await tamperStore.inner.load())!) as { pending: { payload_b64: string } };
    const forgedPayload = encodeGrainValue({ v: 1, t: "Transfer", ak: Buffer.from(kidHex(root.publicKey), "hex"), seq: 1, body: { amount: 10_000 } });
    saved.pending.payload_b64 = b64(forgedPayload);
    await tamperStore.inner.save(JSON.stringify(saved));
    const reopenedTampered = await SignedLedgerWriter.open({ trustedRootPublicKey: root.publicKey, store: tamperStore });
    const callsBefore = tamperSigner.calls;
    await rejectsWith("SDK_ERR_SIGNED_LEDGER_INVALID", () => reopenedTampered.append(tamperSigner, { operationId: "pay", t: "Transfer", body: { amount: 10 } }), "pending bytes altered in storage");
    assert.equal(tamperSigner.calls, callsBefore, "altered pending bytes are never signed");
    checks++;
  }

  // Signer failure keeps the reservation; a wrong signature is never committed.
  const failing: GrainSigner = { publicKey: root.publicKey, sign: async () => { throw new Error("secure enclave unavailable"); } };
  await rejectsWith("SDK_ERR_SIGNED_LEDGER_SIGNER", () => restarted.append(failing, { operationId: "note-3", t: "Note", body: { n: 3 } }), "signer failure");
  const forged: GrainSigner = { publicKey: root.publicKey, sign: async () => new Uint8Array(64).fill(1) };
  await rejectsWith("SDK_ERR_SIGNED_LEDGER_SIGNER", () => restarted.append(forged, { operationId: "note-3", t: "Note", body: { n: 3 } }), "invalid signature");
  assert.equal((await restarted.append(signer, { operationId: "note-3", t: "Note", body: { n: 3 } })).seq, 2n);
  checks++;

  // Abandoning a reservation burns its sequence number.
  flaky.failSaves.add(flaky.saves + 2);
  await rejectsWith("SDK_ERR_SIGNED_LEDGER_STORE", () => restarted.append(signer, { operationId: "lost", t: "Note", body: { n: 4 } }), "commit save fails again");
  await restarted.abandonPendingOperation();
  assert.equal(restarted.pendingOperation, null);
  assert.equal((await restarted.append(signer, { operationId: "note-5", t: "Note", body: { n: 5 } })).seq, 4n);
  checks += 2;

  // If reloading after a failed save also fails, the writer stops.
  flaky.failSaves.add(flaky.saves + 1);
  flaky.failLoads = true;
  await rejectsWith("SDK_ERR_SIGNED_LEDGER_STORE", () => restarted.append(signer, { operationId: "note-6", t: "Note", body: { n: 6 } }), "save and reload fail");
  flaky.failLoads = false;
  await rejectsWith("SDK_ERR_SIGNED_LEDGER_STORE", () => restarted.append(signer, { operationId: "note-7", t: "Note", body: { n: 7 } }), "stopped writer");
  const verifiedFlaky = verifySignedLedgerTransfer(await (await SignedLedgerWriter.open({ trustedRootPublicKey: root.publicKey, store: flaky })).exportTransfer(), rootB64);
  // Events are ordered by payload CID; compare the sequence numbers as a set.
  assert.deepEqual(verifiedFlaky.events.filter((event) => event.t === "Note").map((event) => event.seq).sort((a, b) => (a < b ? -1 : 1)), [1n, 2n, 4n]);
  checks++;
}

// --- Values -------------------------------------------------------------------
{
  const big = (1n << 63n) - 1n;
  const bytes = encodeGrainValue({ n: big, neg: -5n, b: new Uint8Array([1, 2]), l: profileLink, list: [true, null, "é"] });
  assert.ok(bytes.length > 0);
  for (const bad of [{ x: 1.5 }, { x: Number.NaN }, { x: "\ud800" }, { x: new Date() as unknown as GrainValue }, { x: undefined as unknown as GrainValue }]) {
    assert.throws(() => encodeGrainValue(bad), GrainDiagError);
    checks++;
  }
  assert.throws(() => new CidLink("bafkreigh2akiscaildcqabsyg3dfr6chu3fgpregiymsck7e7aqa4s52zy"), GrainDiagError, "raw-codec CID is not blessed");
  assert.throws(() => new CidLink(profileLink.cid.toUpperCase()), GrainDiagError, "base32 upper is not the blessed text form");
  checks += 3;
}

// --- Verifier rejections --------------------------------------------------------
{
  const parsed = JSON.parse(transfer) as { bundle_v: number; root_pub_b64: string; events: string[]; objects: Record<string, string> };
  const variants: [string, unknown, string][] = [];
  const tampered = structuredClone(parsed);
  const sig = Buffer.from(tampered.events[0], "base64");
  sig[sig.length - 1] ^= 1;
  tampered.events[0] = sig.toString("base64");
  variants.push(["tampered signature", tampered, rootB64]);
  variants.push(["wrong trusted root", parsed, b64(device.publicKey)]);
  variants.push(["extra key", { ...parsed, unsigned: true }, rootB64]);
  variants.push(["missing genesis", { ...parsed, events: parsed.events.filter((encoded) => eventType(encoded) !== "LedgerGenesis") }, rootB64]);
  const wrongObject = structuredClone(parsed);
  wrongObject.objects[profileLink.cid] = b64(encodeGrainValue({ v: 1, t: "NutrientProfile" }));
  variants.push(["object bytes do not match CID", wrongObject, rootB64]);
  const stranger = generateEd25519Signer().signer;
  const strangerWriter = await SignedLedgerWriter.open({ trustedRootPublicKey: stranger.publicKey, store: new InMemorySignedLedgerStore() });
  await strangerWriter.initialize(stranger);
  await strangerWriter.append(stranger, { operationId: "x", t: "Note", body: { text: "foreign" } });
  const foreign = JSON.parse(await strangerWriter.exportTransfer()) as typeof parsed;
  variants.push(["event from an unbound key", { ...parsed, events: [...parsed.events, ...foreign.events.slice(-1)] }, rootB64]);
  for (const [label, value, trust] of variants) {
    assert.throws(() => verifySignedLedgerTransfer(JSON.stringify(value), trust), GrainDiagError, label);
    checks++;
  }
  const shuffled = { ...parsed, events: [...parsed.events].reverse().concat(parsed.events[0]) };
  assert.deepEqual(verifySignedLedgerTransfer(JSON.stringify(shuffled), rootB64), verified);
  checks++;
}

// --- Cross-implementation: Rust-written food corpus through the generic verifier ---
{
  type Fixture = { name: string; trustedRootPubB64: string; transfer: unknown };
  const corpus = JSON.parse(readFileSync(fileURLToPath(new URL("../../../../../sdk/workflows/signed-food/v1.json", import.meta.url)), "utf8")) as Fixture[];
  for (const fixture of corpus) {
    const json = JSON.stringify(fixture.transfer);
    const food = verifySignedFoodTransfer(json, fixture.trustedRootPubB64);
    const generic = verifySignedLedgerTransfer(json, fixture.trustedRootPubB64);
    assert.deepEqual(
      { payloadCids: generic.events.map((event) => event.payloadCid), eventCount: generic.events.length, sumMeanKcal: generic.sumMeanKcal, sumVarKcal: generic.sumVarKcal, diagnostics: generic.diagnostics },
      { payloadCids: food.payloadCids, eventCount: food.eventCount, sumMeanKcal: food.sumMeanKcal, sumVarKcal: food.sumVarKcal, diagnostics: food.diagnostics },
      fixture.name
    );
    checks++;
  }
}

// --- Cross-implementation: TS-signed events through the Rust runner ------------
// Relative paths resolve from the repository root, like the divergence harness.
const repoRoot = fileURLToPath(new URL("../../../../../", import.meta.url));
const rustRunner = process.env.GRAIN_RUST_RUNNER_BIN ? resolve(repoRoot, process.env.GRAIN_RUST_RUNNER_BIN) : undefined;
let rustChecks = 0;
if (rustRunner) {
  const dir = mkdtempSync(join(tmpdir(), "grain-signed-ledger-"));
  try {
    const exported = await reopened.exportTransfer();
    const parsed = JSON.parse(exported) as { events: string[] };
    const final = verifySignedLedgerTransfer(exported, rootB64);
    const keys = new Map([[kidHex(root.publicKey), root.publicKey], [kidHex(device.publicKey), device.publicKey]]);
    const vectors: Record<string, unknown>[] = [];
    parsed.events.forEach((encoded, index) => {
      const payload = payloadOf(encoded);
      const author = coseAuthorKid(Buffer.from(encoded, "base64"), TEST_CODES);
      vectors.push({ vector_id: `TS-SIGNED-COSE-${index}`, op: "cose_verify", strict: true,
        input: { cose_b64: encoded, pub_b64: b64(keys.get(author)!), external_aad_b64: "" }, expect: { pass: true } });
      vectors.push({ vector_id: `TS-SIGNED-OBJ-${index}`, op: "dagcbor_validate", strict: true,
        input: { bytes_b64: b64(payload), object_type: "LedgerEvent" }, expect: { pass: true } });
      vectors.push({ vector_id: `TS-SIGNED-CID-${index}`, op: "cid_derive", strict: true,
        input: { bytes_b64: b64(payload), object_type: "LedgerEvent" }, expect: { pass: true, out: { cid: deriveCidV1DagCborSha256(payload) } } });
    });
    // Rust reduces the TS-signed ledger to the same totals and diagnostics.
    const hexOf = (value: GrainValue) => Buffer.from(value as Uint8Array).toString("hex");
    const rows = final.events.map((event) => {
      const body = event.body as Record<string, GrainValue>;
      const kcal = (map: GrainValue) => Number((map as Record<string, GrainValue>).kcal as bigint);
      return {
        t: event.t, ak: event.ak, seq: event.seq.toString(), payload_cid: event.payloadCid,
        body: event.t === "DeviceKeyGrant" ? { grant_ak: hexOf(body.ak) }
          : event.t === "DeviceKeyRevoke" ? { revoke_ak: hexOf(body.ak) }
          : event.t === "IntakeEvent" ? { mean: { kcal: kcal(body.mean) }, var: { kcal: kcal(body.var) } } : {}
      };
    });
    vectors.push({ vector_id: "TS-SIGNED-REDUCE", op: "ledger_reduce", strict: true, input: { root_kid: final.rootKid, events: rows },
      expect: { pass: true, out: { sum_mean: { kcal: final.sumMeanKcal }, sum_var: { kcal: final.sumVarKcal },
        ...(final.diagnostics.length ? { diag_contains: final.diagnostics } : {}) } } });
    for (const vector of vectors) {
      const path = join(dir, `${vector.vector_id as string}.json`);
      writeFileSync(path, JSON.stringify(vector));
      let raw: string;
      try {
        raw = execFileSync(rustRunner, ["run", "--strict", "--vector", path], { encoding: "utf8" });
      } catch (error) {
        raw = String((error as { stdout?: string }).stdout ?? "");
      }
      const out = JSON.parse(raw) as { pass: boolean; diag: string[] };
      assert.equal(out.pass, true, `${vector.vector_id as string}: ${out.diag.join(",")}`);
      rustChecks++;
    }
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

console.log(`signed ledger TS writer/verifier: PASS (${checks} checks${rustRunner ? `, ${rustChecks} Rust runner checks` : ", Rust runner checks skipped: set GRAIN_RUST_RUNNER_BIN"})`);
