import type { IdentityBundleV1, LedgerEvent, ManifestRecord } from "./types.ts";

export interface SequenceStore {
  reserveNextSeq(ak: string): Promise<bigint>;
  snapshot(): Promise<Record<string, string>>;
  importSnapshot(snapshot: Record<string, string>): Promise<void>;
}

export interface EventStore {
  append(event: LedgerEvent): Promise<void>;
  list(): Promise<LedgerEvent[]>;
}

export interface ObjectStore {
  put(cid: string, bytes: Uint8Array): Promise<void>;
  get(cid: string): Promise<Uint8Array | null>;
  listCids(): Promise<string[]>;
}

export interface CapabilityBlobStore {
  put(capId: Uint8Array, ciphertext: Uint8Array, chash: Uint8Array): Promise<void>;
  get(capId: Uint8Array): Promise<{ ciphertext: Uint8Array; chash: Uint8Array } | null>;
}

export interface ManifestStore {
  append(record: ManifestRecord): Promise<void>;
  listByCid(cid: string): Promise<ManifestRecord[]>;
  listAll(): Promise<ManifestRecord[]>;
}

export interface IdentityStore {
  load(): Promise<IdentityBundleV1 | null>;
  save(bundle: IdentityBundleV1): Promise<void>;
}

export interface GrainSdkStore {
  sequence: SequenceStore;
  events: EventStore;
  objects: ObjectStore;
  blobs: CapabilityBlobStore;
  manifest: ManifestStore;
  identity: IdentityStore;
}
