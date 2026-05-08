import { createScannerShell } from "../../../examples/wasm-scanner/src/scanner-shell.mjs";
import { createInjectedCameraAdapter } from "../../../examples/wasm-scanner/src/camera-adapter.mjs";
import { GrainIndexedDBSnapshotPersistence } from "../../../sdk/wasm/src/browser-storage.mjs";
import { GrainClient, GrainStaticTrustProvider } from "../../../sdk/wasm/src/index.mjs";

export async function bootGrainWebStarter({
  root,
  client = null,
  wasmExports,
  trustBundleJson,
  snapshotPersistence = new GrainIndexedDBSnapshotPersistence(),
  sampleQrString = "",
} = {}) {
  if (!root) {
    throw new TypeError("SDK_ERR_WEB_STARTER_ROOT_REQUIRED");
  }
  const grainClient = client ?? new GrainClient(wasmExports);
  const trustProvider = GrainStaticTrustProvider.fromBundleJson(trustBundleJson);
  const cameraAdapter = sampleQrString ? createInjectedCameraAdapter([sampleQrString]) : null;
  const shell = createScannerShell(grainClient, {
    trustProvider,
    snapshotPersistence,
  });

  await shell.restorePersistedSnapshot();
  await shell.prepareLocalIdentity({ rootLabel: "web-starter", deviceLabel: "browser" });
  mountControls(root, shell, cameraAdapter);
  return shell;
}

function mountControls(root, shell, cameraAdapter) {
  const pasteInput = document.createElement("textarea");
  pasteInput.placeholder = "Paste GR1 string";
  pasteInput.rows = 6;

  const trustInput = document.createElement("input");
  trustInput.value = "fixture:primary";
  trustInput.autocomplete = "off";
  trustInput.spellcheck = false;

  const scanButton = document.createElement("button");
  scanButton.type = "button";
  scanButton.textContent = "Scan";
  scanButton.hidden = cameraAdapter === null;
  scanButton.disabled = cameraAdapter === null;

  const previewButton = document.createElement("button");
  previewButton.type = "button";
  previewButton.textContent = "Preview";

  const acceptButton = document.createElement("button");
  acceptButton.type = "button";
  acceptButton.textContent = "Accept";

  const restoreButton = document.createElement("button");
  restoreButton.type = "button";
  restoreButton.textContent = "Restore";

  const listButton = document.createElement("button");
  listButton.type = "button";
  listButton.textContent = "List";

  const exportButton = document.createElement("button");
  exportButton.type = "button";
  exportButton.textContent = "Export";

  const status = document.createElement("output");

  function render() {
    const current = shell.state;
    acceptButton.disabled = !current.canAccept;
    status.value = [
      current.previewStatus ? `Preview: ${current.previewStatus}` : null,
      current.acceptStatus ? `Accept: ${current.acceptStatus}` : null,
      current.snapshotStatus ? `Snapshot: ${current.snapshotStatus}` : null,
      current.exportStatus ? `Export: ${current.exportStatus}` : null,
      `Saved: ${current.acceptedCount}`,
    ].filter(Boolean).join(" | ");
  }

  pasteInput.addEventListener("input", () => {
    shell.setQrString(pasteInput.value);
    render();
  });
  trustInput.addEventListener("input", () => {
    shell.setTrustAnchorId(trustInput.value);
    render();
  });
  scanButton.addEventListener("click", async () => {
    if (cameraAdapter === null) {
      return;
    }
    const payload = await cameraAdapter.scanOnce();
    shell.receiveCameraPayload(payload);
    pasteInput.value = payload.qrString;
    render();
  });
  previewButton.addEventListener("click", () => {
    shell.preview();
    render();
  });
  acceptButton.addEventListener("click", async () => {
    await shell.accept();
    render();
  });
  restoreButton.addEventListener("click", async () => {
    await shell.restorePersistedSnapshot();
    render();
  });
  listButton.addEventListener("click", () => {
    render();
  });
  exportButton.addEventListener("click", () => {
    shell.exportSyncBundleForShare();
    render();
  });

  shell.setTrustAnchorId(trustInput.value);

  root.replaceChildren(
    pasteInput,
    trustInput,
    scanButton,
    restoreButton,
    previewButton,
    acceptButton,
    listButton,
    exportButton,
    status,
  );
  render();
}
