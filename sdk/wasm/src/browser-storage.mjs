const DEFAULT_DATABASE_NAME = "grain-client";
const DEFAULT_STORE_NAME = "snapshots";
const DEFAULT_SNAPSHOT_KEY = "default";

export class GrainSnapshotPersistenceError extends Error {
  constructor(code, message = code) {
    super(message);
    this.name = "GrainSnapshotPersistenceError";
    this.code = code;
  }
}

export class GrainSnapshotCoordinator {
  #persistence;

  constructor(persistence) {
    requireSnapshotPersistence(persistence);
    this.#persistence = persistence;
  }

  async restore(client) {
    requireSnapshotClient(client);
    const snapshotB64 = await this.#persistence.loadSnapshotB64();
    if (snapshotB64 === null) {
      return null;
    }
    return client.restoreStoreSnapshot({ snapshotB64 });
  }

  async persist(client) {
    requireSnapshotClient(client);
    const result = client.exportStoreSnapshot();
    if (result.status === "Exported") {
      if (typeof result.snapshotB64 !== "string" || result.snapshotB64.length === 0) {
        throw new GrainSnapshotPersistenceError(
          "SDK_WASM_ERR_SNAPSHOT_EXPORT_MISSING",
          "exportStoreSnapshot returned Exported without snapshotB64",
        );
      }
      await this.#persistence.saveSnapshotB64(result.snapshotB64);
    } else if (result.status === "Empty") {
      await this.#persistence.clearSnapshot();
    } else {
      throw new GrainSnapshotPersistenceError(
        "SDK_WASM_ERR_SNAPSHOT_EXPORT_STATUS",
        `exportStoreSnapshot returned unsupported status: ${result.status}`,
      );
    }
    return result;
  }
}

export class GrainMemorySnapshotPersistence {
  #snapshotB64 = null;

  async loadSnapshotB64() {
    return this.#snapshotB64;
  }

  async saveSnapshotB64(snapshotB64) {
    this.#snapshotB64 = requireSnapshotB64(snapshotB64);
  }

  async clearSnapshot() {
    this.#snapshotB64 = null;
  }
}

export class GrainIndexedDBSnapshotPersistence {
  #indexedDB;
  #databaseName;
  #storeName;
  #snapshotKey;
  #version;

  constructor({
    indexedDB = globalThis.indexedDB,
    databaseName = DEFAULT_DATABASE_NAME,
    storeName = DEFAULT_STORE_NAME,
    snapshotKey = DEFAULT_SNAPSHOT_KEY,
    version = 1,
  } = {}) {
    if (!indexedDB || typeof indexedDB.open !== "function") {
      throw new TypeError("SDK_WASM_ERR_INDEXEDDB_MISSING");
    }
    this.#indexedDB = indexedDB;
    this.#databaseName = requireNonEmptyString(databaseName, "databaseName");
    this.#storeName = requireNonEmptyString(storeName, "storeName");
    this.#snapshotKey = requireNonEmptyString(snapshotKey, "snapshotKey");
    if (!Number.isInteger(version) || version < 1) {
      throw new TypeError("SDK_WASM_ERR_INDEXEDDB_VERSION");
    }
    this.#version = version;
  }

  async loadSnapshotB64() {
    const db = await this.#openDatabase();
    try {
      const tx = db.transaction(this.#storeName, "readonly");
      const store = tx.objectStore(this.#storeName);
      const done = transactionDone(tx);
      const value = await requestToPromise(store.get(this.#snapshotKey));
      await done;
      if (value === undefined || value === null) {
        return null;
      }
      if (typeof value !== "string") {
        throw new GrainSnapshotPersistenceError("SDK_WASM_ERR_INDEXEDDB_VALUE_SHAPE");
      }
      const trimmed = value.trim();
      return trimmed.length === 0 ? null : trimmed;
    } finally {
      db.close?.();
    }
  }

  async saveSnapshotB64(snapshotB64) {
    const db = await this.#openDatabase();
    try {
      const tx = db.transaction(this.#storeName, "readwrite");
      const store = tx.objectStore(this.#storeName);
      const done = transactionDone(tx);
      await requestToPromise(store.put(requireSnapshotB64(snapshotB64), this.#snapshotKey));
      await done;
    } finally {
      db.close?.();
    }
  }

  async clearSnapshot() {
    const db = await this.#openDatabase();
    try {
      const tx = db.transaction(this.#storeName, "readwrite");
      const store = tx.objectStore(this.#storeName);
      const done = transactionDone(tx);
      await requestToPromise(store.delete(this.#snapshotKey));
      await done;
    } finally {
      db.close?.();
    }
  }

  async #openDatabase() {
    const request = this.#indexedDB.open(this.#databaseName, this.#version);
    request.addEventListener("upgradeneeded", () => {
      const db = request.result;
      if (!db.objectStoreNames.contains(this.#storeName)) {
        db.createObjectStore(this.#storeName);
      }
    }, { once: true });
    return requestToPromise(request);
  }
}

function requireSnapshotClient(client) {
  for (const method of ["exportStoreSnapshot", "restoreStoreSnapshot"]) {
    if (!client || typeof client[method] !== "function") {
      throw new TypeError(`SDK_WASM_ERR_SNAPSHOT_CLIENT_METHOD_MISSING:${method}`);
    }
  }
}

function requireSnapshotPersistence(persistence) {
  for (const method of ["loadSnapshotB64", "saveSnapshotB64", "clearSnapshot"]) {
    if (!persistence || typeof persistence[method] !== "function") {
      throw new TypeError(`SDK_WASM_ERR_SNAPSHOT_PERSISTENCE_METHOD_MISSING:${method}`);
    }
  }
}

function requireSnapshotB64(value) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new TypeError("SDK_WASM_ERR_SNAPSHOT_B64_REQUIRED");
  }
  return value;
}

function requireNonEmptyString(value, name) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new TypeError(`SDK_WASM_ERR_${name.toUpperCase()}_REQUIRED`);
  }
  return value;
}

function requestToPromise(request) {
  return new Promise((resolve, reject) => {
    request.addEventListener("success", () => resolve(request.result), { once: true });
    request.addEventListener("error", () => {
      reject(request.error ?? new GrainSnapshotPersistenceError("SDK_WASM_ERR_INDEXEDDB_REQUEST"));
    }, { once: true });
  });
}

function transactionDone(tx) {
  if (!tx || typeof tx.addEventListener !== "function") {
    return Promise.resolve();
  }
  return new Promise((resolve, reject) => {
    tx.addEventListener("complete", () => resolve(), { once: true });
    tx.addEventListener("abort", () => reject(tx.error ?? new Error("IndexedDB transaction aborted")), { once: true });
    tx.addEventListener("error", () => reject(tx.error ?? new Error("IndexedDB transaction failed")), { once: true });
  });
}
