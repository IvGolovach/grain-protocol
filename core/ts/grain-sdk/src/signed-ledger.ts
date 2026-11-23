import { createPrivateKey, createPublicKey, generateKeyPairSync, sign as nodeSign, type KeyObject } from "node:crypto";

import { encodeCanonical, GENERIC_CBOR_CANONICAL_OPTIONS, parseExact } from "grain-ts-core/cbor";
import { verifyCoseSign1Payload } from "grain-ts-core/ops/cose";
import { deriveCidV1DagCborSha256, parseDagCborStrict, validateTypedObjectV1 } from "grain-ts-core/ops/dagcbor";
import { opLedgerReduce } from "grain-ts-core/ops/ledger";
import { GrainDiagError, type CborNode, type Json, type JsonInteger } from "grain-ts-core/types";
import { bytesEq, compareBytesLex, compareCanonicalMapKey, sha256 } from "grain-ts-core/utils";

// Signed Ledger v1: real NES v0.1 ledger events (COSE_Sign1 Ed25519 over
// canonical DAG-CBOR LedgerEvent payloads) for any event type. See
// adr/sdk/0014-typescript-signed-ledger-v1.md and
// sdk/workflows/contract/signed_ledger_v1.md.

export const SIGNED_LEDGER_ERR = {
  INVALID: "SDK_ERR_SIGNED_LEDGER_INVALID",
  TRUST: "SDK_ERR_SIGNED_LEDGER_TRUST",
  LIMIT: "SDK_ERR_SIGNED_LEDGER_LIMIT",
  UNINITIALIZED: "SDK_ERR_SIGNED_LEDGER_UNINITIALIZED",
  PENDING: "SDK_ERR_SIGNED_LEDGER_PENDING",
  OPERATION_CONFLICT: "SDK_ERR_SIGNED_LEDGER_OPERATION_CONFLICT",
  UNAUTHORIZED: "SDK_ERR_UNAUTHORIZED_AK",
  SIGNER: "SDK_ERR_SIGNED_LEDGER_SIGNER",
  STORE: "SDK_ERR_SIGNED_LEDGER_STORE"
} as const;

/** Diagnostic codes used by transfer parsing; profile verifiers pass their own. */
export interface TransferErrorCodes {
  invalid: string;
  trust: string;
  limit: string;
}

const LEDGER_CODES: TransferErrorCodes = {
  invalid: SIGNED_LEDGER_ERR.INVALID,
  trust: SIGNED_LEDGER_ERR.TRUST,
  limit: SIGNED_LEDGER_ERR.LIMIT
};

export const SIGNED_TRANSFER_MAX_BYTES = 16_000_000;
export const SIGNED_TRANSFER_MAX_ITEMS = 4096;
export const SIGNED_TRANSFER_MAX_COSE_BYTES = 34_000;
const MAX_SEQ = (1n << 63n) - 1n;
const OPERATION_ID = /^[A-Za-z0-9_-]{1,128}$/;
const ROOT_ONLY_TYPES = new Set(["LedgerGenesis", "DeviceKeyGrant", "DeviceKeyRevoke"]);
// Productions that are never LedgerEvent bodies.
const NON_EVENT_TYPES = new Set(["LedgerEvent", "EncryptedObject", "ManifestRecord"]);
const KNOWN_TYPES = new Set([
  "IngredientRef", "NutrientProfile", "CookRun", "NutritionComputeResult", "IntakeEvent", "ServingOffer",
  "LedgerGenesis", "DeviceKeyGrant", "DeviceKeyRevoke", "VoidEvent", "CorrectionEvent",
  "LedgerEvent", "EncryptedObject", "ManifestRecord"
]);

function fail(code: string): never {
  throw new GrainDiagError(code);
}

// ---------------------------------------------------------------------------
// Values: what applications write and read.

/** A tag-42 link to a blessed CIDv1 (dag-cbor, sha2-256). */
export class CidLink {
  readonly cid: string;
  readonly bytes: Uint8Array;

  constructor(cid: string) {
    const bytes = decodeCidText(cid);
    this.cid = cid;
    this.bytes = bytes;
  }

  /** Link to canonical DAG-CBOR object bytes (validated, then hashed). */
  static to(objectBytes: Uint8Array): CidLink {
    return new CidLink(deriveCidV1DagCborSha256(objectBytes));
  }
}

/**
 * The DAG-CBOR data model as plain values. Integers are bigint (or safe
 * JavaScript integers on input); text is string; bytes are Uint8Array; links
 * are CidLink. Floats are not part of Grain and are rejected.
 */
export type GrainValue =
  | null
  | boolean
  | bigint
  | number
  | string
  | Uint8Array
  | CidLink
  | GrainValue[]
  | { [key: string]: GrainValue };

const utf8 = new TextEncoder();
const utf8Strict = new TextDecoder("utf-8", { fatal: true, ignoreBOM: true });

function textNode(value: string): CborNode {
  const bytes = utf8.encode(value);
  if (utf8Strict.decode(bytes) !== value) fail(SIGNED_LEDGER_ERR.INVALID); // lone surrogate
  return { kind: "t", bytes };
}

function mapNode(entries: [string, CborNode][]): CborNode {
  const encoded = entries.map(([key, value]) => {
    const keyNode = textNode(key);
    return { key: keyNode, keyBytes: encodeCanonical(keyNode), value };
  });
  encoded.sort((a, b) => compareCanonicalMapKey(a.keyBytes, b.keyBytes));
  return { kind: "m", entries: encoded };
}

function integerNode(value: bigint): CborNode {
  if (value < -(1n << 64n) || value >= 1n << 64n) fail(SIGNED_LEDGER_ERR.INVALID);
  return value >= 0n ? { kind: "u", value } : { kind: "n", value };
}

/** Convert an application value to a CBOR node (not yet validated as strict DAG-CBOR). */
export function toCborNode(value: GrainValue): CborNode {
  if (value === null) return { kind: "null" };
  if (typeof value === "boolean") return { kind: "bool", value };
  if (typeof value === "bigint") return integerNode(value);
  if (typeof value === "number") {
    if (!Number.isSafeInteger(value)) fail(SIGNED_LEDGER_ERR.INVALID);
    return integerNode(BigInt(value));
  }
  if (typeof value === "string") return textNode(value);
  if (value instanceof Uint8Array) return { kind: "b", value: new Uint8Array(value) };
  if (value instanceof CidLink) return { kind: "tag", tag: 42n, inner: { kind: "b", value: new Uint8Array([0, ...value.bytes]) } };
  if (Array.isArray(value)) return { kind: "a", items: value.map(toCborNode) };
  const prototype = typeof value === "object" ? Object.getPrototypeOf(value) : undefined;
  if (prototype === Object.prototype || prototype === null) {
    return mapNode(Object.entries(value).map(([key, entry]) => [key, toCborNode(entry)]));
  }
  return fail(SIGNED_LEDGER_ERR.INVALID);
}

/** Convert a strict DAG-CBOR node back to an application value. */
export function fromCborNode(node: CborNode): GrainValue {
  switch (node.kind) {
    case "u":
    case "n":
      return node.value;
    case "t":
      return utf8Strict.decode(node.bytes);
    case "b":
      return new Uint8Array(node.value);
    case "bool":
      return node.value;
    case "null":
      return null;
    case "a":
      return node.items.map(fromCborNode);
    case "m": {
      const out: { [key: string]: GrainValue } = {};
      for (const entry of node.entries) {
        if (entry.key.kind !== "t") fail(SIGNED_LEDGER_ERR.INVALID);
        Object.defineProperty(out, utf8Strict.decode(entry.key.bytes), {
          value: fromCborNode(entry.value), enumerable: true, writable: true, configurable: true
        });
      }
      return out;
    }
    case "tag":
      if (node.tag === 42n && node.inner.kind === "b") return new CidLink(encodeCidText(node.inner.value.slice(1)));
      return fail(SIGNED_LEDGER_ERR.INVALID);
    default:
      return fail(SIGNED_LEDGER_ERR.INVALID);
  }
}

/** Encode a value as strict canonical DAG-CBOR, rejecting anything NES §3 forbids. */
export function encodeGrainValue(value: GrainValue): Uint8Array {
  const bytes = encodeCanonical(toCborNode(value));
  parseDagCborStrict(bytes);
  return bytes;
}

const BASE32 = "abcdefghijklmnopqrstuvwxyz234567";

function encodeCidText(bytes: Uint8Array): string {
  let bits = 0;
  let value = 0;
  let out = "b";
  for (const byte of bytes) {
    value = (value << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      out += BASE32[(value >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }
  if (bits > 0) out += BASE32[(value << (5 - bits)) & 31];
  return out;
}

function decodeCidText(text: string): Uint8Array {
  if (typeof text !== "string" || text[0] !== "b") fail(SIGNED_LEDGER_ERR.INVALID);
  const out: number[] = [];
  let bits = 0;
  let value = 0;
  for (const char of text.slice(1)) {
    const index = BASE32.indexOf(char);
    if (index < 0) fail(SIGNED_LEDGER_ERR.INVALID);
    value = ((value << 5) | index) & 0xffff;
    bits += 5;
    if (bits >= 8) {
      out.push((value >>> (bits - 8)) & 0xff);
      bits -= 8;
    }
  }
  const bytes = new Uint8Array(out);
  const blessed = bytes.length === 36 && bytes[0] === 0x01 && bytes[1] === 0x71 && bytes[2] === 0x12 && bytes[3] === 0x20;
  if (!blessed || encodeCidText(bytes) !== text) fail(SIGNED_LEDGER_ERR.INVALID);
  return bytes;
}

// ---------------------------------------------------------------------------
// Signers.

/** An application-owned Ed25519 key. The SDK never sees the private key. */
export interface GrainSigner {
  /** Raw 32-byte Ed25519 public key. */
  readonly publicKey: Uint8Array;
  /** Ed25519-sign exactly these bytes and return the 64-byte signature. */
  sign(message: Uint8Array): Promise<Uint8Array>;
}

const PKCS8_ED25519_PREFIX = Buffer.from("302e020100300506032b657004220420", "hex");

function signerFromKeyObject(privateKey: KeyObject): GrainSigner {
  const spki = createPublicKey(privateKey).export({ format: "der", type: "spki" });
  const publicKey = new Uint8Array(spki.subarray(spki.length - 32));
  return {
    publicKey,
    sign: async (message) => new Uint8Array(nodeSign(null, message, privateKey))
  };
}

/**
 * Node signer from a raw 32-byte Ed25519 seed. Suitable for servers, tools and
 * tests. Key custody (where the seed lives) is the application's job.
 */
export function ed25519SignerFromSeed(seed: Uint8Array): GrainSigner {
  if (!(seed instanceof Uint8Array) || seed.length !== 32) fail(SIGNED_LEDGER_ERR.INVALID);
  const key = createPrivateKey({ key: Buffer.concat([PKCS8_ED25519_PREFIX, seed]), format: "der", type: "pkcs8" });
  return signerFromKeyObject(key);
}

/** Generate a fresh Node Ed25519 signer and return its seed for the application to store. */
export function generateEd25519Signer(): { signer: GrainSigner; seed: Uint8Array } {
  const { privateKey } = generateKeyPairSync("ed25519");
  const der = privateKey.export({ format: "der", type: "pkcs8" });
  return { signer: signerFromKeyObject(privateKey), seed: new Uint8Array(der.subarray(der.length - 32)) };
}

// ---------------------------------------------------------------------------
// Shared transfer parsing and event verification.

function hex(bytes: Uint8Array): string {
  return Buffer.from(bytes).toString("hex");
}

/** Author key ID (hex) of a raw 32-byte Ed25519 public key: first16(SHA-256(pub)). */
export function kidHex(publicKey: Uint8Array): string {
  return hex(sha256(publicKey).slice(0, 16));
}

function base64(value: unknown, codes: TransferErrorCodes): Uint8Array {
  if (typeof value !== "string") return fail(codes.invalid);
  if (value.length > SIGNED_TRANSFER_MAX_BYTES) return fail(codes.limit);
  const bytes = Buffer.from(value, "base64");
  if (bytes.toString("base64") !== value) return fail(codes.invalid);
  return new Uint8Array(bytes);
}

function plainObject(value: unknown, codes: TransferErrorCodes): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return fail(codes.invalid);
  return value as Record<string, unknown>;
}

// JSON.parse validates grammar but silently overwrites duplicate keys. Scan
// validated tokens linearly: a regex with per-character alternatives can exhaust
// V8's regexp stack on a string within the transfer byte limit.
function rejectDuplicateKeys(json: string, codes: TransferErrorCodes): void {
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
        if (current.keys.has(key)) return fail(codes.invalid);
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
      if (json.slice(start, index + 1) !== "1") return fail(codes.invalid);
      continue;
    }
    if (token === "{") { stack.push({ keys: new Set(), expectingKey: true }); continue; }
    if (token === "[") { stack.push(null); continue; }
    if (token === "}" || token === "]") { stack.pop(); continue; }
    const current = stack.at(-1);
    if (token === "," && current) current.expectingKey = true;
  }
}

export interface ParsedTransfer {
  root: Uint8Array;
  rootKid: string;
  events: Uint8Array[];
  /** Object entries in file order; CIDs are not yet checked. */
  objects: [string, Uint8Array][];
}

/** Parse the shared transfer container (`bundle_v`, `root_pub_b64`, `events`, `objects`). */
export function parseSignedTransfer(json: string, trustedRootPubB64: string, codes: TransferErrorCodes): ParsedTransfer {
  if (typeof json !== "string" || Buffer.byteLength(json, "utf8") > SIGNED_TRANSFER_MAX_BYTES) return fail(codes.limit);
  let parsed: unknown;
  try { parsed = JSON.parse(json); } catch { return fail(codes.invalid); }
  rejectDuplicateKeys(json, codes);
  const transfer = plainObject(parsed, codes);
  if (Object.keys(transfer).sort().join(",") !== "bundle_v,events,objects,root_pub_b64") return fail(codes.invalid);
  if (transfer.bundle_v !== 1 || transfer.root_pub_b64 !== trustedRootPubB64) return fail(codes.trust);
  const root = base64(trustedRootPubB64, codes);
  if (root.length !== 32) return fail(codes.trust);
  const sourceEvents = transfer.events;
  const objects = plainObject(transfer.objects, codes);
  if (!Array.isArray(sourceEvents) || sourceEvents.length === 0 || sourceEvents.length > SIGNED_TRANSFER_MAX_ITEMS
    || Object.keys(objects).length > SIGNED_TRANSFER_MAX_ITEMS) return fail(codes.limit);
  const events = sourceEvents.map((encoded) => {
    const data = base64(encoded, codes);
    if (data.length > SIGNED_TRANSFER_MAX_COSE_BYTES) return fail(codes.limit);
    return data;
  });
  return {
    root,
    rootKid: kidHex(root),
    events,
    objects: Object.entries(objects).map(([cid, encoded]) => [cid, base64(encoded, codes)])
  };
}

function field(node: CborNode, key: string, codes: TransferErrorCodes): CborNode {
  if (node.kind !== "m") return fail(codes.invalid);
  const found = node.entries.find((entry) => entry.key.kind === "t" && Buffer.from(entry.key.bytes).toString("utf8") === key);
  return found ? found.value : fail(codes.invalid);
}

function optionalField(node: CborNode, key: string): CborNode | undefined {
  if (node.kind !== "m") return undefined;
  return node.entries.find((entry) => entry.key.kind === "t" && Buffer.from(entry.key.bytes).toString("utf8") === key)?.value;
}

function bytesOf(node: CborNode, codes: TransferErrorCodes): Uint8Array {
  return node.kind === "b" ? node.value : fail(codes.invalid);
}

function textOf(node: CborNode, codes: TransferErrorCodes): string {
  return node.kind === "t" ? Buffer.from(node.bytes).toString("utf8") : fail(codes.invalid);
}

function unsignedOf(node: CborNode, codes: TransferErrorCodes): bigint {
  return node.kind === "u" && node.value <= MAX_SEQ ? node.value : fail(codes.invalid);
}

/** Protected-header author kid (hex) of a COSE_Sign1 envelope, before verification. */
export function coseAuthorKid(data: Uint8Array, codes: TransferErrorCodes): string {
  const envelope = parseExact(data, GENERIC_CBOR_CANONICAL_OPTIONS);
  if (envelope.kind !== "a" || envelope.items.length !== 4) return fail(codes.invalid);
  const protectedNode = parseExact(bytesOf(envelope.items[0], codes), GENERIC_CBOR_CANONICAL_OPTIONS);
  if (protectedNode.kind !== "m") return fail(codes.invalid);
  const kid = protectedNode.entries.find((entry) => entry.key.kind === "u" && entry.key.value === 4n)?.value;
  return kid ? hex(bytesOf(kid, codes)) : fail(codes.invalid);
}

/** v0.1 implements no critical extension identifiers. Typed validation checks the array shape. */
export function hasCriticalExtensions(node: CborNode): boolean {
  const crit = optionalField(node, "crit");
  return crit?.kind === "a" && crit.items.length > 0;
}

// Only these nested productions carry protocol extension fields (CDDL CookInput and MapDecision).
function bodyRequiresQuarantine(t: string, body: CborNode): boolean {
  if (!KNOWN_TYPES.has(t)) return false;
  if (hasCriticalExtensions(body)) return true;
  const children = t === "CookRun" ? optionalField(body, "inputs")
    : t === "NutritionComputeResult" ? optionalField(body, "map") : undefined;
  return children?.kind === "a" && children.items.some(hasCriticalExtensions);
}

/** One cryptographically verified ledger event. */
export interface VerifiedEvent {
  payloadCid: string;
  ak: string;
  seq: bigint;
  t: string;
  tsMs?: bigint;
  body: CborNode;
  payload: Uint8Array;
  cose: Uint8Array;
  quarantined: boolean;
}

/** Verify a COSE_Sign1 ledger event with `publicKey`, enforcing NES §5, §6.1 and typed bodies. */
export function verifyLedgerEventEnvelope(data: Uint8Array, publicKey: Uint8Array, codes: TransferErrorCodes, inspectKind?: (t: string) => void): VerifiedEvent {
  const verified = verifyCoseSign1Payload(data, publicKey, new Uint8Array());
  const node = validateTypedObjectV1(verified.payload, "LedgerEvent");
  if (!bytesEq(bytesOf(field(node, "ak", codes), codes), verified.kid)) return fail(codes.trust);
  const t = textOf(field(node, "t", codes), codes);
  inspectKind?.(t);
  if (NON_EVENT_TYPES.has(t)) return fail(codes.invalid);
  const body = field(node, "body", codes);
  if (KNOWN_TYPES.has(t)) validateTypedObjectV1(encodeCanonical(body), t);
  const ts = optionalField(node, "ts_ms");
  return {
    payloadCid: deriveCidV1DagCborSha256(verified.payload),
    ak: hex(verified.kid),
    seq: unsignedOf(field(node, "seq", codes), codes),
    t,
    tsMs: ts && (ts.kind === "u" || ts.kind === "n") ? ts.value : undefined,
    body,
    payload: verified.payload,
    cose: data,
    quarantined: hasCriticalExtensions(node) || bodyRequiresQuarantine(t, body)
  };
}

/**
 * Verify every envelope under one trusted root. Root-signed grants bind device
 * keys; any other author must be bound by such a grant. Returns unique events
 * keyed by payload CID and the key bindings.
 */
export function verifyLedgerEvents(
  root: Uint8Array,
  envelopes: Uint8Array[],
  codes: TransferErrorCodes,
  inspect?: (event: VerifiedEvent) => void,
  inspectKind?: (t: string) => void
): { events: Map<string, VerifiedEvent>; keys: Map<string, Uint8Array> } {
  const rootKid = kidHex(root);
  const keys = new Map<string, Uint8Array>([[rootKid, root]]);
  const events = new Map<string, VerifiedEvent>();
  const deferred: { ak: string; data: Uint8Array }[] = [];
  for (const data of envelopes) {
    const ak = coseAuthorKid(data, codes);
    if (ak !== rootKid) { deferred.push({ ak, data }); continue; }
    const event = verifyLedgerEventEnvelope(data, root, codes, inspectKind);
    inspect?.(event);
    if (!event.quarantined && event.t === "DeviceKeyGrant") {
      const granted = bytesOf(field(event.body, "pub", codes), codes);
      const grantedKid = bytesOf(field(event.body, "ak", codes), codes);
      if (kidHex(granted) !== hex(grantedKid) || hex(grantedKid) === rootKid) return fail(codes.trust);
      const known = keys.get(hex(grantedKid));
      if (known && !bytesEq(known, granted)) return fail(codes.trust);
      keys.set(hex(grantedKid), granted);
    }
    events.set(event.payloadCid, event);
  }
  for (const pending of deferred) {
    const key = keys.get(pending.ak) ?? fail(codes.trust);
    const event = verifyLedgerEventEnvelope(pending.data, key, codes, inspectKind);
    inspect?.(event);
    events.set(event.payloadCid, event);
  }
  let genesis = 0;
  let rootZero = 0;
  for (const event of events.values()) {
    if (event.quarantined) continue;
    if (event.ak === rootKid && event.seq === 0n) rootZero++;
    if (event.t === "LedgerGenesis") {
      const valid = event.ak === rootKid && event.seq === 0n
        && bytesEq(bytesOf(field(event.body, "root_pub", codes), codes), root)
        && hex(bytesOf(field(event.body, "root_kid", codes), codes)) === rootKid;
      if (!valid) return fail(codes.trust);
      genesis++;
    }
    if (event.ak === rootKid && event.t === "DeviceKeyRevoke" && hex(bytesOf(field(event.body, "ak", codes), codes)) === rootKid) return fail(codes.trust);
  }
  if (genesis !== 1 || rootZero !== 1) return fail(codes.trust);
  return { events, keys };
}

/** Recompute object CIDs; every entry must be strict DAG-CBOR (typed when its `t` is known). */
export function verifyTransferObjects(entries: [string, Uint8Array][], codes: TransferErrorCodes): Map<string, CborNode> {
  const out = new Map<string, CborNode>();
  for (const [cid, data] of entries) {
    if (deriveCidV1DagCborSha256(data) !== cid) return fail(codes.invalid);
    const node = parseDagCborStrict(data);
    const t = optionalField(node, "t");
    out.set(cid, t?.kind === "t" && KNOWN_TYPES.has(Buffer.from(t.bytes).toString("utf8"))
      ? validateTypedObjectV1(data, Buffer.from(t.bytes).toString("utf8"))
      : node);
  }
  return out;
}

function integerJson(node: CborNode | undefined): JsonInteger | undefined {
  if (!node || (node.kind !== "u" && node.kind !== "n")) return undefined;
  return Number.isSafeInteger(Number(node.value)) ? Number(node.value) : node.value.toString();
}

type ReducerEvent = Pick<VerifiedEvent, "ak" | "seq" | "t" | "body" | "payloadCid" | "quarantined">;

/** Map verified events to the NES `ledger_reduce` input model and reduce. */
export function reduceVerifiedEvents(rootKid: string, events: readonly ReducerEvent[], codes: TransferErrorCodes): { sumMeanKcal: JsonInteger; sumVarKcal: JsonInteger; diagnostics: string[] } {
  const rows: Json[] = events.filter((event) => !event.quarantined).map((event) => {
    let body: Record<string, Json> = {};
    if (event.t === "DeviceKeyGrant") body = { grant_ak: hex(bytesOf(field(event.body, "ak", codes), codes)) };
    if (event.t === "DeviceKeyRevoke") body = { revoke_ak: hex(bytesOf(field(event.body, "ak", codes), codes)) };
    if (event.t === "IntakeEvent") {
      const mean = integerJson(optionalField(field(event.body, "mean", codes), "kcal"));
      const variance = integerJson(optionalField(field(event.body, "var", codes), "kcal"));
      body = {
        ...(mean === undefined ? {} : { mean: { kcal: mean } }),
        ...(variance === undefined ? {} : { var: { kcal: variance } })
      };
    }
    return { t: event.t, ak: event.ak, seq: event.seq.toString(), payload_cid: event.payloadCid, body };
  });
  const reduced = opLedgerReduce({ root_kid: rootKid, events: rows });
  return {
    sumMeanKcal: (reduced.out.sum_mean as Record<string, Json>).kcal as JsonInteger,
    sumVarKcal: (reduced.out.sum_var as Record<string, Json>).kcal as JsonInteger,
    diagnostics: (reduced.out.diag_contains ?? []) as string[]
  };
}

// ---------------------------------------------------------------------------
// Generic verification.

export type SignedLedgerEventStatus = "counted" | "unauthorized" | "conflicted" | "quarantined";

export interface SignedLedgerEvent {
  payloadCid: string;
  /** Author key ID, hex. */
  ak: string;
  seq: bigint;
  t: string;
  tsMs?: bigint;
  body: GrainValue;
  /** Whether NES §6 authorization and conflict rules admit this event. */
  status: SignedLedgerEventStatus;
}

export interface SignedLedgerVerification {
  rootKid: string;
  /** Unique events sorted by payload CID. Unknown types are included (NES §2.3). */
  events: SignedLedgerEvent[];
  /** Objects by CID after CID recomputation. */
  objects: Record<string, GrainValue>;
  authorizedAks: string[];
  revokedAks: string[];
  sumMeanKcal: JsonInteger;
  sumVarKcal: JsonInteger;
  diagnostics: string[];
}

function eventStatuses(rootKid: string, events: VerifiedEvent[], codes: TransferErrorCodes): {
  status: Map<string, SignedLedgerEventStatus>; authorized: string[]; revoked: string[];
} {
  const payloadsBySlot = new Map<string, Set<string>>();
  const eligible = events.filter((event) => !event.quarantined);
  for (const event of eligible) {
    const slot = `${event.ak}:${event.seq}`;
    payloadsBySlot.set(slot, (payloadsBySlot.get(slot) ?? new Set()).add(event.payloadCid));
  }
  const conflicted = (event: VerifiedEvent) => payloadsBySlot.get(`${event.ak}:${event.seq}`)!.size > 1;
  const granted = new Set<string>();
  const revoked = new Set<string>();
  for (const event of eligible) {
    if (event.ak !== rootKid || conflicted(event)) continue;
    if (event.t === "DeviceKeyGrant") granted.add(hex(bytesOf(field(event.body, "ak", codes), codes)));
    if (event.t === "DeviceKeyRevoke") revoked.add(hex(bytesOf(field(event.body, "ak", codes), codes)));
  }
  const authorizedAk = (ak: string) => ak === rootKid || (granted.has(ak) && !revoked.has(ak));
  const status = new Map<string, SignedLedgerEventStatus>();
  for (const event of events) {
    if (event.quarantined) {
      status.set(event.payloadCid, "quarantined");
      continue;
    }
    const authorized = ROOT_ONLY_TYPES.has(event.t) ? event.ak === rootKid : authorizedAk(event.ak);
    status.set(event.payloadCid, conflicted(event) ? "conflicted" : authorized ? "counted" : "unauthorized");
  }
  return {
    status,
    authorized: [rootKid, ...[...granted].filter((ak) => !revoked.has(ak))].sort(),
    revoked: [...revoked].sort()
  };
}

/**
 * Verify a Signed Ledger v1 transfer under an independently obtained root key.
 * Rejects the whole file atomically on any encoding, schema, CID, signature or
 * trust failure. A valid signature proves authorship, not that content is true.
 */
export function verifySignedLedgerTransfer(transferJson: string, trustedRootPubB64: string): SignedLedgerVerification {
  const parsed = parseSignedTransfer(transferJson, trustedRootPubB64, LEDGER_CODES);
  const { events } = verifyLedgerEvents(parsed.root, parsed.events, LEDGER_CODES);
  const objects = verifyTransferObjects(parsed.objects, LEDGER_CODES);
  const sorted = [...events.values()].sort((a, b) => compareBytesLex(utf8.encode(a.payloadCid), utf8.encode(b.payloadCid)));
  const { status, authorized, revoked } = eventStatuses(parsed.rootKid, sorted, LEDGER_CODES);
  const totals = reduceVerifiedEvents(parsed.rootKid, sorted, LEDGER_CODES);
  return {
    rootKid: parsed.rootKid,
    events: sorted.map((event) => ({
      payloadCid: event.payloadCid,
      ak: event.ak,
      seq: event.seq,
      t: event.t,
      ...(event.tsMs === undefined ? {} : { tsMs: event.tsMs }),
      body: fromCborNode(event.body),
      status: status.get(event.payloadCid)!
    })),
    objects: Object.fromEntries([...objects.entries()].sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
      .map(([cid, node]) => [cid, fromCborNode(node)])),
    authorizedAks: authorized,
    revokedAks: revoked,
    ...totals
  };
}

// ---------------------------------------------------------------------------
// Writer.

/**
 * Durable storage for one writer's private snapshot. `save` MUST atomically
 * replace the previous snapshot and resolve only once the bytes are durable.
 */
export interface SignedLedgerStore {
  load(): Promise<string | null>;
  save(snapshot: string): Promise<void>;
}

export class InMemorySignedLedgerStore implements SignedLedgerStore {
  private value: string | null = null;

  async load(): Promise<string | null> {
    return this.value;
  }

  async save(snapshot: string): Promise<void> {
    this.value = snapshot;
  }
}

export interface SignedLedgerReceipt {
  status: "committed" | "already_committed";
  payloadCid: string;
  ak: string;
  seq: bigint;
  t: string;
}

export interface AppendSignedEventInput {
  /** Stable ID for this logical write; reuse it when retrying. 1–128 of [A-Za-z0-9_-]. */
  operationId: string;
  t: string;
  body: GrainValue;
  tsMs?: bigint | number;
  /** CAS objects the body links to (for example a NutrientProfile), exported with the ledger. */
  objects?: GrainValue[];
}

interface Pending {
  operation: string;
  ak: string;
  seq: bigint;
  t: string;
  digest: string;
  payload: Uint8Array;
  objects: [string, Uint8Array][];
}

interface JournalState {
  events: Map<string, VerifiedEvent>;
  objects: Map<string, Uint8Array>;
  keys: Map<string, Uint8Array>;
  counters: Map<string, bigint>;
  operations: Map<string, { payloadCid: string; digest: string }>;
  pending: Pending | null;
}

type SnapshotV1 = {
  snapshot_v: 1;
  root_pub_b64: string;
  events: string[];
  objects: Record<string, string>;
  counters: Record<string, string>;
  operations: Record<string, { payload_cid: string; input_sha256: string }>;
  pending: null | {
    operation: string; ak: string; seq: string; t: string; input_sha256: string;
    payload_b64: string; objects: Record<string, string>;
  };
};

const b64 = (bytes: Uint8Array) => Buffer.from(bytes).toString("base64");
const unb64 = (value: string) => base64(value, LEDGER_CODES);
const protectedHeader = (publicKey: Uint8Array): Uint8Array => encodeCanonical({
  kind: "m",
  entries: [
    { key: { kind: "u", value: 1n }, keyBytes: new Uint8Array([0x01]), value: { kind: "n", value: -19n } },
    { key: { kind: "u", value: 4n }, keyBytes: new Uint8Array([0x04]), value: { kind: "b", value: sha256(publicKey).slice(0, 16) } }
  ]
});

function sigStructure(protectedBytes: Uint8Array, payload: Uint8Array): Uint8Array {
  return encodeCanonical({ kind: "a", items: [
    { kind: "t", bytes: utf8.encode("Signature1") },
    { kind: "b", value: protectedBytes },
    { kind: "b", value: new Uint8Array() },
    { kind: "b", value: payload }
  ] });
}

function encodeEnvelope(protectedBytes: Uint8Array, payload: Uint8Array, signature: Uint8Array): Uint8Array {
  return encodeCanonical({ kind: "a", items: [
    { kind: "b", value: protectedBytes },
    { kind: "m", entries: [] },
    { kind: "b", value: payload },
    { kind: "b", value: signature }
  ] });
}

function ledgerError(code: string): GrainDiagError {
  return new GrainDiagError(code);
}

/**
 * Appends signed NES v0.1 ledger events through an application-owned signer.
 *
 * Order per write: reserve the sequence and persist it, sign, verify the
 * signature, persist the committed event, then report success. A failed or
 * uncertain save reloads durable state; if reloading fails the writer stops.
 * Sequences are never reused. Use one writer per store.
 */
export class SignedLedgerWriter {
  private readonly root: Uint8Array;
  private readonly rootKid: string;
  private readonly store: SignedLedgerStore;
  private state: JournalState;
  private stopped = false;
  private queue: Promise<unknown> = Promise.resolve();

  private constructor(root: Uint8Array, store: SignedLedgerStore, state: JournalState, private hasSnapshot: boolean) {
    this.root = root;
    this.rootKid = kidHex(root);
    this.store = store;
    this.state = state;
  }

  /** Open a writer for `trustedRootPublicKey`, restoring and re-verifying any saved snapshot. */
  static async open(options: { trustedRootPublicKey: Uint8Array; store: SignedLedgerStore }): Promise<SignedLedgerWriter> {
    const root = new Uint8Array(options.trustedRootPublicKey);
    if (root.length !== 32) throw ledgerError(SIGNED_LEDGER_ERR.TRUST);
    const saved = await options.store.load();
    return new SignedLedgerWriter(root, options.store, saved === null ? emptyState(root) : restoreSnapshot(root, saved), saved !== null);
  }

  get initialized(): boolean {
    return this.state.events.size > 0;
  }

  /** The reserved but uncommitted operation, if a previous write did not finish. */
  get pendingOperation(): { operationId: string; ak: string; seq: bigint; t: string } | null {
    const pending = this.state.pending;
    return pending ? { operationId: pending.operation, ak: pending.ak, seq: pending.seq, t: pending.t } : null;
  }

  /** Write the root-signed LedgerGenesis at root sequence 0. Idempotent. */
  initialize(rootSigner: GrainSigner): Promise<SignedLedgerReceipt> {
    return this.serialize(() => {
      if (!bytesEq(rootSigner.publicKey, this.root)) throw ledgerError(SIGNED_LEDGER_ERR.TRUST);
      return this.write(rootSigner, "genesis", "LedgerGenesis",
        toCborNode({ v: 1, t: "LedgerGenesis", root_kid: sha256(this.root).slice(0, 16), root_pub: this.root }), undefined, []);
    });
  }

  /** Root grants a device key (NES §6.2). */
  grantDevice(rootSigner: GrainSigner, input: { operationId: string; devicePublicKey: Uint8Array; caps?: string[] }): Promise<SignedLedgerReceipt> {
    return this.serialize(() => {
      this.requireRoot(rootSigner);
      const pub = new Uint8Array(input.devicePublicKey);
      if (pub.length !== 32) throw ledgerError(SIGNED_LEDGER_ERR.INVALID);
      const ak = kidHex(pub);
      if (ak === this.rootKid) throw ledgerError(SIGNED_LEDGER_ERR.INVALID);
      const caps = [...new Set(input.caps ?? ["write"])].sort((a, b) => compareBytesLex(utf8.encode(a), utf8.encode(b)));
      return this.write(rootSigner, input.operationId, "DeviceKeyGrant",
        toCborNode({ v: 1, t: "DeviceKeyGrant", ak: Buffer.from(ak, "hex"), pub, caps }), undefined, []);
    });
  }

  /** Root revokes a device key. Revocation is retroactive and permanent (NES §6.3). */
  revokeDevice(rootSigner: GrainSigner, input: { operationId: string; ak: string }): Promise<SignedLedgerReceipt> {
    return this.serialize(() => {
      this.requireRoot(rootSigner);
      if (!/^[0-9a-f]{32}$/.test(input.ak) || input.ak === this.rootKid || !this.granted().has(input.ak)) {
        throw ledgerError(SIGNED_LEDGER_ERR.INVALID);
      }
      return this.write(rootSigner, input.operationId, "DeviceKeyRevoke",
        toCborNode({ v: 1, t: "DeviceKeyRevoke", ak: Buffer.from(input.ak, "hex") }), undefined, []);
    });
  }

  /**
   * Append an event of any type. Known v0.1 types (IntakeEvent, VoidEvent,
   * CorrectionEvent, ...) must match their CDDL production including `v`/`t`;
   * other types are stored as opaque profile events (NES §2.3).
   */
  append(signer: GrainSigner, input: AppendSignedEventInput): Promise<SignedLedgerReceipt> {
    return this.serialize(() => {
      if (typeof input.t !== "string" || input.t.length === 0 || ROOT_ONLY_TYPES.has(input.t) || NON_EVENT_TYPES.has(input.t)) {
        throw ledgerError(SIGNED_LEDGER_ERR.INVALID);
      }
      const ak = kidHex(signer.publicKey);
      if (!bytesEq(this.state.keys.get(ak) ?? new Uint8Array(), signer.publicKey)) throw ledgerError(SIGNED_LEDGER_ERR.UNAUTHORIZED);
      if (typeof input.tsMs === "number" && !Number.isSafeInteger(input.tsMs)) throw ledgerError(SIGNED_LEDGER_ERR.INVALID);
      const tsMs = input.tsMs === undefined ? undefined : BigInt(input.tsMs);
      if (tsMs !== undefined && (tsMs < -(1n << 63n) || tsMs > MAX_SEQ)) throw ledgerError(SIGNED_LEDGER_ERR.INVALID);
      const objects = (input.objects ?? []).map((value): [string, Uint8Array] => {
        const bytes = encodeGrainValue(value);
        const cid = deriveCidV1DagCborSha256(bytes);
        verifyTransferObjects([[cid, bytes]], LEDGER_CODES);
        return [cid, bytes];
      });
      return this.write(signer, input.operationId, input.t, toCborNode(input.body), tsMs, objects);
    });
  }

  /** Export the shareable transfer JSON. Contains no private keys, but does contain the records. */
  exportTransfer(): Promise<string> {
    return this.serialize(async () => {
      if (!this.initialized) throw ledgerError(SIGNED_LEDGER_ERR.UNINITIALIZED);
      return exportTransferJson(this.root, this.state);
    });
  }

  /** Verify the current journal with the independent verifier. */
  async verify(): Promise<SignedLedgerVerification> {
    return verifySignedLedgerTransfer(await this.exportTransfer(), b64(this.root));
  }

  /**
   * Give up a reserved operation whose input is lost. The sequence number stays
   * consumed and is never reissued, so nothing that may already have been
   * signed can be contradicted.
   */
  abandonPendingOperation(): Promise<void> {
    return this.serialize(async () => {
      if (!this.state.pending) return;
      const next = cloneState(this.state);
      next.pending = null;
      await this.persist(next);
    });
  }

  private serialize<T>(task: () => Promise<T>): Promise<T> {
    const run = this.queue.then(() => {
      if (this.stopped) throw ledgerError(SIGNED_LEDGER_ERR.STORE);
      return task();
    });
    this.queue = run.catch(() => undefined);
    return run;
  }

  private requireRoot(signer: GrainSigner): void {
    if (!bytesEq(signer.publicKey, this.root)) throw ledgerError(SIGNED_LEDGER_ERR.UNAUTHORIZED);
    if (!this.initialized) throw ledgerError(SIGNED_LEDGER_ERR.UNINITIALIZED);
  }

  private granted(): Set<string> {
    return rootSignedTargets(this.rootKid, this.state.events, "DeviceKeyGrant");
  }

  private revoked(): Set<string> {
    return rootSignedTargets(this.rootKid, this.state.events, "DeviceKeyRevoke");
  }

  private async write(
    signer: GrainSigner,
    operation: string,
    t: string,
    body: CborNode,
    tsMs: bigint | undefined,
    objects: [string, Uint8Array][]
  ): Promise<SignedLedgerReceipt> {
    if (typeof operation !== "string" || !OPERATION_ID.test(operation)) throw ledgerError(SIGNED_LEDGER_ERR.INVALID);
    if (t !== "LedgerGenesis" && !this.initialized) throw ledgerError(SIGNED_LEDGER_ERR.UNINITIALIZED);
    const publicKey = new Uint8Array(signer.publicKey);
    const ak = kidHex(publicKey);
    const opKey = `${ak}:${operation}`;
    const digest = hex(sha256(encodeCanonical({ kind: "a", items: [
      textNode(t), body, tsMs === undefined ? { kind: "null" } : integerNode(tsMs),
      { kind: "a", items: objects.map(([, bytes]) => ({ kind: "b", value: bytes }) as CborNode) }
    ] })));

    const done = this.state.operations.get(opKey);
    if (done) {
      if (done.digest !== digest) throw ledgerError(SIGNED_LEDGER_ERR.OPERATION_CONFLICT);
      const event = this.state.events.get(done.payloadCid)!;
      if (!bytesEq(eventPayload(t, ak, event.seq, tsMs, body), event.payload)
        || objects.some(([cid]) => !this.state.objects.has(cid))) throw ledgerError(SIGNED_LEDGER_ERR.INVALID);
      return { status: "already_committed", payloadCid: done.payloadCid, ak, seq: event.seq, t: event.t };
    }

    // Completed receipts remain available after revocation. New signatures require current authority.
    if (ak !== this.rootKid && (!this.granted().has(ak) || this.revoked().has(ak))) throw ledgerError(SIGNED_LEDGER_ERR.UNAUTHORIZED);
    if (t === "DeviceKeyGrant" && this.revoked().has(hex(bytesOf(field(body, "ak", LEDGER_CODES), LEDGER_CODES)))) {
      throw ledgerError(SIGNED_LEDGER_ERR.INVALID);
    }

    // The v1 operation digest above covers the caller's ordered input, including repeats.
    // The snapshot and transfer store attachments by CID. Keep that distinction on recovery.
    const uniqueObjects = new Map(objects);
    let pending = this.state.pending;
    if (pending && (pending.operation !== operation || pending.ak !== ak)) throw ledgerError(SIGNED_LEDGER_ERR.PENDING);
    if (pending && pending.digest !== digest) throw ledgerError(SIGNED_LEDGER_ERR.OPERATION_CONFLICT);
    const last = this.state.counters.get(ak);
    const seq = pending?.seq ?? (t === "LedgerGenesis" ? 0n : (last ?? 0n) + 1n);
    if (seq > MAX_SEQ) throw ledgerError(SIGNED_LEDGER_ERR.LIMIT);
    if (KNOWN_TYPES.has(t)) validateTypedObjectV1(encodeCanonical(body), t);
    const payload = eventPayload(t, ak, seq, tsMs, body);
    if (pending) {
      // Only ever sign bytes rebuilt from the caller's input: a damaged or
      // altered snapshot must not be able to choose what this key signs.
      const savedObjectIds = new Set(pending.objects.map(([cid]) => cid));
      const sameObjects = savedObjectIds.size === uniqueObjects.size
        && [...savedObjectIds].every((cid) => uniqueObjects.has(cid));
      if (!sameObjects || !bytesEq(payload, pending.payload)) {
        throw ledgerError(SIGNED_LEDGER_ERR.INVALID);
      }
    }
    // COSE_Sign1 with Ed25519 always has a 64-byte signature; the byte content cannot change its length.
    const protectedBytes = protectedHeader(publicKey);
    const history = [...this.state.events.values()];
    const projectedCose = encodeEnvelope(protectedBytes, payload, new Uint8Array(64));
    const projectedObjects = new Map(this.state.objects);
    for (const [cid, bytes] of uniqueObjects) projectedObjects.set(cid, bytes);
    checkTransferBounds(this.root, [...history.map((event) => event.cose), projectedCose], projectedObjects);
    const proposed: ReducerEvent = {
      ak, seq, t, body,
      payloadCid: deriveCidV1DagCborSha256(payload),
      quarantined: bodyRequiresQuarantine(t, body)
    };
    reduceVerifiedEvents(this.rootKid, [...history, proposed], LEDGER_CODES);

    if (!pending) {
      pending = { operation, ak, seq, t, digest, payload, objects: [...uniqueObjects] };
      const reserved = cloneState(this.state);
      reserved.pending = pending;
      reserved.counters.set(ak, seq);
      await this.persist(reserved);
    }

    let signature: Uint8Array;
    try {
      signature = new Uint8Array(await signer.sign(sigStructure(protectedBytes, payload)));
    } catch {
      throw ledgerError(SIGNED_LEDGER_ERR.SIGNER);
    }
    const cose = encodeEnvelope(protectedBytes, payload, signature);
    let event: VerifiedEvent;
    try {
      event = verifyLedgerEventEnvelope(cose, publicKey, LEDGER_CODES);
    } catch {
      throw ledgerError(SIGNED_LEDGER_ERR.SIGNER);
    }

    const committed = cloneState(this.state);
    committed.events.set(event.payloadCid, event);
    for (const [cid, bytes] of pending.objects) committed.objects.set(cid, bytes);
    if (t === "DeviceKeyGrant") committed.keys.set(hex(bytesOf(field(body, "ak", LEDGER_CODES), LEDGER_CODES)), bytesOf(field(body, "pub", LEDGER_CODES), LEDGER_CODES));
    committed.operations.set(opKey, { payloadCid: event.payloadCid, digest });
    committed.pending = null;
    await this.persist(committed);
    return { status: "committed", payloadCid: event.payloadCid, ak, seq: event.seq, t };
  }

  private async persist(next: JournalState): Promise<void> {
    const proposed = snapshotJson(this.root, next);
    try {
      await this.store.save(proposed);
      this.hasSnapshot = true;
      this.state = next;
    } catch {
      try {
        const saved = await this.store.load();
        if (saved === null) {
          this.stopped = this.hasSnapshot;
        } else {
          const restored = restoreSnapshot(this.root, saved);
          const actual = snapshotJson(this.root, restored);
          // An atomic replace can leave either side of this write durable.
          if (actual !== proposed && actual !== snapshotJson(this.root, this.state)) {
            this.stopped = true;
          } else {
            this.state = restored;
            this.hasSnapshot = true;
          }
        }
      } catch {
        this.stopped = true;
      }
      throw ledgerError(SIGNED_LEDGER_ERR.STORE);
    }
  }
}

/** Canonical LedgerEvent payload bytes, validated against the typed production. */
function eventPayload(t: string, ak: string, seq: bigint, tsMs: bigint | undefined, body: CborNode): Uint8Array {
  const payload = encodeCanonical(mapNode([
    ["v", { kind: "u", value: 1n }],
    ["t", textNode(t)],
    ["ak", { kind: "b", value: Buffer.from(ak, "hex") }],
    ["seq", { kind: "u", value: seq }],
    ...(tsMs === undefined ? [] : [["ts_ms", integerNode(tsMs)] as [string, CborNode]]),
    ["body", body]
  ]));
  validateTypedObjectV1(payload, "LedgerEvent");
  return payload;
}

function rootSignedTargets(rootKid: string, events: Map<string, VerifiedEvent>, t: string): Set<string> {
  const out = new Set<string>();
  for (const event of events.values()) {
    if (!event.quarantined && event.ak === rootKid && event.t === t) out.add(hex(bytesOf(field(event.body, "ak", LEDGER_CODES), LEDGER_CODES)));
  }
  return out;
}

function emptyState(root: Uint8Array): JournalState {
  return {
    events: new Map(),
    objects: new Map(),
    keys: new Map([[kidHex(root), root]]),
    counters: new Map(),
    operations: new Map(),
    pending: null
  };
}

function cloneState(state: JournalState): JournalState {
  return {
    events: new Map(state.events),
    objects: new Map(state.objects),
    keys: new Map(state.keys),
    counters: new Map(state.counters),
    operations: new Map(state.operations),
    pending: state.pending
  };
}

function sortedEnvelopes(state: JournalState): string[] {
  return [...state.events.values()]
    .sort((a, b) => compareBytesLex(utf8.encode(a.payloadCid), utf8.encode(b.payloadCid)))
    .map((event) => b64(event.cose));
}

function sortedObjects(objects: Map<string, Uint8Array>): Record<string, string> {
  return Object.fromEntries([...objects.entries()].sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
    .map(([cid, bytes]) => [cid, b64(bytes)]));
}

function exportTransferJson(root: Uint8Array, state: JournalState): string {
  return JSON.stringify({ bundle_v: 1, root_pub_b64: b64(root), events: sortedEnvelopes(state), objects: sortedObjects(state.objects) });
}

/** Exact UTF-8 size of exportTransferJson. CIDs and base64 are unescaped ASCII in JSON. */
function checkTransferBounds(root: Uint8Array, envelopes: Uint8Array[], objects: Map<string, Uint8Array>): void {
  if (envelopes.length > SIGNED_TRANSFER_MAX_ITEMS || objects.size > SIGNED_TRANSFER_MAX_ITEMS) {
    throw ledgerError(SIGNED_LEDGER_ERR.LIMIT);
  }
  const base64Length = (bytes: Uint8Array) => 4 * Math.ceil(bytes.length / 3);
  let bytes = JSON.stringify({ bundle_v: 1, root_pub_b64: b64(root), events: [], objects: {} }).length;
  bytes += Math.max(0, envelopes.length - 1) + Math.max(0, objects.size - 1); // separators
  for (const cose of envelopes) {
    if (cose.length > SIGNED_TRANSFER_MAX_COSE_BYTES) throw ledgerError(SIGNED_LEDGER_ERR.LIMIT);
    bytes += 2 + base64Length(cose);
  }
  for (const [cid, object] of objects) bytes += 5 + cid.length + base64Length(object); // "cid":"base64"
  if (bytes > SIGNED_TRANSFER_MAX_BYTES) throw ledgerError(SIGNED_LEDGER_ERR.LIMIT);
}

function snapshotJson(root: Uint8Array, state: JournalState): string {
  const pending = state.pending;
  const snapshot: SnapshotV1 = {
    snapshot_v: 1,
    root_pub_b64: b64(root),
    events: sortedEnvelopes(state),
    objects: sortedObjects(state.objects),
    counters: Object.fromEntries([...state.counters.entries()].sort().map(([ak, seq]) => [ak, seq.toString()])),
    operations: Object.fromEntries([...state.operations.entries()].sort()
      .map(([key, value]) => [key, { payload_cid: value.payloadCid, input_sha256: value.digest }])),
    pending: pending ? {
      operation: pending.operation, ak: pending.ak, seq: pending.seq.toString(), t: pending.t,
      input_sha256: pending.digest, payload_b64: b64(pending.payload),
      objects: Object.fromEntries(pending.objects.map(([cid, bytes]) => [cid, b64(bytes)]))
    } : null
  };
  return JSON.stringify(snapshot);
}

function decimal(value: unknown): bigint {
  if (typeof value !== "string" || !/^(0|[1-9]\d*)$/.test(value)) return fail(SIGNED_LEDGER_ERR.INVALID);
  const parsed = BigInt(value);
  return parsed <= MAX_SEQ ? parsed : fail(SIGNED_LEDGER_ERR.INVALID);
}

/** Restore a private snapshot, re-verifying every event and the counter invariants. */
function restoreSnapshot(root: Uint8Array, json: string): JournalState {
  let raw: SnapshotV1;
  try { raw = JSON.parse(json) as SnapshotV1; } catch { return fail(SIGNED_LEDGER_ERR.INVALID); }
  if (!raw || raw.snapshot_v !== 1 || raw.root_pub_b64 !== b64(root) || !Array.isArray(raw.events)) return fail(SIGNED_LEDGER_ERR.INVALID);
  const state = emptyState(root);
  if (raw.events.length > 0) {
    const verified = verifyLedgerEvents(root, raw.events.map(unb64), LEDGER_CODES);
    state.events = verified.events;
    state.keys = verified.keys;
  }
  const objects = Object.entries(plainObject(raw.objects, LEDGER_CODES)).map(([cid, value]): [string, Uint8Array] => [cid, unb64(value as string)]);
  verifyTransferObjects(objects, LEDGER_CODES);
  state.objects = new Map(objects);
  for (const [ak, value] of Object.entries(plainObject(raw.counters, LEDGER_CODES))) state.counters.set(ak, decimal(value));
  checkTransferBounds(root, [...state.events.values()].map((event) => event.cose), state.objects);
  reduceVerifiedEvents(kidHex(root), [...state.events.values()], LEDGER_CODES);
  const occupied = new Set<string>();
  for (const event of state.events.values()) {
    const slot = `${event.ak}:${event.seq}`;
    if (occupied.has(slot)) return fail(SIGNED_LEDGER_ERR.INVALID);
    occupied.add(slot);
    const counter = state.counters.get(event.ak);
    if (counter === undefined || counter < event.seq) return fail(SIGNED_LEDGER_ERR.INVALID);
  }
  const indexed = new Set<string>();
  for (const [key, value] of Object.entries(plainObject(raw.operations, LEDGER_CODES))) {
    const entry = plainObject(value, LEDGER_CODES);
    if (typeof entry.payload_cid !== "string" || !state.events.has(entry.payload_cid) || typeof entry.input_sha256 !== "string") {
      return fail(SIGNED_LEDGER_ERR.INVALID);
    }
    const event = state.events.get(entry.payload_cid)!;
    const operation = key.slice(event.ak.length + 1);
    if (!key.startsWith(event.ak + ":") || !OPERATION_ID.test(operation) || indexed.has(entry.payload_cid)
      || !/^[a-f0-9]{64}$/.test(entry.input_sha256)
      || (event.t === "LedgerGenesis" && operation !== "genesis")) return fail(SIGNED_LEDGER_ERR.INVALID);
    indexed.add(entry.payload_cid);
    state.operations.set(key, { payloadCid: entry.payload_cid, digest: entry.input_sha256 });
  }
  if (indexed.size !== state.events.size) return fail(SIGNED_LEDGER_ERR.INVALID);
  if (raw.pending) {
    const pending = plainObject(raw.pending, LEDGER_CODES);
    const seq = decimal(pending.seq);
    const payload = unb64(pending.payload_b64 as string);
    const node = validateTypedObjectV1(payload, "LedgerEvent");
    const ak = hex(bytesOf(field(node, "ak", LEDGER_CODES), LEDGER_CODES));
    const pendingObjects = Object.entries(plainObject(pending.objects, LEDGER_CODES))
      .map(([cid, value]): [string, Uint8Array] => [cid, unb64(value as string)]);
    verifyTransferObjects(pendingObjects, LEDGER_CODES);
    if (ak !== pending.ak || unsignedOf(field(node, "seq", LEDGER_CODES), LEDGER_CODES) !== seq
      || textOf(field(node, "t", LEDGER_CODES), LEDGER_CODES) !== pending.t
      || state.counters.get(ak) !== seq || occupied.has(`${ak}:${seq}`)
      || typeof pending.operation !== "string" || !OPERATION_ID.test(pending.operation)
      || state.operations.has(`${ak}:${pending.operation}`)
      || typeof pending.input_sha256 !== "string" || !/^[a-f0-9]{64}$/.test(pending.input_sha256)
      || (pending.t === "LedgerGenesis" ? (state.events.size !== 0 || ak !== kidHex(root) || seq !== 0n || pending.operation !== "genesis")
        : (state.events.size === 0 || seq === 0n))) {
      return fail(SIGNED_LEDGER_ERR.INVALID);
    }
    state.pending = {
      operation: pending.operation, ak, seq, t: pending.t as string, digest: pending.input_sha256,
      payload, objects: pendingObjects
    };
  }
  return state;
}
