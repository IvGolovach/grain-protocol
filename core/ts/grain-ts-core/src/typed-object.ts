import {
  STRICT_DAG_CBOR_OPTIONS,
  encodeCanonical,
  mapGet,
  parseExact,
  validateSetArrayUtf8
} from "./cbor.js";
import { schemaForObjectTypeV1 } from "./object-schema.js";
import type { ObjectSchemaV1, ObjectTypeV1, PayloadLimitV1 } from "./object-schema.js";
import { GrainDiagError, LIMITS } from "./types.js";
import type { CborNode } from "./types.js";
import { bytesEq, compareBytesLex, decodeUtf8 } from "./utils.js";

type CborMap = Extract<CborNode, { kind: "m" }>;
type ItemValidator = (value: CborNode) => void;

const COOK_INPUT_KEYS = ["ing", "amount_g", "note", "ext", "crit"] as const;
const MAP_DECISION_KEYS = ["ing", "profile", "ext", "crit"] as const;
const EVENT_REF_KEYS = ["ak", "seq"] as const;
const CID_LINK_PREFIX = new Uint8Array([0x00, 0x01, 0x71, 0x12, 0x20]);
const CID_LINK_BSTR_LEN = CID_LINK_PREFIX.length + 32;
const I64_MIN = -(1n << 63n);
const I64_MAX = (1n << 63n) - 1n;

export function parseDagCborStrict(bytes: Uint8Array): CborNode {
  if (bytes.length > LIMITS.CBL_MAX_DAGCBOR_OBJECT_BYTES) {
    throw new GrainDiagError("GRAIN_ERR_LIMIT");
  }
  return parseExact(bytes, STRICT_DAG_CBOR_OPTIONS);
}

export function validateTypedObjectV1(bytes: Uint8Array, objectType: string): CborNode {
  const schema = schemaForObjectTypeV1(objectType);
  if (schema) {
    validateContextPayloadLimit(bytes, schema.payloadLimit);
  }

  const value = parseDagCborStrict(bytes);
  validateAllCidLinks(value);
  if (!schema) {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }
  const map = expectMap(value);

  validateEnvelope(map, schema);
  validateTopLevelKeys(map, schema.allowedTopLevelKeys);
  validateCommonFields(map);

  switch (schema.objectType) {
    case "IngredientRef":
      validateIngredientRef(map);
      break;
    case "NutrientProfile":
      validateNutrientProfile(map);
      break;
    case "CookRun":
      validateCookRun(map);
      break;
    case "NutritionComputeResult":
      validateNutritionComputeResult(map);
      break;
    case "IntakeEvent":
      validateIntakeEvent(map);
      break;
    case "ServingOffer":
      validateServingOffer(map);
      break;
    case "LedgerGenesis":
      validateLedgerGenesis(map);
      break;
    case "DeviceKeyGrant":
      validateDeviceKeyGrant(map);
      break;
    case "DeviceKeyRevoke":
      validateDeviceKeyRevoke(map);
      break;
    case "VoidEvent":
    case "CorrectionEvent":
      validateTargetEvent(map);
      break;
    case "LedgerEvent":
      validateLedgerEvent(map);
      break;
    case "EncryptedObject":
      validateEncryptedObject(map);
      break;
    case "ManifestRecord":
      validateManifestRecord(map);
      break;
    default:
      assertNever(schema.objectType);
  }

  return value;
}

function validateContextPayloadLimit(bytes: Uint8Array, limit: PayloadLimitV1): void {
  let max: number;
  switch (limit) {
    case "dagcbor_object":
      max = LIMITS.CBL_MAX_DAGCBOR_OBJECT_BYTES;
      break;
    case "ledger_event":
      max = LIMITS.CBL_MAX_LEDGER_EVENT_PAYLOAD_BYTES;
      break;
    case "manifest_record":
      max = LIMITS.CBL_MAX_MANIFEST_RECORD_PAYLOAD_BYTES;
      break;
    case "serving_offer":
      max = LIMITS.CBL_MAX_SERVINGOFFER_PAYLOAD_BYTES;
      break;
    case "encrypted_object":
      max = LIMITS.CBL_MAX_E2E_CIPHERTEXT_BYTES;
      break;
    default:
      assertNever(limit);
  }
  if (bytes.length > max) {
    throw new GrainDiagError("GRAIN_ERR_LIMIT");
  }
}

function validateEnvelope(map: CborMap, schema: ObjectSchemaV1): void {
  const version = mapGet(map, "v");
  if (!version || version.kind !== "u" || version.value !== 1n) {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }

  const actualT = requireText(map, "t");
  if (schema.literalT !== undefined && !bytesEq(actualT, new TextEncoder().encode(schema.literalT))) {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }
}

function validateTopLevelKeys(map: CborMap, allowed: readonly string[]): void {
  const allowedSet = new Set(allowed);
  for (const entry of map.entries) {
    if (entry.key.kind !== "t") {
      throw new GrainDiagError("GRAIN_ERR_NONCANONICAL");
    }
    if (!allowedSet.has(decodeUtf8(entry.key.bytes))) {
      throw new GrainDiagError("GRAIN_ERR_UNKNOWN_TOPLEVEL_KEY");
    }
  }
}

function validateNestedKeys(map: CborMap, allowed: readonly string[]): void {
  const allowedSet = new Set(allowed);
  for (const entry of map.entries) {
    if (entry.key.kind !== "t") {
      throw new GrainDiagError("GRAIN_ERR_NONCANONICAL");
    }
    if (!allowedSet.has(decodeUtf8(entry.key.bytes))) {
      throw new GrainDiagError("GRAIN_ERR_SCHEMA");
    }
  }
}

function validateCommonFields(map: CborMap): void {
  const ext = mapGet(map, "ext");
  if (ext) {
    if (ext.kind !== "m") {
      throw new GrainDiagError("GRAIN_ERR_SCHEMA");
    }
    if (encodeCanonical(ext).length > LIMITS.CBL_MAX_EXT_CANONICAL_BYTES) {
      throw new GrainDiagError("GRAIN_ERR_LIMIT");
    }
  }

  const crit = mapGet(map, "crit");
  if (crit) {
    validateTstrSetArray(crit, true);
  }
}

function validateIngredientRef(map: CborMap): void {
  requireText(map, "ref_type");
  requireText(map, "ref_id");
  optionalText(map, "ref_version");
  optionalText(map, "name");
}

function validateNutrientProfile(map: CborMap): void {
  requireText(map, "dataset_snapshot_id");
  requireText(map, "source");
  requireText(map, "basis");
  validateNutrientMap(requireField(map, "nutr"), false);
  const uncert = mapGet(map, "uncert");
  if (uncert) {
    validateNutrientMap(uncert, true);
  }
}

function validateCookRun(map: CborMap): void {
  validateStructuredSetArray(requireField(map, "inputs"), validateCookInput);
  optionalNonnegativeInt64(map, "yield_g");
  optionalInt64(map, "ts_ms");
}

function validateCookInput(value: CborNode): void {
  const map = expectMap(value);
  validateNestedKeys(map, COOK_INPUT_KEYS);
  validateCommonFields(map);
  validateCidLink(requireField(map, "ing"));
  requireNonnegativeInt64(map, "amount_g");
  optionalText(map, "note");
}

function validateNutritionComputeResult(map: CborMap): void {
  validateCidLink(requireField(map, "cookrun"));
  requireText(map, "engine_id");
  requireText(map, "engine_version");
  requireText(map, "dataset_snapshot_id");
  validateStructuredSetArray(requireField(map, "map"), validateMapDecision);
  validateNutrientMap(requireField(map, "out"), false);
}

function validateMapDecision(value: CborNode): void {
  const map = expectMap(value);
  validateNestedKeys(map, MAP_DECISION_KEYS);
  validateCommonFields(map);
  validateCidLink(requireField(map, "ing"));
  validateCidLink(requireField(map, "profile"));
}

function validateIntakeEvent(map: CborMap): void {
  const sourceClass = decodeUtf8(requireText(map, "source_class"));
  if (sourceClass !== "attested" && sourceClass !== "measured" && sourceClass !== "estimated") {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }

  validateNutrientMap(requireField(map, "mean"), false);
  validateNutrientMap(requireField(map, "var"), true);
  optionalInt64(map, "ts_ms");

  switch (decodeUtf8(requireText(map, "mode"))) {
    case "from_cookrun":
      validateCidLink(requireField(map, "cookrun"));
      requireNonnegativeInt64(map, "amount_g");
      forbidFields(map, ["ing", "profile", "servings"]);
      break;
    case "from_ingredient":
      validateCidLink(requireField(map, "ing"));
      requireNonnegativeInt64(map, "amount_g");
      forbidFields(map, ["cookrun", "profile", "servings"]);
      break;
    case "from_profile":
      validateCidLink(requireField(map, "profile"));
      requireNonnegativeInt64(map, "servings");
      forbidFields(map, ["cookrun", "ing", "amount_g"]);
      break;
    default:
      throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }
}

function validateServingOffer(map: CborMap): void {
  requireBytesLength(map, "issuer_kid", 16);
  requireNonnegativeInt64(map, "serving_g");
  validateNutrientMap(requireField(map, "mean"), false);
  validateNutrientMap(requireField(map, "var"), true);
  optionalBytes(map, "nonce");
}

function validateLedgerGenesis(map: CborMap): void {
  requireBytesLength(map, "root_kid", 16);
  requireBytesLength(map, "root_pub", 32);
}

function validateDeviceKeyGrant(map: CborMap): void {
  requireBytesLength(map, "ak", 16);
  requireBytesLength(map, "pub", 32);
  validateTstrSetArray(requireField(map, "caps"), false);
}

function validateDeviceKeyRevoke(map: CborMap): void {
  requireBytesLength(map, "ak", 16);
}

function validateTargetEvent(map: CborMap): void {
  validateEventRef(requireField(map, "target"));
  optionalText(map, "reason");
}

function validateEventRef(value: CborNode): void {
  const map = expectMap(value);
  validateNestedKeys(map, EVENT_REF_KEYS);
  requireBytesLength(map, "ak", 16);
  requireUint63(map, "seq");
}

function validateLedgerEvent(map: CborMap): void {
  requireBytesLength(map, "ak", 16);
  requireUint63(map, "seq");
  optionalInt64(map, "ts_ms");
  requireField(map, "body");
}

function validateEncryptedObject(map: CborMap): void {
  requireLiteralText(map, "alg", "A256GCM");
  requireBytesLength(map, "cap_id", 32);
  requireBytesLength(map, "nonce", 12);
  const ct = requireBytes(map, "ct");
  if (ct.length > LIMITS.CBL_MAX_E2E_CIPHERTEXT_BYTES) {
    throw new GrainDiagError("GRAIN_ERR_LIMIT");
  }
}

function validateManifestRecord(map: CborMap): void {
  const opValue = mapGet(map, "op");
  if (!opValue) {
    throw new GrainDiagError("GRAIN_ERR_MANIFEST_OP");
  }
  if (opValue.kind !== "t") {
    throw new GrainDiagError("GRAIN_ERR_MANIFEST_OP");
  }

  const op = decodeUtf8(opValue.bytes);
  if (op === "put") {
    if (!mapHas(map, "cap_id") || !mapHas(map, "chash")) {
      throw new GrainDiagError("GRAIN_ERR_MANIFEST_OP");
    }
  } else if (op === "del") {
    if (mapHas(map, "cap_id") || mapHas(map, "chash") || mapHas(map, "size")) {
      throw new GrainDiagError("GRAIN_ERR_MANIFEST_OP");
    }
  } else {
    throw new GrainDiagError("GRAIN_ERR_MANIFEST_OP");
  }

  requireBytesLength(map, "ak", 16);
  requireUint63(map, "seq");
  validateCidLink(requireField(map, "cid"));

  if (op === "put") {
    requireBytesLength(map, "cap_id", 32);
    requireBytesLength(map, "chash", 32);
    optionalUint63(map, "size");
  }
}

function validateNutrientMap(value: CborNode, nonnegative: boolean): void {
  const map = expectMap(value);
  for (const entry of map.entries) {
    if (entry.key.kind !== "t") {
      throw new GrainDiagError("GRAIN_ERR_NONCANONICAL");
    }
    if (nonnegative) {
      expectNonnegativeInt64(entry.value);
    } else {
      expectInt64(entry.value);
    }
  }
}

function validateStructuredSetArray(value: CborNode, validateItem: ItemValidator): void {
  if (value.kind !== "a") {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }

  const encodedItems = value.items.map((item) => {
    validateItem(item);
    return encodeCanonical(item);
  });

  for (let i = 1; i < encodedItems.length; i += 1) {
    const previous = encodedItems[i - 1];
    const current = encodedItems[i];
    if (bytesEq(previous, current)) {
      throw new GrainDiagError("GRAIN_ERR_SET_ARRAY_DUP");
    }
    if (compareBytesLex(previous, current) > 0) {
      throw new GrainDiagError("GRAIN_ERR_SET_ARRAY_ORDER");
    }
  }
}

function validateTstrSetArray(value: CborNode, isCrit: boolean): void {
  if (value.kind !== "a") {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }

  if (isCrit) {
    if (value.items.length > LIMITS.CBL_MAX_CRIT_ENTRIES) {
      throw new GrainDiagError("GRAIN_ERR_LIMIT");
    }
    let total = 0;
    for (const item of value.items) {
      if (item.kind !== "t") {
        throw new GrainDiagError("GRAIN_ERR_SCHEMA");
      }
      total += item.bytes.length;
    }
    if (total > LIMITS.CBL_MAX_CRIT_TOTAL_UTF8_BYTES) {
      throw new GrainDiagError("GRAIN_ERR_LIMIT");
    }
  }

  const result = validateSetArrayUtf8(value);
  if (!result.orderOk) {
    throw new GrainDiagError("GRAIN_ERR_SET_ARRAY_ORDER");
  }
  if (!result.uniqueOk) {
    throw new GrainDiagError("GRAIN_ERR_SET_ARRAY_DUP");
  }
}

function validateCidLink(value: CborNode): void {
  if (value.kind !== "tag" || value.tag !== 42n || value.inner.kind !== "b") {
    throw new GrainDiagError("GRAIN_ERR_BAD_CID_LINK");
  }
  const bytes = value.inner.value;
  if (bytes.length !== CID_LINK_BSTR_LEN || !bytesEq(bytes.slice(0, CID_LINK_PREFIX.length), CID_LINK_PREFIX)) {
    throw new GrainDiagError("GRAIN_ERR_BAD_CID_LINK");
  }
}

function validateAllCidLinks(value: CborNode): void {
  switch (value.kind) {
    case "tag":
      if (value.tag !== 42n) {
        throw new GrainDiagError("GRAIN_ERR_TAG_FORBIDDEN");
      }
      validateCidLink(value);
      break;
    case "a":
      for (const item of value.items) {
        validateAllCidLinks(item);
      }
      break;
    case "m":
      for (const entry of value.entries) {
        validateAllCidLinks(entry.key);
        validateAllCidLinks(entry.value);
      }
      break;
    default:
      break;
  }
}

function expectMap(value: CborNode): CborMap {
  if (value.kind !== "m") {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }
  return value;
}

function mapHas(map: CborMap, key: string): boolean {
  return mapGet(map, key) !== undefined;
}

function requireField(map: CborMap, key: string): CborNode {
  const value = mapGet(map, key);
  if (!value) {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }
  return value;
}

function requireText(map: CborMap, key: string): Uint8Array {
  const value = requireField(map, key);
  if (value.kind !== "t") {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }
  return value.bytes;
}

function requireLiteralText(map: CborMap, key: string, expected: string): void {
  if (!bytesEq(requireText(map, key), new TextEncoder().encode(expected))) {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }
}

function optionalText(map: CborMap, key: string): void {
  const value = mapGet(map, key);
  if (value && value.kind !== "t") {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }
}

function requireBytes(map: CborMap, key: string): Uint8Array {
  const value = requireField(map, key);
  if (value.kind !== "b") {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }
  return value.value;
}

function requireBytesLength(map: CborMap, key: string, expectedLength: number): void {
  if (requireBytes(map, key).length !== expectedLength) {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }
}

function optionalBytes(map: CborMap, key: string): void {
  const value = mapGet(map, key);
  if (value && value.kind !== "b") {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }
}

function expectInt64(value: CborNode): void {
  if (value.kind === "u" && value.value <= I64_MAX) {
    return;
  }
  if (value.kind === "n" && value.value >= I64_MIN) {
    return;
  }
  throw new GrainDiagError("GRAIN_ERR_SCHEMA");
}

function expectNonnegativeInt64(value: CborNode): void {
  if (value.kind !== "u" || value.value > I64_MAX) {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }
}

function optionalInt64(map: CborMap, key: string): void {
  const value = mapGet(map, key);
  if (value) {
    expectInt64(value);
  }
}

function requireNonnegativeInt64(map: CborMap, key: string): void {
  expectNonnegativeInt64(requireField(map, key));
}

function optionalNonnegativeInt64(map: CborMap, key: string): void {
  const value = mapGet(map, key);
  if (value) {
    expectNonnegativeInt64(value);
  }
}

function requireUint63(map: CborMap, key: string): void {
  expectNonnegativeInt64(requireField(map, key));
}

function optionalUint63(map: CborMap, key: string): void {
  const value = mapGet(map, key);
  if (value) {
    expectNonnegativeInt64(value);
  }
}

function forbidFields(map: CborMap, fields: readonly string[]): void {
  if (fields.some((field) => mapHas(map, field))) {
    throw new GrainDiagError("GRAIN_ERR_SCHEMA");
  }
}

function assertNever(value: never): never {
  throw new GrainDiagError("GRAIN_ERR_SCHEMA", `unreachable typed-object variant: ${String(value)}`);
}
