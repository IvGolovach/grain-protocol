import { encodeCanonical, GENERIC_CBOR_CANONICAL_OPTIONS, parseExact } from "grain-ts-core/cbor";
import { verifyCoseSign1Payload } from "grain-ts-core/ops/cose";
import { deriveCidV1DagCborSha256, validateTypedObjectV1 } from "grain-ts-core/ops/dagcbor";
import { opLedgerReduce } from "grain-ts-core/ops/ledger";
import { GrainDiagError, type CborNode, type Json, type JsonInteger } from "grain-ts-core/types";
import { bytesEq, sha256 } from "grain-ts-core/utils";

const INVALID = "SDK_ERR_SIGNED_FOOD_INVALID";
const TRUST = "SDK_ERR_SIGNED_FOOD_TRUST";
const LIMIT = "SDK_ERR_SIGNED_FOOD_LIMIT";
const MAX_BYTES = 16_000_000;
const MAX_ITEMS = 4096;

export interface SignedFoodVerification {
  rootKid: string;
  /** Sorted unique verified payload CIDs. Signature validity is distinct from reducer inclusion. */
  payloadCids: string[];
  eventCount: number;
  sumMeanKcal: JsonInteger;
  sumVarKcal: JsonInteger;
  diagnostics: string[];
}

interface Event {
  cid: string;
  ak: string;
  seq: bigint;
  kind: string;
  body: CborNode;
  operation?: string;
}

function reject(code: string = INVALID): never { throw new GrainDiagError(code); }
// JSON.parse validates grammar but silently overwrites duplicate keys. Scan
// validated tokens linearly: a regex with per-character alternatives can exhaust
// V8's regexp stack on a string within the transfer byte limit.
function rejectDuplicateKeys(json: string): void {
  const stack: ({ keys: Set<string>; expectingKey: boolean } | null)[] = [];
  for (let index = 0; index < json.length; index++) {
    const token = json[index];
    if (token === '"') {
      const start = index++;
      while (json[index] !== '"') {
        if (json[index] === "\\") index++;
        index++;
      }
      const current = stack.at(-1);
      if (current?.expectingKey) {
        const key = JSON.parse(json.slice(start, index + 1)) as string;
        if (current.keys.has(key)) return reject();
        current.keys.add(key);
        current.expectingKey = false;
      }
      continue;
    }
    // bundle_v is the only numeric field in this container. Match Rust's
    // integer deserializer: 1.0 and 1e0 are not version-one integer literals.
    if (token === "-" || (token >= "0" && token <= "9")) {
      const start = index;
      while (index + 1 < json.length && "0123456789.eE+-".includes(json[index + 1])) index++;
      if (json.slice(start, index + 1) !== "1") return reject();
      continue;
    }
    if (token === "{") { stack.push({ keys: new Set(), expectingKey: true }); continue; }
    if (token === "[") { stack.push(null); continue; }
    if (token === "}" || token === "]") { stack.pop(); continue; }
    const current = stack.at(-1);
    if (token === "," && current) current.expectingKey = true;
  }
}
function object(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return reject();
  return value as Record<string, unknown>;
}
function b64(value: unknown): Uint8Array {
  if (typeof value !== "string") return reject();
  if (value.length > MAX_BYTES) return reject(LIMIT);
  const bytes = Buffer.from(value, "base64");
  if (bytes.toString("base64") !== value) return reject();
  return bytes;
}
function hex(bytes: Uint8Array): string { return Buffer.from(bytes).toString("hex"); }
function pub(value: unknown): Uint8Array {
  const bytes = b64(value);
  if (bytes.length !== 32) return reject(TRUST);
  return bytes;
}
function field(node: CborNode, key: string): CborNode {
  if (node.kind !== "m") return reject();
  return node.entries.find((entry) => entry.key.kind === "t" && Buffer.from(entry.key.bytes).toString("utf8") === key)?.value ?? reject();
}
function bytes(node: CborNode): Uint8Array { return node.kind === "b" ? node.value : reject(); }
function text(node: CborNode): string { return node.kind === "t" ? Buffer.from(node.bytes).toString("utf8") : reject(); }
function integer(node: CborNode): bigint {
  if ((node.kind !== "u" && node.kind !== "n") || node.value < -(1n << 63n) || node.value > (1n << 63n) - 1n) return reject();
  return node.value;
}
function cid(data: Uint8Array): string {
  return deriveCidV1DagCborSha256(data);
}
function linkKey(data: Uint8Array): string {
  return hex(Buffer.concat([Buffer.from([0, 1, 0x71, 0x12, 0x20]), sha256(data)]));
}
function author(data: Uint8Array): string {
  const envelope = parseExact(data, GENERIC_CBOR_CANONICAL_OPTIONS);
  if (envelope.kind !== "a" || envelope.items.length !== 4) return reject();
  const protectedNode = parseExact(bytes(envelope.items[0]), GENERIC_CBOR_CANONICAL_OPTIONS);
  if (protectedNode.kind !== "m") return reject();
  const kid = protectedNode.entries.find((entry) => entry.key.kind === "u" && entry.key.value === 4n)?.value;
  return kid ? hex(bytes(kid)) : reject();
}
function event(data: Uint8Array, publicKey: Uint8Array): Event {
  const verified = verifyCoseSign1Payload(data, publicKey, new Uint8Array());
  const node = validateTypedObjectV1(verified.payload, "LedgerEvent");
  if (!bytesEq(bytes(field(node, "ak")), verified.kid)) return reject(TRUST);
  const kind = text(field(node, "t"));
  if (!["LedgerGenesis", "DeviceKeyGrant", "DeviceKeyRevoke", "IntakeEvent"].includes(kind)) return reject("SDK_ERR_SIGNED_FOOD_UNSUPPORTED");
  const body = field(node, "body");
  validateTypedObjectV1(encodeCanonical(body), kind);
  const operation = kind === "LedgerGenesis" ? undefined : text(field(field(body, "ext"), "grain.food.operation_id"));
  if (operation !== undefined && !/^[A-Za-z0-9_-]{1,128}$/.test(operation)) return reject();
  return { cid: cid(verified.payload), ak: hex(verified.kid), seq: integer(field(node, "seq")), kind, body, operation };
}

/** Verify a bounded Signed Food Ledger v1 file with an independently supplied trust root.
 * This Node API uses the TypeScript protocol core; it does not call the Rust writer.
 * Throws diagnostic-only errors and never accepts legacy unsigned exports as signed evidence.
 */
export function verifySignedFoodTransfer(transferJson: string, trustedRootPubB64: string): SignedFoodVerification {
  if (Buffer.byteLength(transferJson, "utf8") > MAX_BYTES) return reject(LIMIT);
  let parsed: unknown;
  try { parsed = JSON.parse(transferJson); } catch { return reject(); }
  rejectDuplicateKeys(transferJson);
  const transfer = object(parsed);
  if (Object.keys(transfer).sort().join(",") !== "bundle_v,events,objects,root_pub_b64") return reject();
  if (transfer.bundle_v !== 1 || transfer.root_pub_b64 !== trustedRootPubB64) return reject(TRUST);
  const root = pub(trustedRootPubB64);
  const rootKid = hex(sha256(root).slice(0, 16));
  const sourceEvents = transfer.events;
  const objects = object(transfer.objects);
  if (!Array.isArray(sourceEvents) || sourceEvents.length === 0 || sourceEvents.length > MAX_ITEMS || Object.keys(objects).length > MAX_ITEMS) return reject(LIMIT);
  const keys = new Map<string, Uint8Array>([[rootKid, root]]);
  const events = new Map<string, Event>();
  const deferred: { ak: string; data: Uint8Array }[] = [];
  for (const encoded of sourceEvents) {
    const data = b64(encoded);
    if (data.length > 34_000) return reject(LIMIT);
    const ak = author(data);
    if (ak !== rootKid) { deferred.push({ ak, data }); continue; }
    const verified = event(data, root);
    if (verified.kind === "DeviceKeyGrant") {
      const granted = bytes(field(verified.body, "pub"));
      const grantedKid = bytes(field(verified.body, "ak"));
      if (!bytesEq(sha256(granted).slice(0, 16), grantedKid) || hex(grantedKid) === rootKid) return reject(TRUST);
      const known = keys.get(hex(grantedKid));
      if (known && !bytesEq(known, granted)) return reject(TRUST);
      keys.set(hex(grantedKid), granted);
    }
    events.set(verified.cid, verified);
  }
  for (const pending of deferred) {
    const key = keys.get(pending.ak) ?? reject(TRUST);
    const verified = event(pending.data, key);
    events.set(verified.cid, verified);
  }
  const profiles = new Map<string, CborNode>();
  for (const [id, encoded] of Object.entries(objects)) {
    const data = b64(encoded);
    if (cid(data) !== id) return reject();
    profiles.set(linkKey(data), validateTypedObjectV1(data, "NutrientProfile"));
  }
  let genesis = 0;
  let rootZero = 0;
  const operations = new Set<string>();
  const payloadCids = [...events.keys()].sort();
  const rows: Json[] = [];
  for (const id of payloadCids) {
    const ev = events.get(id)!;
    if (ev.ak === rootKid && ev.seq === 0n) rootZero++;
    if (ev.operation !== undefined) {
      const operationKey = `${ev.ak}:${ev.operation}`;
      if (operations.has(operationKey)) return reject("SDK_ERR_SIGNED_FOOD_OPERATION_CONFLICT");
      operations.add(operationKey);
    }
    let body: Record<string, Json> = {};
    switch (ev.kind) {
      case "LedgerGenesis":
        if (ev.ak !== rootKid || ev.seq !== 0n || !bytesEq(bytes(field(ev.body, "root_pub")), root) || hex(bytes(field(ev.body, "root_kid"))) !== rootKid) return reject(TRUST);
        genesis++;
        break;
      case "DeviceKeyGrant": body = { grant_ak: hex(bytes(field(ev.body, "ak"))) }; break;
      case "DeviceKeyRevoke": {
        const revoked = hex(bytes(field(ev.body, "ak")));
        if (revoked === rootKid) return reject(TRUST);
        body = { revoke_ak: revoked };
        break;
      }
      case "IntakeEvent": {
        if (text(field(ev.body, "mode")) !== "from_profile" || integer(field(ev.body, "servings")) !== 1n) return reject("SDK_ERR_SIGNED_FOOD_UNSUPPORTED");
        const source = text(field(ev.body, "source_class"));
        if (!["estimated", "measured"].includes(source)) return reject("SDK_ERR_SIGNED_FOOD_UNSUPPORTED");
        const link = field(ev.body, "profile");
        if (link.kind !== "tag" || link.tag !== 42n) return reject();
        const profile = profiles.get(hex(bytes(link.inner))) ?? reject();
        if (text(field(profile, "basis")) !== "per_serving" || text(field(profile, "source")) !== source) return reject();
        const mean = integer(field(field(ev.body, "mean"), "kcal"));
        const variance = integer(field(field(ev.body, "var"), "kcal"));
        if (integer(field(field(profile, "nutr"), "kcal")) !== mean || integer(field(field(profile, "uncert"), "kcal")) !== variance) return reject();
        body = { mean: { kcal: mean.toString() }, var: { kcal: variance.toString() }, source_class: source };
        break;
      }
    }
    rows.push({ t: ev.kind, ak: ev.ak, seq: ev.seq.toString(), payload_cid: id, body });
  }
  if (genesis !== 1 || rootZero !== 1) return reject(TRUST);
  const reduced = opLedgerReduce({ root_kid: rootKid, events: rows });
  const mean = (reduced.out.sum_mean as Record<string, Json>).kcal as JsonInteger;
  const variance = (reduced.out.sum_var as Record<string, Json>).kcal as JsonInteger;
  return { rootKid, payloadCids, eventCount: events.size, sumMeanKcal: mean, sumVarKcal: variance, diagnostics: (reduced.out.diag_contains ?? []) as string[] };
}
