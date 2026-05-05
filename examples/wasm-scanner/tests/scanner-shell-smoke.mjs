#!/usr/bin/env node
import assert from "node:assert/strict";

import {
  SCANNER_ACCEPT_REQUIRES_VERIFIED_PREVIEW_DIAG,
  createScannerShell,
} from "../src/scanner-shell.mjs";
import { createInjectedCameraAdapter } from "../src/camera-adapter.mjs";

const savedRecords = [];
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
};

const shell = createScannerShell(client);
let state = shell.accept();
assert.equal(state.canAccept, false);
assert.deepEqual(state.diagnostics, [SCANNER_ACCEPT_REQUIRES_VERIFIED_PREVIEW_DIAG]);

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
