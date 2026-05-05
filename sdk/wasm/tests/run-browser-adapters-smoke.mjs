#!/usr/bin/env node
import assert from "node:assert/strict";

import {
  GrainIndexedDBSnapshotPersistence,
  GrainMemorySnapshotPersistence,
  GrainSnapshotCoordinator,
  GrainSnapshotPersistenceError,
} from "../src/browser-storage.mjs";

async function memoryPersistenceRoundTrip() {
  const persistence = new GrainMemorySnapshotPersistence();
  assert.equal(await persistence.loadSnapshotB64(), null);
  await persistence.saveSnapshotB64("snapshot-one");
  assert.equal(await persistence.loadSnapshotB64(), "snapshot-one");
  await persistence.clearSnapshot();
  assert.equal(await persistence.loadSnapshotB64(), null);
}

async function coordinatorPersistsRestoresAndClears() {
  const persistence = new GrainMemorySnapshotPersistence();
  const coordinator = new GrainSnapshotCoordinator(persistence);
  const client = new FakeSnapshotClient(exportedSnapshot("snapshot-two"));

  const exported = await coordinator.persist(client);
  assert.equal(exported.status, "Exported");
  assert.equal(await persistence.loadSnapshotB64(), "snapshot-two");

  const restored = await coordinator.restore(client);
  assert.equal(restored.status, "Restored");
  assert.equal(client.restoredSnapshotB64, "snapshot-two");

  client.exportResult = emptySnapshot();
  const empty = await coordinator.persist(client);
  assert.equal(empty.status, "Empty");
  assert.equal(await persistence.loadSnapshotB64(), null);
}

async function indexedDbPersistenceRoundTrip() {
  const persistence = new GrainIndexedDBSnapshotPersistence({
    indexedDB: new FakeIndexedDBFactory(),
    databaseName: "grain-adapter-smoke",
    storeName: "snapshots",
    snapshotKey: "client-store",
  });

  assert.equal(await persistence.loadSnapshotB64(), null);
  await persistence.saveSnapshotB64("snapshot-three");
  assert.equal(await persistence.loadSnapshotB64(), "snapshot-three");
  await persistence.clearSnapshot();
  assert.equal(await persistence.loadSnapshotB64(), null);
}

async function missingExportedSnapshotThrows() {
  const coordinator = new GrainSnapshotCoordinator(new GrainMemorySnapshotPersistence());
  const client = new FakeSnapshotClient({
    status: "Exported",
    diag: [],
    snapshotB64: null,
    acceptedRecordCount: 0,
    deviceCount: 0,
    lifecycleEventCount: 0,
  });

  await assert.rejects(
    () => coordinator.persist(client),
    (error) =>
      error instanceof GrainSnapshotPersistenceError &&
      error.code === "SDK_WASM_ERR_SNAPSHOT_EXPORT_MISSING",
  );
}

class FakeSnapshotClient {
  constructor(exportResult) {
    this.exportResult = exportResult;
    this.restoredSnapshotB64 = null;
  }

  exportStoreSnapshot() {
    return this.exportResult;
  }

  restoreStoreSnapshot({ snapshotB64 }) {
    this.restoredSnapshotB64 = snapshotB64;
    return {
      status: "Restored",
      diag: [],
      snapshotB64: null,
      acceptedRecordCount: 1,
      deviceCount: 2,
      lifecycleEventCount: 3,
    };
  }
}

function exportedSnapshot(snapshotB64) {
  return {
    status: "Exported",
    diag: [],
    snapshotB64,
    acceptedRecordCount: 1,
    deviceCount: 2,
    lifecycleEventCount: 3,
  };
}

function emptySnapshot() {
  return {
    status: "Empty",
    diag: [],
    snapshotB64: null,
    acceptedRecordCount: 0,
    deviceCount: 0,
    lifecycleEventCount: 0,
  };
}

class FakeIndexedDBFactory {
  #databases = new Map();

  open(databaseName) {
    const request = new FakeIDBRequest();
    queueMicrotask(() => {
      let db = this.#databases.get(databaseName);
      const isNew = db === undefined;
      if (isNew) {
        db = new FakeIDBDatabase();
        this.#databases.set(databaseName, db);
      }
      request.result = db;
      if (isNew) {
        request.dispatch("upgradeneeded");
      }
      request.dispatch("success");
    });
    return request;
  }
}

class FakeIDBDatabase {
  #stores = new Map();

  objectStoreNames = {
    contains: (storeName) => this.#stores.has(storeName),
  };

  createObjectStore(storeName) {
    if (!this.#stores.has(storeName)) {
      this.#stores.set(storeName, new Map());
    }
    return this.#stores.get(storeName);
  }

  transaction(storeName) {
    if (!this.#stores.has(storeName)) {
      throw new Error(`store missing: ${storeName}`);
    }
    return new FakeIDBTransaction(this.#stores.get(storeName));
  }

  close() {}
}

class FakeIDBTransaction {
  #store;
  #listeners = new Map();

  constructor(store) {
    this.#store = store;
  }

  objectStore() {
    return new FakeIDBObjectStore(this.#store, this);
  }

  addEventListener(eventName, listener) {
    const listeners = this.#listeners.get(eventName) ?? [];
    listeners.push(listener);
    this.#listeners.set(eventName, listeners);
  }

  complete() {
    queueMicrotask(() => {
      for (const listener of this.#listeners.get("complete") ?? []) {
        listener();
      }
    });
  }
}

class FakeIDBObjectStore {
  #store;
  #transaction;

  constructor(store, transaction) {
    this.#store = store;
    this.#transaction = transaction;
  }

  get(key) {
    return this.#run(() => this.#store.get(key));
  }

  put(value, key) {
    return this.#run(() => {
      this.#store.set(key, value);
      return key;
    });
  }

  delete(key) {
    return this.#run(() => {
      this.#store.delete(key);
      return undefined;
    });
  }

  #run(operation) {
    const request = new FakeIDBRequest();
    queueMicrotask(() => {
      request.result = operation();
      request.dispatch("success");
      this.#transaction.complete();
    });
    return request;
  }
}

class FakeIDBRequest {
  #listeners = new Map();

  result = undefined;
  error = null;

  addEventListener(eventName, listener) {
    const listeners = this.#listeners.get(eventName) ?? [];
    listeners.push(listener);
    this.#listeners.set(eventName, listeners);
  }

  dispatch(eventName) {
    for (const listener of this.#listeners.get(eventName) ?? []) {
      listener({ target: this });
    }
  }
}

await memoryPersistenceRoundTrip();
await coordinatorPersistsRestoresAndClears();
await indexedDbPersistenceRoundTrip();
await missingExportedSnapshotThrows();
console.log("WASM browser adapters smoke: PASS");
