#!/usr/bin/env node
import assert from "node:assert/strict";

import { GrainMemorySnapshotPersistence } from "../../../sdk/wasm/src/browser-storage.mjs";
import { bootGrainWebStarter } from "../src/main.mjs";

const SAMPLE_QR = "gr1:demo";
const TRUST_BUNDLE_JSON = JSON.stringify({
  bundle_v: 1,
  anchors: [
    {
      id: "fixture:primary",
      trust_pub_b64: "dHJ1c3QtZGVtbw==",
    },
  ],
});

async function starterPreviewsAcceptsPersistsAndRestores() {
  const root = new FakeElement("main");
  const records = [];
  const snapshots = new Map();
  const snapshotPersistence = new GrainMemorySnapshotPersistence();
  const shell = await bootGrainWebStarter({
    root,
    client: createWorkflowClient({ records, snapshots }),
    trustBundleJson: TRUST_BUNDLE_JSON,
    snapshotPersistence,
    sampleQrString: SAMPLE_QR,
  });

  const controls = controlsByText(root);
  assert.equal(shell.state.lifecycleStatus, "Ready");
  assert.equal(shell.state.snapshotStatus, "Exported");
  assert.equal(controls.Scan.hidden, false);

  await controls.Scan.click();
  assert.equal(shell.state.qrString, SAMPLE_QR);

  await controls.Preview.click();
  assert.equal(shell.state.previewStatus, "Verified");
  assert.equal(shell.state.canAccept, true);

  await controls.Accept.click();
  assert.equal(shell.state.acceptStatus, "Accepted");
  assert.equal(shell.state.acceptedCount, 1);
  assert.notEqual(await snapshotPersistence.loadSnapshotB64(), null);

  await controls.Export.click();
  assert.equal(shell.state.exportStatus, "Exported");
  assert.equal(shell.state.exportAcceptedCount, 1);
  assert.equal(shell.state.exportDeviceCount, 2);

  const restoredRoot = new FakeElement("main");
  const restored = await bootGrainWebStarter({
    root: restoredRoot,
    client: createWorkflowClient({ records: [], snapshots }),
    trustBundleJson: TRUST_BUNDLE_JSON,
    snapshotPersistence,
    sampleQrString: SAMPLE_QR,
  });
  assert.equal(restored.state.snapshotStatus, "Restored");
  assert.equal(restored.state.acceptedCount, 1);

  const restoredControls = controlsByText(restoredRoot);
  await restoredControls.Scan.click();
  await restoredControls.Preview.click();
  await restoredControls.Accept.click();
  assert.equal(restored.state.acceptStatus, "AlreadyAccepted");
  assert.equal(restored.state.acceptedCount, 1);
}

async function starterWithoutSampleHidesScanControl() {
  const root = new FakeElement("main");
  await bootGrainWebStarter({
    root,
    client: createWorkflowClient(),
    trustBundleJson: TRUST_BUNDLE_JSON,
    snapshotPersistence: new GrainMemorySnapshotPersistence(),
  });
  assert.equal(controlsByText(root).Scan.hidden, true);
}

function controlsByText(root) {
  return Object.fromEntries(
    root.children
      .filter((child) => child.tagName === "button")
      .map((child) => [child.textContent, child])
  );
}

function createWorkflowClient({ records = [], snapshots = new Map() } = {}) {
  let lifecycle = {
    status: "Uninitialized",
    diag: ["SDK_ERR_IDENTITY_MISSING"],
    deviceCount: 0,
    lifecycleEventCount: 0,
  };
  let snapshotCounter = 0;

  return {
    scanPreviewWithTrustProvider(input) {
      assert.equal(input.qrString, SAMPLE_QR);
      const resolved = resolveTrust(input);
      if (resolved.diag !== null) {
        return rejectedPreview(resolved.diag);
      }
      return { status: "Verified", diag: [], coseB64: "cose-demo" };
    },
    scanAcceptWithTrustProvider(input) {
      assert.equal(input.qrString, SAMPLE_QR);
      const resolved = resolveTrust(input);
      if (resolved.diag !== null) {
        return rejectedAccept(resolved.diag);
      }
      if (records.length === 0) {
        records.push({ scanId: "scan-demo" });
        return { status: "Accepted", diag: [], scanId: "scan-demo" };
      }
      return { status: "AlreadyAccepted", diag: [], scanId: "scan-demo" };
    },
    listAcceptedScans() {
      return records;
    },
    createRootIdentity(input) {
      assert.equal(input.label, "web-starter");
      lifecycle = { status: "Ready", diag: [], deviceCount: 1, lifecycleEventCount: 0 };
      return { status: "Created", diag: [], deviceCount: 1, lifecycleEventCount: 0 };
    },
    addDeviceKey(input) {
      assert.equal(input.label, "browser");
      lifecycle = { status: "Ready", diag: [], deviceCount: 2, lifecycleEventCount: 1 };
      return { status: "Added", diag: [], deviceCount: 2, lifecycleEventCount: 1 };
    },
    clientLifecycle() {
      return lifecycle;
    },
    exportStoreSnapshot() {
      const snapshotB64 = `snapshot-${++snapshotCounter}`;
      snapshots.set(snapshotB64, {
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
      const snapshot = snapshots.get(snapshotB64);
      if (snapshot === undefined) {
        return rejectedSnapshot();
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
    exportSyncBundle() {
      return {
        status: "Exported",
        diag: [],
        bundleB64: "sync-demo",
        acceptedRecordCount: records.length,
        deviceCount: lifecycle.deviceCount,
        lifecycleEventCount: lifecycle.lifecycleEventCount,
      };
    },
  };
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
  return { status: "Rejected", diag: [diag], coseB64: null };
}

function rejectedAccept(diag) {
  return { status: "Rejected", diag: [diag], scanId: null };
}

function rejectedSnapshot() {
  return {
    status: "Rejected",
    diag: ["SDK_ERR_STORE_SNAPSHOT_INVALID"],
    snapshotB64: null,
    acceptedRecordCount: 0,
    deviceCount: 0,
    lifecycleEventCount: 0,
  };
}

class FakeElement {
  constructor(tagName) {
    this.tagName = tagName;
    this.children = [];
    this.disabled = false;
    this.hidden = false;
    this.listeners = new Map();
    this.placeholder = "";
    this.rows = 0;
    this.spellcheck = true;
    this.textContent = "";
    this.type = "";
    this.value = "";
  }

  addEventListener(type, listener) {
    this.listeners.set(type, listener);
  }

  append(...children) {
    this.children.push(...children);
  }

  replaceChildren(...children) {
    this.children = children;
  }

  async click() {
    const listener = this.listeners.get("click");
    if (listener) {
      await listener();
    }
  }
}

globalThis.document = {
  createElement(tagName) {
    return new FakeElement(tagName);
  },
};

await starterPreviewsAcceptsPersistsAndRestores();
await starterWithoutSampleHidesScanControl();
console.log("Web WASM starter smoke: PASS");
