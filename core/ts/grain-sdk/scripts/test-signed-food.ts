import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join } from "node:path";
import { verifySignedFoodTransfer } from "../src/signed-food.js";
import { GrainDiagError } from "grain-ts-core/types";
import type { CborNode } from "grain-ts-core/types";
import { encodeCanonical, GENERIC_CBOR_CANONICAL_OPTIONS, STRICT_DAG_CBOR_OPTIONS, parseExact } from "grain-ts-core/cbor";
import { createPrivateKey, sign } from "node:crypto";

type Transfer = { bundle_v: number; root_pub_b64: string; events: string[]; objects: Record<string, string> };
type Fixture = {
  name: string; trustedRootPubB64: string; transfer: Transfer;
  payloadCids?: string[];
  expected: { eventCount: number; sumMeanKcal: number; sumVarKcal: number; diagnostics: string[] };
};
const fixturePath = fileURLToPath(new URL("../../../../../sdk/workflows/signed-food/v1.json", import.meta.url));
const fixtures = JSON.parse(readFileSync(fixturePath, "utf8")) as Fixture[];
const extra = process.argv[2];
if (extra) {
  fixtures.push({ name: "swift-file-handoff", trustedRootPubB64: readFileSync(join(extra, "trusted-root.b64"), "utf8").trim(),
    transfer: JSON.parse(readFileSync(join(extra, "transfer.json"), "utf8")),
    expected: JSON.parse(readFileSync(join(extra, "expected.json"), "utf8")) });
}
let checks = 0;
function rejects(transfer: unknown, root: string): void {
  assert.throws(() => verifySignedFoodTransfer(JSON.stringify(transfer), root), (error: unknown) => error instanceof GrainDiagError);
  checks++;
}
function field(node: CborNode, name: string): CborNode {
  assert.equal(node.kind, "m");
  if (node.kind !== "m") throw new Error("test map");
  const found = node.entries.find((entry) => entry.key.kind === "t" && Buffer.from(entry.key.bytes).toString("utf8") === name);
  assert.ok(found);
  return found.value;
}
// Synthetic seed 53 matches the deterministic Rust corpus, never an application key.
const testKey = createPrivateKey({ key: Buffer.concat([Buffer.from("302e020100300506032b657004220420", "hex"), Buffer.alloc(32, 53)]), format: "der", type: "pkcs8" });
function resign(fixture: Fixture, kind: string, change: (node: CborNode) => void): Transfer {
  const modified = structuredClone(fixture.transfer);
  let changed = false;
  modified.events = modified.events.map((encoded) => {
    const envelope = parseExact(Buffer.from(encoded, "base64"), GENERIC_CBOR_CANONICAL_OPTIONS);
    assert.ok(envelope.kind === "a" && envelope.items[0].kind === "b" && envelope.items[2].kind === "b");
    const payload = parseExact(envelope.items[2].value, STRICT_DAG_CBOR_OPTIONS);
    const type = field(payload, "t");
    assert.equal(type.kind, "t");
    if (type.kind !== "t" || Buffer.from(type.bytes).toString("utf8") !== kind) return encoded;
    change(payload);
    changed = true;
    const content = encodeCanonical(payload);
    const message = encodeCanonical({ kind: "a", items: [
      { kind: "t", bytes: Buffer.from("Signature1") }, envelope.items[0], { kind: "b", value: new Uint8Array() }, { kind: "b", value: content }
    ] });
    envelope.items[2] = { kind: "b", value: content };
    envelope.items[3] = { kind: "b", value: sign(null, message, testKey) };
    return Buffer.from(encodeCanonical(envelope)).toString("base64");
  });
  assert.ok(changed);
  return modified;
}
for (const fixture of fixtures) {
  const { transfer, trustedRootPubB64: root } = fixture;
  const verified = verifySignedFoodTransfer(JSON.stringify(transfer), root);
  assert.deepEqual({ eventCount: verified.eventCount, sumMeanKcal: verified.sumMeanKcal, sumVarKcal: verified.sumVarKcal, diagnostics: verified.diagnostics }, fixture.expected, fixture.name);
  assert.equal(verified.payloadCids.length, fixture.expected.eventCount);
  if (fixture.payloadCids) assert.deepEqual(verified.payloadCids, fixture.payloadCids);
  assert.deepEqual(verified.payloadCids, [...verified.payloadCids].sort());
  checks++;
  const reordered = structuredClone(transfer);
  reordered.events.reverse();
  reordered.events.push(reordered.events[0]);
  assert.deepEqual(verifySignedFoodTransfer(JSON.stringify(reordered), root), verified);
  checks++;
  const tampered = structuredClone(transfer);
  const signature = Buffer.from(tampered.events[0], "base64");
  signature[signature.length - 1] ^= 1;
  tampered.events[0] = signature.toString("base64");
  rejects(tampered, root);
  rejects(transfer, Buffer.alloc(32, 99).toString("base64"));
  if (Object.keys(transfer.objects).length > 0) {
    const missing = structuredClone(transfer);
    missing.objects = {};
    rejects(missing, root);
  }
  const wrongObject = structuredClone(transfer);
  const first = Object.keys(wrongObject.objects)[0] ?? "invalid-cid";
  wrongObject.objects[first] = Buffer.from([0xa0]).toString("base64");
  rejects(wrongObject, root);
  rejects({ ...transfer, bundle_v: 2 }, root);
  rejects({ ...transfer, unsigned: true }, root);
  rejects({ ...transfer, events: Array.from({ length: 4097 }, () => transfer.events[0]) }, root);
  rejects({ ...transfer, events: [transfer.events[0] + " "] }, root);
  rejects({ v: 1, root: root, records: [] }, root);
  assert.throws(() => verifySignedFoodTransfer(JSON.stringify(transfer).replace('"bundle_v":1', '"bundle_v":1,"bundle_v":1'), root), GrainDiagError);
  checks++;
  const firstObject = Object.entries(transfer.objects)[0];
  if (firstObject) {
    const duplicateObjects = JSON.stringify(transfer).replace('"objects":{', `"objects":{${JSON.stringify(firstObject[0])}:${JSON.stringify(firstObject[1])},`);
    assert.throws(() => verifySignedFoodTransfer(duplicateObjects, root), GrainDiagError);
    checks++;
  }
}
const confirmed = fixtures.find((fixture) => fixture.name === "confirmed")!;
for (const literal of ["1.0", "1e0"]) {
  assert.throws(() => verifySignedFoodTransfer(JSON.stringify(confirmed.transfer).replace('"bundle_v":1', `"bundle_v":${literal}`), confirmed.trustedRootPubB64), GrainDiagError);
  checks++;
}
rejects(resign(confirmed, "IntakeEvent", (node) => {
  const mean = field(field(field(node, "body"), "mean"), "kcal");
  assert.equal(mean.kind, "u"); if (mean.kind === "u") mean.value += 1n;
}), confirmed.trustedRootPubB64);
rejects(resign(confirmed, "IntakeEvent", (node) => {
  const author = field(node, "ak"); assert.equal(author.kind, "b"); if (author.kind === "b") author.value[0] ^= 1;
}), confirmed.trustedRootPubB64);
rejects(resign(confirmed, "LedgerGenesis", (node) => {
  const seq = field(node, "seq"); assert.equal(seq.kind, "u"); if (seq.kind === "u") seq.value = 1n;
}), confirmed.trustedRootPubB64);
assert.throws(() => verifySignedFoodTransfer("{", fixtures[0].trustedRootPubB64), GrainDiagError);
assert.throws(() => verifySignedFoodTransfer(" ".repeat(16_000_001), fixtures[0].trustedRootPubB64), GrainDiagError);
console.log(`signed food TS verifier: PASS (${checks + 2} checks, ${fixtures.length} independent handoff cases)`);
