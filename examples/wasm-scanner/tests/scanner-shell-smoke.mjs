#!/usr/bin/env node
import assert from "node:assert/strict";

import {
  GrainMemorySnapshotPersistence,
} from "../../../sdk/wasm/src/browser-storage.mjs";
import { GrainStaticTrustProvider } from "../../../sdk/wasm/src/index.mjs";
import { createInjectedCameraAdapter } from "../src/camera-adapter.mjs";
import {
  SCANNER_ACCEPT_REQUIRES_VERIFIED_PREVIEW_DIAG,
  createScannerShell,
} from "../src/scanner-shell.mjs";

const snapshotPayloads = new Map();
let snapshotCounter = 0;

async function acceptRequiresVerifiedPreview() {
  const client = createWorkflowClient();
  const persistence = new RecordingSnapshotPersistence();
  const shell = createScannerShell(client, {
    trustProvider: trustProvider(),
    snapshotPersistence: persistence,
  });

  const state = await shell.accept();

  assert.equal(state.canAccept, false);
  assert.equal(state.acceptStatus, null);
  assert.equal(state.acceptedCount, 0);
  assert.equal(persistence.saveCount, 0);
  assert.deepEqual(state.diagnostics, [SCANNER_ACCEPT_REQUIRES_VERIFIED_PREVIEW_DIAG]);
}

async function verifiedPreviewEnablesAcceptAndPersistsSnapshot() {
  const snapshotPersistence = new GrainMemorySnapshotPersistence();
  const records = [];

  const client = createWorkflowClient({ records });
  const shell = createScannerShell(client, {
    trustProvider: trustProvider(),
    snapshotPersistence,
  });

  let state = await shell.prepareLocalIdentity();
  assert.equal(state.lifecycleStatus, "Ready");
  assert.equal(state.deviceCount, 2);
  assert.equal(state.lifecycleEventCount, 1);
  assert.equal(state.snapshotStatus, "Exported");

  state = await shell.prepareLocalIdentity();
  assert.equal(state.deviceCount, 2);
  assert.equal(state.lifecycleEventCount, 1);

  shell.setTrustAnchorId(" publisher:primary ");
  const cameraAdapter = createInjectedCameraAdapter(["gr1:demo"]);
  shell.receiveCameraPayload(await cameraAdapter.scanOnce());

  state = shell.preview();
  assert.equal(state.previewStatus, "Verified");
  assert.equal(state.canAccept, true);
  assert.deepEqual(state.diagnostics, []);

  state = await shell.accept();
  assert.equal(state.acceptStatus, "Accepted");
  assert.equal(state.acceptedCount, 1);
  assert.equal(state.acceptedScanId, "scan-demo");
  assert.equal(state.snapshotStatus, "Exported");
  assert.notEqual(await snapshotPersistence.loadSnapshotB64(), null);

  state = await shell.accept();
  assert.equal(state.acceptStatus, "AlreadyAccepted");
  assert.equal(state.acceptedCount, 1);

  const restartedClient = createWorkflowClient({ records: [] });
  const restarted = createScannerShell(restartedClient, {
    trustProvider: trustProvider(),
    snapshotPersistence,
  });

  state = await restarted.restorePersistedSnapshot();
  assert.equal(state.snapshotStatus, "Restored");
  assert.equal(state.acceptedCount, 1);
  assert.equal(state.lifecycleStatus, "Ready");
}

async function blankTrustAnchorRejectsWithoutWrite() {
  await rejectedTrustAnchorDoesNotWrite({
    trustAnchorId: "   ",
    expectedDiag: "SDK_ERR_TRUST_ANCHOR_REQUIRED",
  });
}

async function unknownTrustAnchorRejectsWithoutWrite() {
  await rejectedTrustAnchorDoesNotWrite({
    trustAnchorId: "publisher:unknown",
    expectedDiag: "SDK_ERR_TRUST_ANCHOR_NOT_FOUND",
  });
}

async function rejectedTrustAnchorDoesNotWrite({ trustAnchorId, expectedDiag }) {
  const client = createWorkflowClient();
  const persistence = new RecordingSnapshotPersistence();
  const shell = createScannerShell(client, {
    trustProvider: trustProvider(),
    snapshotPersistence: persistence,
  });

  shell.setTrustAnchorId(trustAnchorId);
  shell.receiveCameraPayload({ qrString: "gr1:demo", source: "injected" });
  let state = shell.preview();

  assert.equal(state.previewStatus, "Rejected");
  assert.deepEqual(state.diagnostics, [expectedDiag]);
  assert.equal(state.canAccept, false);

  state = await shell.accept();

  assert.equal(state.acceptStatus, null);
  assert.equal(state.acceptedCount, 0);
  assert.equal(persistence.saveCount, 0);
  assert.deepEqual(state.diagnostics, [expectedDiag]);
}

function createWorkflowClient({ records = [] } = {}) {
  let lifecycle = {
    status: "Uninitialized",
    diag: ["SDK_ERR_IDENTITY_MISSING"],
    rootKid: null,
    activeAk: null,
    deviceCount: 0,
    revokedCount: 0,
    acceptedRecordCount: records.length,
    lifecycleEventCount: 0,
  };

  return {
    scanPreviewWithTrustProvider(input) {
      assert.equal(input.qrString, "gr1:demo");
      const resolved = resolveTrust(input);
      if (resolved.diag !== null) {
        return rejectedPreview(resolved.diag);
      }
      return {
        status: "Verified",
        diag: [],
        coseB64: "cose-demo",
      };
    },
    scanAcceptWithTrustProvider(input) {
      assert.equal(input.qrString, "gr1:demo");
      const resolved = resolveTrust(input);
      if (resolved.diag !== null) {
        return rejectedAccept(resolved.diag);
      }
      if (records.length === 0) {
        records.push({
          scanId: "scan-demo",
          coseB64: "cose-demo",
          trustPubB64: resolved.trustPubB64,
        });
        lifecycle = {
          ...lifecycle,
          acceptedRecordCount: records.length,
        };
        return {
          status: "Accepted",
          diag: [],
          scanId: "scan-demo",
          coseB64: "cose-demo",
          trustPubB64: resolved.trustPubB64,
        };
      }
      return {
        status: "AlreadyAccepted",
        diag: [],
        scanId: "scan-demo",
        coseB64: "cose-demo",
        trustPubB64: resolved.trustPubB64,
      };
    },
    listAcceptedScans() {
      return records;
    },
    clientLifecycle() {
      return lifecycle;
    },
    createRootIdentity(input) {
      assert.equal(input.label, "phone");
      lifecycle = {
        status: "Ready",
        diag: [],
        rootKid: "root-demo",
        activeAk: "root-demo",
        deviceCount: 1,
        revokedCount: 0,
        acceptedRecordCount: records.length,
        lifecycleEventCount: 0,
      };
      return {
        status: "Created",
        diag: [],
        rootKid: "root-demo",
        activeAk: "root-demo",
        bundleB64: "eyJidW5kbGVfdiI6MX0=",
        deviceCount: 1,
        revokedCount: 0,
        lifecycleEventCount: 0,
      };
    },
    addDeviceKey(input) {
      assert.equal(input.label, "scanner");
      lifecycle = {
        ...lifecycle,
        status: "Ready",
        deviceCount: 2,
        lifecycleEventCount: 1,
      };
      return {
        status: "Added",
        diag: [],
        deviceAk: "device-demo",
        activeAk: "root-demo",
        rootKid: "root-demo",
        deviceCount: 2,
        revokedCount: 0,
        lifecycleEventCount: 1,
      };
    },
    exportStoreSnapshot() {
      if (lifecycle.status !== "Ready" && records.length === 0) {
        return {
          status: "Empty",
          diag: [],
          snapshotB64: null,
          acceptedRecordCount: 0,
          deviceCount: 0,
          lifecycleEventCount: 0,
        };
      }
      const snapshotB64 = `snapshot-${++snapshotCounter}`;
      snapshotPayloads.set(snapshotB64, {
        records: structuredClone(records),
        lifecycle: structuredClone(lifecycle),
      });
      return {
        status: "Exported",
        diag: [],
        snapshotB64,
        acceptedRecordCount: records.length,
        deviceCount: lifecycle.deviceCount,
        lifecycleEventCount: lifecycle.lifecycleEventCount,
      };
    },
    restoreStoreSnapshot({ snapshotB64 }) {
      const snapshot = snapshotPayloads.get(snapshotB64);
      if (snapshot === undefined) {
        return {
          status: "Rejected",
          diag: ["SDK_ERR_STORE_SNAPSHOT_INVALID"],
          snapshotB64: null,
          acceptedRecordCount: records.length,
          deviceCount: lifecycle.deviceCount,
          lifecycleEventCount: lifecycle.lifecycleEventCount,
        };
      }
      records.splice(0, records.length, ...snapshot.records);
      lifecycle = snapshot.lifecycle;
      return {
        status: "Restored",
        diag: [],
        snapshotB64: null,
        acceptedRecordCount: records.length,
        deviceCount: lifecycle.deviceCount,
        lifecycleEventCount: lifecycle.lifecycleEventCount,
      };
    },
  };
}

class RecordingSnapshotPersistence {
  saveCount = 0;
  #snapshotB64 = null;

  async loadSnapshotB64() {
    return this.#snapshotB64;
  }

  async saveSnapshotB64(snapshotB64) {
    this.saveCount += 1;
    this.#snapshotB64 = snapshotB64;
  }

  async clearSnapshot() {
    this.#snapshotB64 = null;
  }
}

function trustProvider() {
  return new GrainStaticTrustProvider({
    "publisher:primary": "trust-demo",
  });
}

function resolveTrust(input) {
  const trustAnchorId = input.trustAnchorId.trim();
  if (trustAnchorId.length === 0) {
    return { diag: "SDK_ERR_TRUST_ANCHOR_REQUIRED", trustPubB64: null };
  }
  const trustPubB64 = input.trustProvider.trustPubB64(trustAnchorId);
  if (trustPubB64 === null || trustPubB64 === undefined) {
    return { diag: "SDK_ERR_TRUST_ANCHOR_NOT_FOUND", trustPubB64: null };
  }
  return { diag: null, trustPubB64 };
}

function rejectedPreview(diag) {
  return {
    status: "Rejected",
    diag: [diag],
    coseB64: null,
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

await acceptRequiresVerifiedPreview();
await verifiedPreviewEnablesAcceptAndPersistsSnapshot();
await blankTrustAnchorRejectsWithoutWrite();
await unknownTrustAnchorRejectsWithoutWrite();
console.log("WASM scanner shell smoke: PASS");
