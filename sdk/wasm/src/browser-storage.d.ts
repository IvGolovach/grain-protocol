import type { GrainStoreSnapshotResult } from "./index.mjs";

export class GrainSnapshotPersistenceError extends Error {
  readonly code: string;
  constructor(code: string, message?: string);
}

export interface GrainSnapshotPersistence {
  loadSnapshotB64(): string | null | Promise<string | null>;
  saveSnapshotB64(snapshotB64: string): void | Promise<void>;
  clearSnapshot(): void | Promise<void>;
}

export interface GrainSnapshotClient {
  exportStoreSnapshot(): GrainStoreSnapshotResult;
  restoreStoreSnapshot(input: { snapshotB64: string }): GrainStoreSnapshotResult;
}

export class GrainSnapshotCoordinator {
  constructor(persistence: GrainSnapshotPersistence);
  restore(client: GrainSnapshotClient): Promise<GrainStoreSnapshotResult | null>;
  persist(client: GrainSnapshotClient): Promise<GrainStoreSnapshotResult>;
}

export class GrainMemorySnapshotPersistence implements GrainSnapshotPersistence {
  loadSnapshotB64(): Promise<string | null>;
  saveSnapshotB64(snapshotB64: string): Promise<void>;
  clearSnapshot(): Promise<void>;
}

export interface GrainIndexedDBSnapshotPersistenceOptions {
  indexedDB?: IDBFactory;
  databaseName?: string;
  storeName?: string;
  snapshotKey?: string;
  version?: number;
}

export class GrainIndexedDBSnapshotPersistence implements GrainSnapshotPersistence {
  constructor(options?: GrainIndexedDBSnapshotPersistenceOptions);
  loadSnapshotB64(): Promise<string | null>;
  saveSnapshotB64(snapshotB64: string): Promise<void>;
  clearSnapshot(): Promise<void>;
}
