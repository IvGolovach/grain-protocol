export type GrainScanPreviewStatus = "Verified" | "Untrusted" | "Rejected";
export type GrainScanAcceptStatus = "Accepted" | "AlreadyAccepted" | "Rejected";
export type GrainIdentityStatus =
  | "Created"
  | "Exported"
  | "Imported"
  | "AlreadyExists"
  | "Uninitialized"
  | "Rejected";
export type GrainDeviceStatus = "Added" | "Revoked" | "Active" | "Rejected";
export type GrainClientLifecycleStatus = "Ready" | "Uninitialized";
export type GrainPairingStatus = "Created" | "Valid" | "Paired" | "AlreadyPaired" | "Rejected";
export type GrainSyncStatus = "Exported" | "Empty" | "Imported" | "AlreadyImported" | "Rejected";
export type GrainStoreSnapshotStatus = "Exported" | "Restored" | "Empty" | "Rejected";

export interface GrainScanPreviewInput {
  qrString: string;
  trustPubB64?: string | null;
}

export interface GrainScanAcceptInput {
  qrString: string;
  trustPubB64: string;
}

export interface GrainLabelInput {
  label?: string;
}

export interface GrainDeviceAkInput {
  ak: string;
}

export interface GrainIdentityBundleInput {
  bundleB64: string;
}

export interface GrainPairingEnvelopeInput {
  envelopeB64: string;
}

export interface GrainSyncBundleInput {
  bundleB64: string;
}

export interface GrainStoreSnapshotInput {
  snapshotB64: string;
}

export interface GrainScanPreview {
  status: GrainScanPreviewStatus;
  diag: string[];
  coseB64: string | null;
}

export interface GrainScanAccept {
  status: GrainScanAcceptStatus;
  diag: string[];
  scanId: string | null;
  coseB64: string | null;
  trustPubB64: string | null;
}

export interface GrainAcceptedScan {
  scanId: string;
  coseB64: string;
  trustPubB64: string;
}

export interface GrainIdentityResult {
  status: GrainIdentityStatus;
  diag: string[];
  rootKid: string | null;
  activeAk: string | null;
  bundleB64: string | null;
  deviceCount: number;
  revokedCount: number;
  lifecycleEventCount: number;
}

export interface GrainDeviceResult {
  status: GrainDeviceStatus;
  diag: string[];
  deviceAk: string | null;
  activeAk: string | null;
  rootKid: string | null;
  deviceCount: number;
  revokedCount: number;
  lifecycleEventCount: number;
}

export interface GrainClientLifecycle {
  status: GrainClientLifecycleStatus;
  diag: string[];
  rootKid: string | null;
  activeAk: string | null;
  deviceCount: number;
  revokedCount: number;
  acceptedRecordCount: number;
  lifecycleEventCount: number;
}

export interface GrainPairingResult {
  status: GrainPairingStatus;
  diag: string[];
  pairingId: string | null;
  envelopeB64: string | null;
  rootKid: string | null;
  deviceCount: number;
}

export interface GrainSyncResult {
  status: GrainSyncStatus;
  diag: string[];
  bundleB64: string | null;
  acceptedRecordCount: number;
  deviceCount: number;
  lifecycleEventCount: number;
}

export interface GrainStoreSnapshotResult {
  status: GrainStoreSnapshotStatus;
  diag: string[];
  snapshotB64: string | null;
  acceptedRecordCount: number;
  deviceCount: number;
  lifecycleEventCount: number;
}

export class GrainClient {
  constructor(wasmExports: WebAssembly.Exports);
  scanPreview(input: GrainScanPreviewInput): GrainScanPreview;
  scanAccept(input: GrainScanAcceptInput): GrainScanAccept;
  listAcceptedScans(): GrainAcceptedScan[];
  createRootIdentity(input?: GrainLabelInput): GrainIdentityResult;
  exportIdentityBundle(): GrainIdentityResult;
  importIdentityBundle(input: GrainIdentityBundleInput): GrainIdentityResult;
  addDeviceKey(input?: GrainLabelInput): GrainDeviceResult;
  revokeDeviceKey(input: GrainDeviceAkInput): GrainDeviceResult;
  setActiveDevice(input: GrainDeviceAkInput): GrainDeviceResult;
  clientLifecycle(): GrainClientLifecycle;
  createPairingEnvelope(): GrainPairingResult;
  previewPairingEnvelope(input: GrainPairingEnvelopeInput): GrainPairingResult;
  acceptPairingEnvelope(input: GrainPairingEnvelopeInput): GrainPairingResult;
  exportSyncBundle(): GrainSyncResult;
  importSyncBundle(input: GrainSyncBundleInput): GrainSyncResult;
  exportStoreSnapshot(): GrainStoreSnapshotResult;
  restoreStoreSnapshot(input: GrainStoreSnapshotInput): GrainStoreSnapshotResult;
  close(): void;
}

export function createGrainClientFromInstance(instance: WebAssembly.Instance): GrainClient;
