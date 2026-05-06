const textEncoder = new TextEncoder();
const textDecoder = new TextDecoder();
const PREVIEW_STATUSES = new Set(["Verified", "Untrusted", "Rejected"]);
const ACCEPT_STATUSES = new Set(["Accepted", "AlreadyAccepted", "Rejected"]);
const IDENTITY_STATUSES = new Set(["Created", "Exported", "Imported", "AlreadyExists", "Uninitialized", "Rejected"]);
const DEVICE_STATUSES = new Set(["Added", "Revoked", "Active", "Rejected"]);
const LIFECYCLE_STATUSES = new Set(["Ready", "Uninitialized"]);
const PAIRING_STATUSES = new Set(["Created", "Valid", "Paired", "AlreadyPaired", "Rejected"]);
const SYNC_STATUSES = new Set(["Exported", "Empty", "Imported", "AlreadyImported", "Rejected"]);
const STORE_SNAPSHOT_STATUSES = new Set(["Exported", "Restored", "Empty", "Rejected"]);
const SDK_ERR_TRUST_ANCHOR_REQUIRED = "SDK_ERR_TRUST_ANCHOR_REQUIRED";
const SDK_ERR_TRUST_ANCHOR_NOT_FOUND = "SDK_ERR_TRUST_ANCHOR_NOT_FOUND";
const SDK_ERR_TRUST_ANCHOR_BUNDLE_INVALID = "SDK_ERR_TRUST_ANCHOR_BUNDLE_INVALID";
const REDACTED = "[REDACTED]";
const SENSITIVE_LOG_KEYS = new Set([
  "bundleB64",
  "coseB64",
  "envelopeB64",
  "identityBundle",
  "snapshotB64",
  "syncBundle",
  "syncSecret",
  "trustPubB64",
  "bundle_b64",
  "cose_b64",
  "envelope_b64",
  "identity_bundle",
  "snapshot_b64",
  "sync_bundle",
  "sync_secret_b64",
  "trust_pub_b64",
  "trustMaterial",
  "trust_material",
]);

export const GrainCustodyMaterial = Object.freeze({
  StoreSnapshot: "storeSnapshot",
  IdentityBundle: "identityBundle",
  PairingEnvelope: "pairingEnvelope",
  SyncBundle: "syncBundle",
  TrustMaterial: "trustMaterial",
});

export const GrainCustodyBinding = Object.freeze({
  PortableTransfer: "portableTransfer",
  DeviceKeychain: "deviceKeychain",
  DeviceKeystore: "deviceKeystore",
  SecureEnclave: "secureEnclave",
  ExternalSecureModule: "externalSecureModule",
  AppManaged: "appManaged",
});

export const GrainCustodyPolicies = Object.freeze({
  portableIdentityBundle: () => custodyDescriptor(GrainCustodyMaterial.IdentityBundle, GrainCustodyBinding.PortableTransfer, true, false),
  portablePairingEnvelope: () => custodyDescriptor(GrainCustodyMaterial.PairingEnvelope, GrainCustodyBinding.PortableTransfer, true, false),
  portableSyncBundle: () => custodyDescriptor(GrainCustodyMaterial.SyncBundle, GrainCustodyBinding.PortableTransfer, true, false),
  browserSnapshot: () => custodyDescriptor(GrainCustodyMaterial.StoreSnapshot, GrainCustodyBinding.AppManaged, false, false),
  externalSecureModuleSnapshot: () => custodyDescriptor(GrainCustodyMaterial.StoreSnapshot, GrainCustodyBinding.ExternalSecureModule, false, true),
});

export function redactGrainClientLogValue(value) {
  return redactValue(value);
}

function custodyDescriptor(material, binding, exportable, deviceBound) {
  return Object.freeze({ material, binding, exportable, deviceBound });
}

function redactValue(value) {
  if (Array.isArray(value)) {
    return value.map((item) => redactValue(item));
  }
  if (!isPlainObject(value)) {
    return value;
  }

  const redacted = {};
  for (const [key, item] of Object.entries(value)) {
    redacted[key] = SENSITIVE_LOG_KEYS.has(key) && item !== null && item !== undefined
      ? REDACTED
      : redactValue(item);
  }
  return redacted;
}

export class GrainStaticTrustProvider {
  #anchors;

  constructor(anchors = {}) {
    if (anchors instanceof Map) {
      this.#anchors = new Map(anchors);
      return;
    }
    if (!anchors || typeof anchors !== "object" || Array.isArray(anchors)) {
      throw new TypeError("GrainStaticTrustProvider anchors must be an object or Map");
    }
    this.#anchors = new Map(Object.entries(anchors));
  }

  trustPubB64(anchorId) {
    return this.#anchors.get(anchorId) ?? null;
  }

  static fromBundleJson(bundleJson) {
    return new GrainStaticTrustProvider(parseTrustAnchorBundleJson(bundleJson));
  }
}

function parseTrustAnchorBundleJson(bundleJson) {
  if (typeof bundleJson !== "string") {
    throw new TypeError("GrainStaticTrustProvider.fromBundleJson requires bundleJson");
  }

  let bundle;
  try {
    bundle = JSON.parse(bundleJson);
  } catch {
    throwTrustAnchorBundleInvalid();
  }
  if (!isPlainObject(bundle) || !sameKeys(bundle, ["bundle_v", "anchors"])) {
    throwTrustAnchorBundleInvalid();
  }
  if (bundle.bundle_v !== 1 || !Array.isArray(bundle.anchors) || bundle.anchors.length === 0) {
    throwTrustAnchorBundleInvalid();
  }

  const anchors = new Map();
  for (const anchor of bundle.anchors) {
    if (!isPlainObject(anchor) || !sameKeys(anchor, ["id", "trust_pub_b64"])) {
      throwTrustAnchorBundleInvalid();
    }
    if (
      typeof anchor.id !== "string" ||
      anchor.id.length === 0 ||
      anchor.id.trim() !== anchor.id ||
      anchors.has(anchor.id) ||
      !isNonEmptyStandardBase64(anchor.trust_pub_b64)
    ) {
      throwTrustAnchorBundleInvalid();
    }
    anchors.set(anchor.id, anchor.trust_pub_b64);
  }
  return anchors;
}

function sameKeys(value, expectedKeys) {
  const keys = Object.keys(value);
  return keys.length === expectedKeys.length && expectedKeys.every((key) => keys.includes(key));
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function isNonEmptyStandardBase64(value) {
  if (typeof value !== "string" || value.length === 0) {
    return false;
  }
  if (!/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(value)) {
    return false;
  }
  try {
    if (typeof globalThis.atob === "function") {
      return globalThis.atob(value).length > 0;
    }
    if (typeof globalThis.Buffer?.from === "function") {
      return globalThis.Buffer.from(value, "base64").length > 0;
    }
  } catch {
    return false;
  }
  return false;
}

function throwTrustAnchorBundleInvalid() {
  throw new Error(SDK_ERR_TRUST_ANCHOR_BUNDLE_INVALID);
}

export class GrainClient {
  #exports;
  #storePtr;
  #closed = false;

  constructor(wasmExports) {
    this.#exports = requireExports(wasmExports);
    this.#storePtr = this.#exports.grain_client_store_new();
    if (!Number.isInteger(this.#storePtr) || this.#storePtr === 0) {
      throw new Error("SDK_WASM_ERR_STORE_INIT");
    }
  }

  scanPreview(input) {
    this.#assertOpen();
    const payload = toPreviewPayload(input);
    return toPreview(callJson(this.#exports, (ptr, len) => this.#exports.grain_client_scan_preview(ptr, len), payload));
  }

  scanPreviewWithTrustProvider(input) {
    this.#assertOpen();
    const resolution = resolveTrustInput(input, "scanPreviewWithTrustProvider");
    if (resolution.diag !== null) {
      return rejectedPreview(resolution.diag);
    }
    return this.scanPreview({ qrString: input.qrString, trustPubB64: resolution.trustPubB64 });
  }

  scanAccept(input) {
    this.#assertOpen();
    const payload = toAcceptPayload(input);
    return toAccept(callJson(
      this.#exports,
      (ptr, len) => this.#exports.grain_client_scan_accept(this.#storePtr, ptr, len),
      payload,
    ));
  }

  scanAcceptWithTrustProvider(input) {
    this.#assertOpen();
    const resolution = resolveTrustInput(input, "scanAcceptWithTrustProvider");
    if (resolution.diag !== null) {
      return rejectedAccept(resolution.diag);
    }
    return this.scanAccept({ qrString: input.qrString, trustPubB64: resolution.trustPubB64 });
  }

  listAcceptedScans() {
    this.#assertOpen();
    const raw = callNoInputJson(this.#exports, () => this.#exports.grain_client_list_accepted_scans(this.#storePtr));
    if (raw.status !== "Ok") {
      throw new Error(`SDK_WASM_ERR_LIST_FAILED:${diagList(raw).join(",")}`);
    }
    if (!Array.isArray(raw.records)) {
      throw new Error("SDK_WASM_ERR_RESPONSE_SHAPE:records");
    }
    const records = raw.records;
    return records.map((record) => ({
      scanId: requireString(record.scan_id, "records[].scan_id"),
      coseB64: requireString(record.cose_b64, "records[].cose_b64"),
      trustPubB64: requireString(record.trust_pub_b64, "records[].trust_pub_b64"),
    }));
  }

  createRootIdentity(input = {}) {
    this.#assertOpen();
    return toIdentity(callJson(
      this.#exports,
      (ptr, len) => this.#exports.grain_client_create_root_identity(this.#storePtr, ptr, len),
      toLabelPayload(input, "root", "createRootIdentity"),
    ));
  }

  exportIdentityBundle() {
    this.#assertOpen();
    return toIdentity(callNoInputJson(
      this.#exports,
      () => this.#exports.grain_client_export_identity_bundle(this.#storePtr),
    ));
  }

  importIdentityBundle(input) {
    this.#assertOpen();
    return toIdentity(callJson(
      this.#exports,
      (ptr, len) => this.#exports.grain_client_import_identity_bundle(this.#storePtr, ptr, len),
      toB64Payload(input, "bundleB64", "bundle_b64", "importIdentityBundle"),
    ));
  }

  addDeviceKey(input = {}) {
    this.#assertOpen();
    return toDevice(callJson(
      this.#exports,
      (ptr, len) => this.#exports.grain_client_add_device_key(this.#storePtr, ptr, len),
      toLabelPayload(input, "device", "addDeviceKey"),
    ));
  }

  revokeDeviceKey(input) {
    this.#assertOpen();
    return toDevice(callJson(
      this.#exports,
      (ptr, len) => this.#exports.grain_client_revoke_device_key(this.#storePtr, ptr, len),
      toAkPayload(input, "revokeDeviceKey"),
    ));
  }

  setActiveDevice(input) {
    this.#assertOpen();
    return toDevice(callJson(
      this.#exports,
      (ptr, len) => this.#exports.grain_client_set_active_device(this.#storePtr, ptr, len),
      toAkPayload(input, "setActiveDevice"),
    ));
  }

  clientLifecycle() {
    this.#assertOpen();
    return toLifecycle(callNoInputJson(
      this.#exports,
      () => this.#exports.grain_client_lifecycle(this.#storePtr),
    ));
  }

  createPairingEnvelope() {
    this.#assertOpen();
    return toPairing(callNoInputJson(
      this.#exports,
      () => this.#exports.grain_client_create_pairing_envelope(this.#storePtr),
    ));
  }

  previewPairingEnvelope(input) {
    this.#assertOpen();
    return toPairing(callJson(
      this.#exports,
      (ptr, len) => this.#exports.grain_client_pairing_preview(ptr, len),
      toB64Payload(input, "envelopeB64", "envelope_b64", "previewPairingEnvelope"),
    ));
  }

  acceptPairingEnvelope(input) {
    this.#assertOpen();
    return toPairing(callJson(
      this.#exports,
      (ptr, len) => this.#exports.grain_client_accept_pairing_envelope(this.#storePtr, ptr, len),
      toB64Payload(input, "envelopeB64", "envelope_b64", "acceptPairingEnvelope"),
    ));
  }

  exportSyncBundle() {
    this.#assertOpen();
    return toSync(callNoInputJson(
      this.#exports,
      () => this.#exports.grain_client_export_sync_bundle(this.#storePtr),
    ));
  }

  importSyncBundle(input) {
    this.#assertOpen();
    return toSync(callJson(
      this.#exports,
      (ptr, len) => this.#exports.grain_client_import_sync_bundle(this.#storePtr, ptr, len),
      toB64Payload(input, "bundleB64", "bundle_b64", "importSyncBundle"),
    ));
  }

  exportStoreSnapshot() {
    this.#assertOpen();
    return toStoreSnapshot(callNoInputJson(
      this.#exports,
      () => this.#exports.grain_client_export_store_snapshot(this.#storePtr),
    ));
  }

  restoreStoreSnapshot(input) {
    this.#assertOpen();
    return toStoreSnapshot(callJson(
      this.#exports,
      (ptr, len) => this.#exports.grain_client_restore_store_snapshot(this.#storePtr, ptr, len),
      toB64Payload(input, "snapshotB64", "snapshot_b64", "restoreStoreSnapshot"),
    ));
  }

  close() {
    if (!this.#closed) {
      this.#exports.grain_client_store_free(this.#storePtr);
      this.#closed = true;
      this.#storePtr = 0;
    }
  }

  #assertOpen() {
    if (this.#closed) {
      throw new Error("SDK_WASM_ERR_CLIENT_CLOSED");
    }
  }
}

export function createGrainClientFromInstance(instance) {
  return new GrainClient(instance.exports);
}

function requireExports(wasmExports) {
  const required = [
    "memory",
    "grain_client_alloc",
    "grain_client_dealloc",
    "grain_client_store_new",
    "grain_client_store_free",
    "grain_client_scan_preview",
    "grain_client_scan_accept",
    "grain_client_list_accepted_scans",
    "grain_client_create_root_identity",
    "grain_client_export_identity_bundle",
    "grain_client_import_identity_bundle",
    "grain_client_add_device_key",
    "grain_client_revoke_device_key",
    "grain_client_set_active_device",
    "grain_client_lifecycle",
    "grain_client_pairing_preview",
    "grain_client_create_pairing_envelope",
    "grain_client_accept_pairing_envelope",
    "grain_client_export_sync_bundle",
    "grain_client_import_sync_bundle",
    "grain_client_export_store_snapshot",
    "grain_client_restore_store_snapshot",
  ];
  for (const name of required) {
    if (!(name in wasmExports)) {
      throw new Error(`SDK_WASM_ERR_EXPORT_MISSING:${name}`);
    }
  }
  return wasmExports;
}

function callJson(wasmExports, invoke, payload) {
  const bytes = textEncoder.encode(JSON.stringify(payload));
  const inputPtr = wasmExports.grain_client_alloc(bytes.length);
  new Uint8Array(wasmExports.memory.buffer, inputPtr, bytes.length).set(bytes);

  let packed;
  try {
    packed = invoke(inputPtr, bytes.length);
  } finally {
    wasmExports.grain_client_dealloc(inputPtr, bytes.length);
  }

  return decodeJsonResponse(wasmExports, packed);
}

function callNoInputJson(wasmExports, invoke) {
  return decodeJsonResponse(wasmExports, invoke());
}

function decodeJsonResponse(wasmExports, packed) {
  const { ptr, len } = decodePacked(packed);
  const bytes = new Uint8Array(wasmExports.memory.buffer, ptr, len);
  const jsonText = textDecoder.decode(bytes.slice());
  wasmExports.grain_client_dealloc(ptr, len);
  return JSON.parse(jsonText);
}

function decodePacked(raw) {
  const value = typeof raw === "bigint" ? raw : BigInt(raw);
  return {
    ptr: Number((value >> 32n) & 0xffffffffn),
    len: Number(value & 0xffffffffn),
  };
}

function toPreviewPayload(input) {
  if (!input || typeof input.qrString !== "string") {
    throw new TypeError("scanPreview requires qrString");
  }
  if (
    input.trustPubB64 !== undefined &&
    input.trustPubB64 !== null &&
    typeof input.trustPubB64 !== "string"
  ) {
    throw new TypeError("scanPreview trustPubB64 must be a string, null, or undefined");
  }
  return {
    qr_string: input.qrString,
    trust_pub_b64: input.trustPubB64 ?? null,
  };
}

function toAcceptPayload(input) {
  if (!input || typeof input.qrString !== "string") {
    throw new TypeError("scanAccept requires qrString");
  }
  if (typeof input.trustPubB64 !== "string") {
    throw new TypeError("scanAccept requires trustPubB64");
  }
  return {
    qr_string: input.qrString,
    trust_pub_b64: input.trustPubB64,
  };
}

function resolveTrustInput(input, functionName) {
  if (!input || typeof input.qrString !== "string") {
    throw new TypeError(`${functionName} requires qrString`);
  }
  if (input.trustAnchorId === null || input.trustAnchorId === undefined) {
    return { diag: SDK_ERR_TRUST_ANCHOR_REQUIRED, trustPubB64: null };
  }
  if (typeof input.trustAnchorId !== "string") {
    throw new TypeError(`${functionName} requires trustAnchorId`);
  }
  if (input.trustAnchorId.trim().length === 0) {
    return { diag: SDK_ERR_TRUST_ANCHOR_REQUIRED, trustPubB64: null };
  }
  const provider = input.trustProvider;
  if (!provider || typeof provider.trustPubB64 !== "function") {
    throw new TypeError(`${functionName} requires trustProvider.trustPubB64(anchorId)`);
  }
  const trustPubB64 = provider.trustPubB64(input.trustAnchorId);
  if (trustPubB64 === null || trustPubB64 === undefined) {
    return { diag: SDK_ERR_TRUST_ANCHOR_NOT_FOUND, trustPubB64: null };
  }
  if (typeof trustPubB64 !== "string") {
    throw new TypeError(`${functionName} trustProvider.trustPubB64 must return a string, null, or undefined`);
  }
  return { diag: null, trustPubB64 };
}

function toLabelPayload(input, defaultLabel, functionName) {
  if (input === undefined || input === null) {
    return { label: defaultLabel };
  }
  if (typeof input !== "object") {
    throw new TypeError(`${functionName} input must be an object`);
  }
  if (input.label !== undefined && typeof input.label !== "string") {
    throw new TypeError(`${functionName} label must be a string`);
  }
  return { label: input.label ?? defaultLabel };
}

function toAkPayload(input, functionName) {
  if (!input || typeof input.ak !== "string") {
    throw new TypeError(`${functionName} requires ak`);
  }
  return { ak: input.ak };
}

function toB64Payload(input, publicName, wireName, functionName) {
  if (!input || typeof input[publicName] !== "string") {
    throw new TypeError(`${functionName} requires ${publicName}`);
  }
  return { [wireName]: input[publicName] };
}

function toPreview(raw) {
  const status = requireEnum(raw.status, PREVIEW_STATUSES, "status");
  return {
    status,
    diag: diagList(raw),
    coseB64: optionalString(raw.cose_b64, "cose_b64"),
  };
}

function rejectedPreview(diag) {
  return {
    status: "Rejected",
    diag: [diag],
    coseB64: null,
  };
}

function toAccept(raw) {
  const status = requireEnum(raw.status, ACCEPT_STATUSES, "status");
  return {
    status,
    diag: diagList(raw),
    scanId: optionalString(raw.scan_id, "scan_id"),
    coseB64: optionalString(raw.cose_b64, "cose_b64"),
    trustPubB64: optionalString(raw.trust_pub_b64, "trust_pub_b64"),
  };
}

function rejectedAccept(diag) {
  return {
    status: "Rejected",
    diag: [diag],
    scanId: null,
    coseB64: null,
    trustPubB64: null,
  };
}

function toIdentity(raw) {
  const status = requireEnum(raw.status, IDENTITY_STATUSES, "status");
  return {
    status,
    diag: diagList(raw),
    rootKid: optionalString(raw.root_kid, "root_kid"),
    activeAk: optionalString(raw.active_ak, "active_ak"),
    bundleB64: optionalString(raw.bundle_b64, "bundle_b64"),
    deviceCount: requireNonNegativeInteger(raw.device_count, "device_count"),
    revokedCount: requireNonNegativeInteger(raw.revoked_count, "revoked_count"),
    lifecycleEventCount: requireNonNegativeInteger(raw.lifecycle_event_count, "lifecycle_event_count"),
  };
}

function toDevice(raw) {
  const status = requireEnum(raw.status, DEVICE_STATUSES, "status");
  return {
    status,
    diag: diagList(raw),
    deviceAk: optionalString(raw.device_ak, "device_ak"),
    activeAk: optionalString(raw.active_ak, "active_ak"),
    rootKid: optionalString(raw.root_kid, "root_kid"),
    deviceCount: requireNonNegativeInteger(raw.device_count, "device_count"),
    revokedCount: requireNonNegativeInteger(raw.revoked_count, "revoked_count"),
    lifecycleEventCount: requireNonNegativeInteger(raw.lifecycle_event_count, "lifecycle_event_count"),
  };
}

function toLifecycle(raw) {
  const status = requireEnum(raw.status, LIFECYCLE_STATUSES, "status");
  return {
    status,
    diag: diagList(raw),
    rootKid: optionalString(raw.root_kid, "root_kid"),
    activeAk: optionalString(raw.active_ak, "active_ak"),
    deviceCount: requireNonNegativeInteger(raw.device_count, "device_count"),
    revokedCount: requireNonNegativeInteger(raw.revoked_count, "revoked_count"),
    acceptedRecordCount: requireNonNegativeInteger(raw.accepted_record_count, "accepted_record_count"),
    lifecycleEventCount: requireNonNegativeInteger(raw.lifecycle_event_count, "lifecycle_event_count"),
  };
}

function toPairing(raw) {
  const status = requireEnum(raw.status, PAIRING_STATUSES, "status");
  return {
    status,
    diag: diagList(raw),
    pairingId: optionalString(raw.pairing_id, "pairing_id"),
    envelopeB64: optionalString(raw.envelope_b64, "envelope_b64"),
    rootKid: optionalString(raw.root_kid, "root_kid"),
    deviceCount: requireNonNegativeInteger(raw.device_count, "device_count"),
  };
}

function toSync(raw) {
  const status = requireEnum(raw.status, SYNC_STATUSES, "status");
  return {
    status,
    diag: diagList(raw),
    bundleB64: optionalString(raw.bundle_b64, "bundle_b64"),
    acceptedRecordCount: requireNonNegativeInteger(raw.accepted_record_count, "accepted_record_count"),
    deviceCount: requireNonNegativeInteger(raw.device_count, "device_count"),
    lifecycleEventCount: requireNonNegativeInteger(raw.lifecycle_event_count, "lifecycle_event_count"),
  };
}

function toStoreSnapshot(raw) {
  const status = requireEnum(raw.status, STORE_SNAPSHOT_STATUSES, "status");
  return {
    status,
    diag: diagList(raw),
    snapshotB64: optionalString(raw.snapshot_b64, "snapshot_b64"),
    acceptedRecordCount: requireNonNegativeInteger(raw.accepted_record_count, "accepted_record_count"),
    deviceCount: requireNonNegativeInteger(raw.device_count, "device_count"),
    lifecycleEventCount: requireNonNegativeInteger(raw.lifecycle_event_count, "lifecycle_event_count"),
  };
}

function diagList(raw) {
  return requireStringArray(raw.diag, "diag");
}

function requireEnum(value, allowed, fieldName) {
  if (typeof value !== "string" || !allowed.has(value)) {
    throw new Error(`SDK_WASM_ERR_RESPONSE_SHAPE:${fieldName}`);
  }
  return value;
}

function requireStringArray(value, fieldName) {
  if (!Array.isArray(value) || value.some((item) => typeof item !== "string")) {
    throw new Error(`SDK_WASM_ERR_RESPONSE_SHAPE:${fieldName}`);
  }
  return value;
}

function optionalString(value, fieldName) {
  if (value === null || value === undefined) {
    return null;
  }
  if (typeof value !== "string") {
    throw new Error(`SDK_WASM_ERR_RESPONSE_SHAPE:${fieldName}`);
  }
  return value;
}

function requireString(value, fieldName) {
  if (typeof value !== "string") {
    throw new Error(`SDK_WASM_ERR_RESPONSE_SHAPE:${fieldName}`);
  }
  return value;
}

function requireNonNegativeInteger(value, fieldName) {
  if (!Number.isSafeInteger(value) || value < 0) {
    throw new Error(`SDK_WASM_ERR_RESPONSE_SHAPE:${fieldName}`);
  }
  return value;
}
