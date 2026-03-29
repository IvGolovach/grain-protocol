import {
  createDecipheriv,
  createPublicKey,
  hkdfSync,
  verify
} from "node:crypto";
import { inflateSync } from "node:zlib";

import {
  GrainDiagError,
  LIMITS,
  type ParseOptions
} from "./types.js";
import type { CborNode, Json, OperationActual } from "./types.js";
import {
  encodeCanonical,
  GENERIC_CBOR_CANONICAL_OPTIONS,
  GENERIC_CBOR_LENIENT_OPTIONS,
  STRICT_DAG_CBOR_OPTIONS,
  mapGet,
  nodeAsBytes,
  nodeAsText,
  nodeAsU,
  parseExact,
  parseOne,
  validateSetArrayUtf8
} from "./cbor.js";
import { base45Decode } from "./base45.js";
import {
  bytesEq,
  compareBytesLex,
  decodeB64,
  encodeB64,
  normalizeDiag,
  sha256,
  sha256Hex
} from "./utils.js";

const KEY_INFO = Buffer.from("GrainE2E\0v0.1\0A256GCM\0key", "ascii");
const NONCE_INFO_PREFIX = Buffer.from("GrainE2E\0v0.1\0A256GCM\0nonce\0", "ascii");
const I64_MIN = -(1n << 63n);
const I64_MAX = (1n << 63n) - 1n;
const ED25519_SPKI_PREFIX = Buffer.from("302a300506032b6570032100", "hex");

export function executeOperation(op: string, input: Record<string, Json>, strict: boolean): OperationActual {
  if (!strict) {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }

  switch (op) {
    case "dagcbor_validate":
      return opDagCborValidate(input);
    case "cid_derive":
      return opCidDerive(input);
    case "cose_verify":
      return opCoseVerify(input);
    case "qr_decode_gr1":
      return opQrDecodeGr1(input);
    case "parse_cborseq_stream_v1":
      return opParseCborSeq(input);
    case "ledger_reduce":
      return opLedgerReduce(input);
    case "e2e_derive_v1":
      return opE2eDerive(input);
    case "e2e_decrypt":
      return opE2eDecrypt(input);
    case "manifest_resolve":
      return opManifestResolve(input);
    default:
      throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }
}

function opDagCborValidate(input: Record<string, Json>): OperationActual {
  const bytes = decodeB64(input.bytes_b64);
  validateDagCborStrict(bytes);
  return { accepted: true, diag: [], out: {} };
}

function opCidDerive(input: Record<string, Json>): OperationActual {
  const bytes = decodeB64(input.bytes_b64);
  validateDagCborStrict(bytes);
  return {
    accepted: true,
    diag: [],
    out: {
      cid: deriveCidV1DagCborSha256(bytes)
    }
  };
}

function opCoseVerify(input: Record<string, Json>): OperationActual {
  const coseBytes = decodeB64(input.cose_b64);
  const pubKey = decodeB64(input.pub_b64);
  const externalAad = decodeB64(input.external_aad_b64);

  if (isTopLevelTag18(coseBytes)) {
    throw new GrainDiagError("GRAIN_ERR_COSE_TAG18_FORBIDDEN");
  }

  if (externalAad.length !== 0) {
    throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
  }

  const top = parseExact(coseBytes, GENERIC_CBOR_CANONICAL_OPTIONS);
  const topCanonical = encodeCanonical(top);
  if (!bytesEq(topCanonical, coseBytes)) {
    throw new GrainDiagError("GRAIN_ERR_NONCANONICAL");
  }

  if (top.kind !== "a" || top.items.length !== 4) {
    throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
  }

  const protectedBstr = nodeAsBytes(top.items[0]);
  if (!protectedBstr) {
    throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
  }

  const unprotected = top.items[1];
  if (unprotected.kind !== "m" || unprotected.entries.length !== 0) {
    throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
  }

  const payload = nodeAsBytes(top.items[2]);
  const sigBytes = nodeAsBytes(top.items[3]);
  if (!payload || !sigBytes || sigBytes.length !== 64) {
    throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
  }

  const protectedNode = parseExact(protectedBstr, GENERIC_CBOR_CANONICAL_OPTIONS);
  const protectedCanonical = encodeCanonical(protectedNode);
  if (!bytesEq(protectedCanonical, protectedBstr)) {
    throw new GrainDiagError("GRAIN_ERR_NONCANONICAL");
  }

  if (protectedNode.kind !== "m" || protectedNode.entries.length !== 2) {
    throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
  }

  let algOk = false;
  let kidOk = false;
  for (const entry of protectedNode.entries) {
    if (entry.key.kind !== "u") {
      throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
    }

    if (entry.key.value === 1n) {
      if (entry.value.kind !== "n" || entry.value.value !== -19n) {
        throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
      }
      algOk = true;
      continue;
    }

    if (entry.key.value === 4n) {
      if (entry.value.kind !== "b") {
        throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
      }
      kidOk = true;
      continue;
    }

    throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
  }

  if (!(algOk && kidOk)) {
    throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
  }

  if (pubKey.length !== 32) {
    throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
  }

  const sigStructure: CborNode = {
    kind: "a",
    items: [
      { kind: "t", bytes: new TextEncoder().encode("Signature1") },
      { kind: "b", value: protectedBstr },
      { kind: "b", value: externalAad },
      { kind: "b", value: payload }
    ]
  };

  const toSign = encodeCanonical(sigStructure);
  const keyDer = Buffer.concat([ED25519_SPKI_PREFIX, Buffer.from(pubKey)]);

  let keyObj;
  try {
    keyObj = createPublicKey({ key: keyDer, format: "der", type: "spki" });
  } catch {
    throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
  }

  let ok = false;
  try {
    ok = verify(null, Buffer.from(toSign), keyObj, Buffer.from(sigBytes));
  } catch {
    throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
  }

  if (!ok) {
    throw new GrainDiagError("GRAIN_ERR_COSE_PROFILE");
  }

  return { accepted: true, diag: [], out: {} };
}

function opQrDecodeGr1(input: Record<string, Json>): OperationActual {
  const qr = input.qr_string;
  if (typeof qr !== "string") {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }
  if (!qr.startsWith("GR1:")) {
    throw new GrainDiagError("GRAIN_ERR_QR_PREFIX");
  }

  const body = qr.slice(4);
  const compressed = base45Decode(body);
  let cose: Uint8Array;
  try {
    cose = new Uint8Array(inflateSync(Buffer.from(compressed)));
  } catch {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }
  return {
    accepted: true,
    diag: [],
    out: {
      cose_b64: encodeB64(cose)
    }
  };
}

function opParseCborSeq(input: Record<string, Json>): OperationActual {
  const streamKind = input.stream_kind;
  if (streamKind !== "ledger" && streamKind !== "manifest") {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }

  const hasCborseq = Object.hasOwn(input, "cborseq_b64");
  const hasSegments = Object.hasOwn(input, "segments_b64");
  if (hasCborseq === hasSegments) {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }

  let stream: Uint8Array;
  if (hasCborseq) {
    stream = decodeB64(input.cborseq_b64);
  } else {
    if (!Array.isArray(input.segments_b64)) {
      throw new GrainDiagError("GRAIN_ERR_SCHEMA");
    }
    const all: number[] = [];
    for (const seg of input.segments_b64) {
      const b = decodeB64(seg);
      for (const x of b) all.push(x);
    }
    stream = new Uint8Array(all);
  }

  if (stream.length > LIMITS.CBL_MAX_CBORSEQ_SEGMENT_BYTES) {
    throw new GrainDiagError("GRAIN_ERR_LIMIT");
  }

  const digests: string[] = [];

  if (stream.length === 0) {
    return { accepted: true, diag: [], out: { item_sha256_hex: digests } };
  }

  let pos = 0;
  while (pos < stream.length) {
    try {
      const parsed = parseOne(stream.slice(pos), GENERIC_CBOR_LENIENT_OPTIONS as ParseOptions);
      if (parsed.used <= 0) {
        throw new GrainDiagError(pos === 0 ? "GRAIN_ERR_CBORSEQ_INVALID_INITIAL_BYTE" : "GRAIN_ERR_CBORSEQ_GARBAGE_TAIL");
      }
      const item = stream.slice(pos, pos + parsed.used);
      digests.push(sha256Hex(item));
      pos += parsed.used;

      if (digests.length > LIMITS.CBL_MAX_CBORSEQ_SEGMENT_ITEMS) {
        throw new GrainDiagError("GRAIN_ERR_LIMIT");
      }
    } catch (err) {
      if (err instanceof GrainDiagError) {
        if (err.code === "GRAIN_ERR_CBORSEQ_TRUNCATED") {
          throw err;
        }
        if (err.code === "CBOR_TRUNCATED_INTERNAL") {
          throw new GrainDiagError("GRAIN_ERR_CBORSEQ_TRUNCATED");
        }
        if (err.code === "GRAIN_ERR_NONCANONICAL") {
          throw new GrainDiagError(pos === 0 ? "GRAIN_ERR_CBORSEQ_INVALID_INITIAL_BYTE" : "GRAIN_ERR_CBORSEQ_GARBAGE_TAIL");
        }
        throw err;
      }
      throw new GrainDiagError("GRAIN_ERR_CBORSEQ_TRUNCATED");
    }
  }

  return { accepted: true, diag: [], out: { item_sha256_hex: digests } };
}

function opLedgerReduce(input: Record<string, Json>): OperationActual {
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

  const pairPayloads = new Map<string, Set<string>>();
  for (const ev of authorizedEvents) {
    const key = `${ev.ak}\u0000${ev.seq.toString()}`;
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
  if (conflicted.size > 0) {
    diagnostics.add("SEQ_CONFLICT");
  }

  let sumMean = 0n;
  let sumVar = 0n;
  const seenExact = new Set<string>();

  for (const ev of authorizedEvents) {
    const pairKey = `${ev.ak}\u0000${ev.seq.toString()}`;
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

function opE2eDerive(input: Record<string, Json>): OperationActual {
  const syncSecret = decodeB64(input.sync_secret_b64);
  const capId = decodeB64(input.cap_id_b64);
  const cidLinkBstr = decodeB64(input.cid_link_bstr_b64);

  const derived = deriveKeyNonce(syncSecret, capId, cidLinkBstr);
  return {
    accepted: true,
    diag: [],
    out: {
      key_b64: encodeB64(derived.key),
      nonce_b64: encodeB64(derived.nonce)
    }
  };
}

function opE2eDecrypt(input: Record<string, Json>): OperationActual {
  const encryptedObjectBytes = decodeB64(input.encrypted_object_b64);
  const syncSecret = decodeB64(input.sync_secret_b64);
  const cidLink = decodeB64(input.cid_link_b64);

  if (encryptedObjectBytes.length > LIMITS.CBL_MAX_E2E_CIPHERTEXT_BYTES) {
    throw new GrainDiagError("GRAIN_ERR_LIMIT");
  }

  if (input.manifest_chash_b64 !== undefined) {
    const expected = decodeB64(input.manifest_chash_b64);
    const actual = sha256(encryptedObjectBytes);
    if (!bytesEq(expected, actual)) {
      throw new GrainDiagError("CHASH_MISMATCH");
    }
  }

  const node = parseExact(encryptedObjectBytes, STRICT_DAG_CBOR_OPTIONS);
  schemaChecks(node);

  if (node.kind !== "m") {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }

  const t = nodeAsText(mapGet(node, "t"));
  const v = nodeAsU(mapGet(node, "v"));
  const alg = nodeAsText(mapGet(node, "alg"));
  const capId = nodeAsBytes(mapGet(node, "cap_id"));
  const nonceEnv = nodeAsBytes(mapGet(node, "nonce"));
  const ct = nodeAsBytes(mapGet(node, "ct"));

  if (t !== "EncryptedObject" || v !== 1n || alg !== "A256GCM" || !capId || !nonceEnv || !ct) {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }

  if (capId.length !== 32 || nonceEnv.length !== 12) {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }

  const derived = deriveKeyNonce(syncSecret, capId, cidLink);

  let pt: Uint8Array;
  try {
    const decipher = createDecipheriv("aes-256-gcm", Buffer.from(derived.key), Buffer.from(derived.nonce), {
      authTagLength: 16
    });
    decipher.setAAD(Buffer.from(capId));

    if (ct.length < 16) {
      throw new GrainDiagError("GRAIN_ERR_AEAD_AUTH");
    }
    const body = ct.slice(0, ct.length - 16);
    const tag = ct.slice(ct.length - 16);
    decipher.setAuthTag(Buffer.from(tag));

    const plain = Buffer.concat([decipher.update(Buffer.from(body)), decipher.final()]);
    pt = new Uint8Array(plain);
  } catch {
    throw new GrainDiagError("GRAIN_ERR_AEAD_AUTH");
  }

  if (!bytesEq(nonceEnv, derived.nonce)) {
    throw new GrainDiagError("NONCE_PROFILE_MISMATCH");
  }

  return {
    accepted: true,
    diag: [],
    out: {
      pt_b64: encodeB64(pt)
    }
  };
}

function opManifestResolve(input: Record<string, Json>): OperationActual {
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
    if (!capToChash.has(capHex)) capToChash.set(capHex, new Set());
    capToChash.get(capHex)?.add(chashHex);
  }

  const conflicted = new Set<string>();
  for (const [capHex, hashes] of capToChash.entries()) {
    if (hashes.size > 1) conflicted.add(capHex);
  }

  const diagnostics: string[] = [];
  const filtered = puts.filter((r) => !conflicted.has(Buffer.from(r.capId ?? new Uint8Array()).toString("hex")));
  if (conflicted.size > 0) diagnostics.push("CAP_CHASH_CONFLICT");

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

function validateDagCborStrict(bytes: Uint8Array): CborNode {
  if (bytes.length > LIMITS.CBL_MAX_DAGCBOR_OBJECT_BYTES) {
    throw new GrainDiagError("GRAIN_ERR_LIMIT");
  }

  const node = parseExact(bytes, STRICT_DAG_CBOR_OPTIONS);
  schemaChecks(node);
  return node;
}

function schemaChecks(node: CborNode): void {
  if (node.kind !== "m") {
    return;
  }

  const t = nodeAsText(mapGet(node, "t"));
  if (!t) return;

  const allowed = allowedTopLevelKeys(t);
  if (allowed) {
    const allowedSet = new Set(allowed);
    for (const entry of node.entries) {
      if (entry.key.kind !== "t") {
        throw new GrainDiagError("GRAIN_ERR_NONCANONICAL");
      }
      const key = new TextDecoder().decode(entry.key.bytes);
      if (!allowedSet.has(key)) {
        throw new GrainDiagError("GRAIN_ERR_UNKNOWN_TOPLEVEL_KEY");
      }
    }
  }

  const crit = mapGet(node, "crit");
  if (crit) {
    if (crit.kind !== "a") throw new GrainDiagError("GRAIN_ERR_SCHEMA");
    if (crit.items.length > 64) throw new GrainDiagError("GRAIN_ERR_LIMIT");
    let total = 0;
    for (const it of crit.items) {
      if (it.kind !== "t") throw new GrainDiagError("GRAIN_ERR_SCHEMA");
      total += it.bytes.length;
    }
    if (total > 4096) throw new GrainDiagError("GRAIN_ERR_LIMIT");

    const check = validateSetArrayUtf8(crit);
    if (!check.orderOk) throw new GrainDiagError("GRAIN_ERR_SET_ARRAY_ORDER");
    if (!check.uniqueOk) throw new GrainDiagError("GRAIN_ERR_SET_ARRAY_DUP");
  }

  if (t === "DeviceKeyGrant") {
    const caps = mapGet(node, "caps");
    if (caps) {
      const check = validateSetArrayUtf8(caps);
      if (!check.orderOk) throw new GrainDiagError("GRAIN_ERR_SET_ARRAY_ORDER");
      if (!check.uniqueOk) throw new GrainDiagError("GRAIN_ERR_SET_ARRAY_DUP");
    }
  }
}

function deriveKeyNonce(syncSecret: Uint8Array, capId: Uint8Array, cidLinkBstr: Uint8Array): { key: Uint8Array; nonce: Uint8Array } {
  if (syncSecret.length !== 32 || capId.length !== 32) {
    throw new GrainDiagError("GRAIN_ERR_E2E_INPUT_LENGTH");
  }
  if (cidLinkBstr.length === 0 || cidLinkBstr[0] !== 0x00) {
    throw new GrainDiagError("GRAIN_ERR_BAD_CID_LINK");
  }

  const key = new Uint8Array(hkdfSync("sha256", Buffer.from(syncSecret), Buffer.from(capId), KEY_INFO, 32));
  const nonceInfo = Buffer.concat([NONCE_INFO_PREFIX, Buffer.from(cidLinkBstr)]);
  const nonce = new Uint8Array(hkdfSync("sha256", Buffer.from(syncSecret), Buffer.from(capId), nonceInfo, 12));
  return { key, nonce };
}

function deriveCidV1DagCborSha256(bytes: Uint8Array): string {
  const digest = sha256(bytes);
  const cidBytes: number[] = [];
  pushVarint(1n, cidBytes);
  pushVarint(0x71n, cidBytes);
  pushVarint(0x12n, cidBytes);
  pushVarint(32n, cidBytes);
  for (const b of digest) {
    cidBytes.push(b);
  }
  return `b${base32LowerNoPad(new Uint8Array(cidBytes))}`;
}

function pushVarint(v: bigint, out: number[]): void {
  if (v < 0n) {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }

  let x = v;
  while (true) {
    let b = Number(x & 0x7fn);
    x >>= 7n;
    if (x !== 0n) {
      b |= 0x80;
    }
    out.push(b);
    if (x === 0n) {
      break;
    }
  }
}

function base32LowerNoPad(data: Uint8Array): string {
  const alphabet = "abcdefghijklmnopqrstuvwxyz234567";
  let out = "";
  let buffer = 0;
  let bits = 0;

  for (const byte of data) {
    buffer = (buffer << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      const idx = (buffer >> (bits - 5)) & 0x1f;
      out += alphabet[idx];
      bits -= 5;
    }
  }

  if (bits > 0) {
    const idx = (buffer << (5 - bits)) & 0x1f;
    out += alphabet[idx];
  }

  return out;
}

function isTopLevelTag18(bytes: Uint8Array): boolean {
  if (bytes.length === 0) {
    return false;
  }

  const b0 = bytes[0];
  const major = b0 >> 5;
  const ai = b0 & 0x1f;

  if (major !== 6) {
    return false;
  }

  if (ai === 18) {
    return true;
  }
  if (ai === 24) {
    return bytes.length >= 2 && bytes[1] === 18;
  }
  if (ai === 25) {
    return bytes.length >= 3 && bytes[1] === 0 && bytes[2] === 18;
  }

  return false;
}

type ManifestRecord = {
  op: "put" | "del";
  capId?: Uint8Array;
  chash?: Uint8Array;
};

type LedgerEvent = {
  t: string;
  ak: string;
  seq: bigint;
  payloadCid: string;
  body: Record<string, Json>;
};

function parseManifestRecords(value: Json | undefined): ManifestRecord[] {
  if (value === undefined) return [];
  if (!Array.isArray(value)) {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }

  const out: ManifestRecord[] = [];
  for (const rec of value) {
    if (rec === null || typeof rec !== "object" || Array.isArray(rec)) {
      throw new GrainDiagError("GRAIN_ERR_SCHEMA");
    }
    const r = rec as Record<string, Json>;
    const op = r.op;
    if (op !== "put" && op !== "del") {
      throw new GrainDiagError("GRAIN_ERR_MANIFEST_OP");
    }

    const cap = r.cap_id_b64 !== undefined ? decodeB64(r.cap_id_b64) : undefined;
    const chash = r.chash_b64 !== undefined ? decodeB64(r.chash_b64) : undefined;

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

function textFromObjectField(obj: Record<string, Json>, key: string): string | undefined {
  const value = obj[key];
  if (value === undefined) {
    return undefined;
  }
  if (typeof value !== "string") {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }
  return value;
}

function parseInteger(value: Json | undefined, code: string): bigint {
  if (typeof value === "number") {
    if (!Number.isSafeInteger(value)) {
      throw new GrainDiagError(code);
    }
    return BigInt(value);
  }

  if (typeof value === "string") {
    if (!/^-?[0-9]+$/.test(value)) {
      throw new GrainDiagError(code);
    }
    return BigInt(value);
  }

  throw new GrainDiagError(code);
}

function toText(value: Json | undefined, code: string): string {
  if (typeof value !== "string") {
    throw new GrainDiagError(code);
  }
  return value;
}

function toObject(value: Json | undefined, code: string): Record<string, Json> {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new GrainDiagError(code);
  }
  return value as Record<string, Json>;
}

function withDiag(base: Record<string, Json>, diagnostics: string[]): Record<string, Json> {
  if (diagnostics.length === 0) {
    return base;
  }
  return {
    ...base,
    diag_contains: normalizeDiag(diagnostics)
  };
}

function allowedTopLevelKeys(t: string): string[] | undefined {
  switch (t) {
    case "IngredientRef":
      return ["v", "t", "ref_type", "ref_id", "ref_version", "name", "ext", "crit"];
    case "NutrientProfile":
      return ["v", "t", "dataset_snapshot_id", "source", "basis", "nutr", "uncert", "ext", "crit"];
    case "CookRun":
      return ["v", "t", "inputs", "yield_g", "ts_ms", "ext", "crit"];
    case "NutritionComputeResult":
      return ["v", "t", "cookrun", "engine_id", "engine_version", "dataset_snapshot_id", "map", "out", "ext", "crit"];
    case "IntakeEvent":
      return ["v", "t", "source_class", "mean", "var", "mode", "cookrun", "amount_g", "ing", "profile", "servings", "ts_ms", "ext", "crit"];
    case "ServingOffer":
      return ["v", "t", "issuer_kid", "serving_g", "mean", "var", "nonce", "ext", "crit"];
    case "LedgerGenesis":
      return ["v", "t", "root_kid", "root_pub", "ext", "crit"];
    case "DeviceKeyGrant":
      return ["v", "t", "ak", "pub", "caps", "ext", "crit"];
    case "DeviceKeyRevoke":
      return ["v", "t", "ak", "ext", "crit"];
    case "VoidEvent":
      return ["v", "t", "target", "reason", "ext", "crit"];
    case "CorrectionEvent":
      return ["v", "t", "target", "reason", "ext", "crit"];
    case "LedgerEvent":
      return ["v", "t", "ak", "seq", "ts_ms", "body", "ext", "crit"];
    case "EncryptedObject":
      return ["v", "t", "alg", "cap_id", "nonce", "ct", "ext", "crit"];
    case "ManifestRecord":
      return ["v", "t", "ak", "seq", "cid", "op", "cap_id", "chash", "size", "ext", "crit"];
    default:
      return undefined;
  }
}
