import { GrainDiagError, type CborNode, type JsonInteger } from "grain-ts-core/types";
import { deriveCidV1DagCborSha256, validateTypedObjectV1 } from "grain-ts-core/ops/dagcbor";
import { sha256 } from "grain-ts-core/utils";

import {
  hasCriticalExtensions,
  parseSignedTransfer,
  reduceVerifiedEvents,
  verifyLedgerEvents,
  type TransferErrorCodes,
  type VerifiedEvent
} from "./signed-ledger.js";

// Signed Food Ledger v1 is the food profile of Signed Ledger v1: the same
// container and event verification, restricted to the events and
// NutrientProfile objects the Rust/Swift food producer writes (SDK ADR-0013).

const INVALID = "SDK_ERR_SIGNED_FOOD_INVALID";
const TRUST = "SDK_ERR_SIGNED_FOOD_TRUST";
const LIMIT = "SDK_ERR_SIGNED_FOOD_LIMIT";
const UNSUPPORTED = "SDK_ERR_SIGNED_FOOD_UNSUPPORTED";
const CODES: TransferErrorCodes = { invalid: INVALID, trust: TRUST, limit: LIMIT };
const FOOD_KINDS = new Set(["LedgerGenesis", "DeviceKeyGrant", "DeviceKeyRevoke", "IntakeEvent"]);

export interface SignedFoodVerification {
  rootKid: string;
  /** Sorted unique verified payload CIDs. Signature validity is distinct from reducer inclusion. */
  payloadCids: string[];
  eventCount: number;
  sumMeanKcal: JsonInteger;
  sumVarKcal: JsonInteger;
  diagnostics: string[];
}

function reject(code: string = INVALID): never { throw new GrainDiagError(code); }
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
function hex(data: Uint8Array): string { return Buffer.from(data).toString("hex"); }
function linkKey(data: Uint8Array): string {
  return hex(Buffer.concat([Buffer.from([0, 1, 0x71, 0x12, 0x20]), sha256(data)]));
}
function operationId(event: VerifiedEvent): string | undefined {
  if (event.t === "LedgerGenesis") return undefined;
  const operation = text(field(field(event.body, "ext"), "grain.food.operation_id"));
  return /^[A-Za-z0-9_-]{1,128}$/.test(operation) ? operation : reject();
}

/** Verify a bounded Signed Food Ledger v1 file with an independently supplied trust root.
 * This Node API uses the TypeScript protocol core; it does not call the Rust writer.
 * Throws diagnostic-only errors and never accepts legacy unsigned exports as signed evidence.
 */
export function verifySignedFoodTransfer(transferJson: string, trustedRootPubB64: string): SignedFoodVerification {
  const parsed = parseSignedTransfer(transferJson, trustedRootPubB64, CODES);
  const { events } = verifyLedgerEvents(parsed.root, parsed.events, CODES, (event) => {
    if (event.quarantined || !FOOD_KINDS.has(event.t)) reject(UNSUPPORTED);
    operationId(event);
  });
  const profiles = new Map<string, CborNode>();
  for (const [id, data] of parsed.objects) {
    if (deriveCidV1DagCborSha256(data) !== id) return reject();
    const profile = validateTypedObjectV1(data, "NutrientProfile");
    if (hasCriticalExtensions(profile)) reject(UNSUPPORTED);
    profiles.set(linkKey(data), profile);
  }
  const operations = new Set<string>();
  const payloadCids = [...events.keys()].sort();
  const sorted = payloadCids.map((id) => events.get(id)!);
  for (const ev of sorted) {
    const operation = operationId(ev);
    if (operation !== undefined) {
      const operationKey = `${ev.ak}:${operation}`;
      if (operations.has(operationKey)) return reject("SDK_ERR_SIGNED_FOOD_OPERATION_CONFLICT");
      operations.add(operationKey);
    }
    if (ev.t !== "IntakeEvent") continue;
    if (text(field(ev.body, "mode")) !== "from_profile" || integer(field(ev.body, "servings")) !== 1n) return reject(UNSUPPORTED);
    const source = text(field(ev.body, "source_class"));
    if (!["estimated", "measured"].includes(source)) return reject(UNSUPPORTED);
    const link = field(ev.body, "profile");
    if (link.kind !== "tag" || link.tag !== 42n) return reject();
    const profile = profiles.get(hex(bytes(link.inner))) ?? reject();
    if (text(field(profile, "basis")) !== "per_serving" || text(field(profile, "source")) !== source) return reject();
    const mean = integer(field(field(ev.body, "mean"), "kcal"));
    const variance = integer(field(field(ev.body, "var"), "kcal"));
    if (integer(field(field(profile, "nutr"), "kcal")) !== mean || integer(field(field(profile, "uncert"), "kcal")) !== variance) return reject();
  }
  const totals = reduceVerifiedEvents(parsed.rootKid, sorted, CODES);
  return { rootKid: parsed.rootKid, payloadCids, eventCount: events.size, ...totals };
}
