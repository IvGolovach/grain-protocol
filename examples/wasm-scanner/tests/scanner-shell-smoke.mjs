#!/usr/bin/env node
import assert from "node:assert/strict";

import {
  SCANNER_ACCEPT_REQUIRES_VERIFIED_PREVIEW_DIAG,
  createScannerShell,
} from "../src/scanner-shell.mjs";
import { createInjectedCameraAdapter } from "../src/camera-adapter.mjs";

const savedRecords = [];
let lifecycle = {
  status: "Uninitialized",
  diag: ["SDK_ERR_IDENTITY_MISSING"],
  rootKid: null,
  activeAk: null,
  deviceCount: 0,
  revokedCount: 0,
  acceptedRecordCount: 0,
  lifecycleEventCount: 0,
};
let addDeviceKeyCallCount = 0;
const client = {
  scanPreview(input) {
    assert.equal(input.qrString, "gr1:demo");
    assert.equal(input.trustPubB64, "trust-demo");
    return {
      status: "Verified",
      diag: [],
      coseB64: "cose-demo",
    };
  },
  scanAccept(input) {
    assert.equal(input.qrString, "gr1:demo");
    assert.equal(input.trustPubB64, "trust-demo");
    if (savedRecords.length === 0) {
      savedRecords.push({
        scanId: "scan-demo",
        coseB64: "cose-demo",
        trustPubB64: "trust-demo",
      });
      return {
        status: "Accepted",
        diag: [],
        scanId: "scan-demo",
        coseB64: "cose-demo",
        trustPubB64: "trust-demo",
      };
    }
    return {
      status: "AlreadyAccepted",
      diag: [],
      scanId: "scan-demo",
      coseB64: "cose-demo",
      trustPubB64: "trust-demo",
    };
  },
  listAcceptedScans() {
    return savedRecords;
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
      acceptedRecordCount: savedRecords.length,
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
    addDeviceKeyCallCount += 1;
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
};

const shell = createScannerShell(client);
let state = shell.accept();
assert.equal(state.canAccept, false);
assert.deepEqual(state.diagnostics, [SCANNER_ACCEPT_REQUIRES_VERIFIED_PREVIEW_DIAG]);

state = shell.prepareLocalIdentity();
assert.equal(state.lifecycleStatus, "Ready");
assert.equal(state.deviceCount, 2);
assert.equal(state.lifecycleEventCount, 1);
state = shell.prepareLocalIdentity();
assert.equal(state.deviceCount, 2);
assert.equal(state.lifecycleEventCount, 1);
assert.equal(addDeviceKeyCallCount, 1);

shell.setTrustPubB64(" trust-demo ");
const cameraAdapter = createInjectedCameraAdapter(["gr1:demo"]);
shell.receiveCameraPayload(await cameraAdapter.scanOnce());
state = shell.preview();
assert.equal(state.previewStatus, "Verified");
assert.equal(state.canAccept, true);
assert.deepEqual(state.diagnostics, []);

state = shell.accept();
assert.equal(state.acceptStatus, "Accepted");
assert.equal(state.acceptedCount, 1);
assert.equal(state.acceptedScanId, "scan-demo");

state = shell.accept();
assert.equal(state.acceptStatus, "AlreadyAccepted");
assert.equal(state.acceptedCount, 1);

console.log("WASM scanner shell smoke: PASS");
