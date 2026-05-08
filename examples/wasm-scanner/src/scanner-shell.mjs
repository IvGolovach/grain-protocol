import { GrainSnapshotCoordinator } from "../../../sdk/wasm/src/browser-storage.mjs";

export const SCANNER_ACCEPT_REQUIRES_VERIFIED_PREVIEW_DIAG =
  "SDK_ERR_EXAMPLE_ACCEPT_REQUIRES_VERIFIED_PREVIEW";
export const SCANNER_SNAPSHOT_PERSISTENCE_DIAG = "SDK_ERR_EXAMPLE_SNAPSHOT_PERSISTENCE";

export function createScannerShell(client, { trustProvider, snapshotPersistence = null } = {}) {
  requireClient(client);
  requireTrustProvider(trustProvider);
  const snapshotCoordinator = snapshotPersistence === null ? null : new GrainSnapshotCoordinator(snapshotPersistence);

  const state = {
    qrString: "",
    trustAnchorId: "",
    previewStatus: null,
    acceptStatus: null,
    diagnostics: [],
    canAccept: false,
    acceptedCount: 0,
    acceptedScanId: null,
    lifecycleStatus: null,
    deviceCount: 0,
    lifecycleEventCount: 0,
    snapshotStatus: null,
    exportStatus: null,
    exportAcceptedCount: 0,
    exportDeviceCount: 0,
    exportLifecycleEventCount: 0,
  };

  return {
    get state() {
      return structuredClone(state);
    },

    setQrString(value) {
      state.qrString = String(value);
      resetDecisionState(state);
    },

    setTrustAnchorId(value) {
      state.trustAnchorId = String(value);
      resetDecisionState(state);
    },

    receiveCameraPayload(payload) {
      state.qrString = requireCameraPayload(payload).qrString;
      resetDecisionState(state);
    },

    async prepareLocalIdentity({ rootLabel = "phone", deviceLabel = "scanner" } = {}) {
      const lifecycle = client.clientLifecycle();
      if (lifecycle.status === "Ready") {
        state.diagnostics = lifecycle.diag;
        applyLifecycle(state, lifecycle);
        return this.state;
      }
      if (lifecycle.status === "Uninitialized") {
        const root = client.createRootIdentity({ label: rootLabel });
        if (root.diag.length > 0) {
          state.diagnostics = root.diag;
          refreshLifecycle(state, client);
          return this.state;
        }
      }

      const device = client.addDeviceKey({ label: deviceLabel });
      state.diagnostics = device.diag;
      refreshLifecycle(state, client);
      await persistSnapshot(state, client, snapshotCoordinator);
      return this.state;
    },

    preview() {
      const preview = client.scanPreviewWithTrustProvider({
        qrString: state.qrString,
        trustAnchorId: normalizedTrustAnchorId(state),
        trustProvider,
      });

      state.previewStatus = preview.status;
      state.acceptStatus = null;
      state.diagnostics = preview.diag;
      state.canAccept = preview.status === "Verified";
      state.acceptedCount = client.listAcceptedScans().length;
      state.acceptedScanId = null;
      return this.state;
    },

    async accept() {
      if (state.previewStatus !== "Verified" || !state.canAccept) {
        const diagnostics = state.previewStatus === "Rejected" && state.diagnostics.length > 0
          ? state.diagnostics
          : [SCANNER_ACCEPT_REQUIRES_VERIFIED_PREVIEW_DIAG];
        state.acceptStatus = null;
        state.diagnostics = diagnostics;
        state.canAccept = false;
        state.acceptedScanId = null;
        return this.state;
      }

      const accepted = client.scanAcceptWithTrustProvider({
        qrString: state.qrString,
        trustAnchorId: normalizedTrustAnchorId(state),
        trustProvider,
      });

      state.acceptStatus = accepted.status;
      state.acceptedScanId = accepted.scanId;
      state.diagnostics = accepted.diag;
      state.acceptedCount = client.listAcceptedScans().length;
      state.canAccept = state.previewStatus === "Verified";
      if (accepted.status === "Accepted" || accepted.status === "AlreadyAccepted") {
        await persistSnapshot(state, client, snapshotCoordinator);
      }
      return this.state;
    },

    async restorePersistedSnapshot() {
      if (snapshotCoordinator === null) {
        return this.state;
      }
      try {
        const restored = await snapshotCoordinator.restore(client);
        if (restored === null) {
          state.snapshotStatus = "Empty";
          refreshLifecycle(state, client);
          state.acceptedCount = client.listAcceptedScans().length;
          return this.state;
        }
        state.snapshotStatus = restored.status;
        state.diagnostics = restored.diag;
        state.acceptedCount = restored.acceptedRecordCount;
        refreshLifecycle(state, client);
      } catch (_) {
        state.snapshotStatus = "PersistenceError";
        state.diagnostics = [SCANNER_SNAPSHOT_PERSISTENCE_DIAG];
      }
      return this.state;
    },

    exportSyncBundleForShare() {
      const exported = client.exportSyncBundle();
      state.exportStatus = exported.status;
      state.exportAcceptedCount = exported.acceptedRecordCount;
      state.exportDeviceCount = exported.deviceCount;
      state.exportLifecycleEventCount = exported.lifecycleEventCount;
      state.diagnostics = exported.diag;
      return exported;
    },
  };
}

export function mountScannerShell(root, client, {
  cameraAdapter = null,
  trustProvider,
  snapshotPersistence = null,
} = {}) {
  const shell = createScannerShell(client, { trustProvider, snapshotPersistence });
  root.replaceChildren();
  root.classList.add("grain-scanner");

  const scanInput = document.createElement("textarea");
  scanInput.placeholder = "GR1 string";
  scanInput.rows = 6;

  const trustInput = document.createElement("input");
  trustInput.placeholder = "Trust anchor ID";
  trustInput.autocapitalize = "off";
  trustInput.autocomplete = "off";
  trustInput.spellcheck = false;

  const previewButton = document.createElement("button");
  previewButton.type = "button";
  previewButton.textContent = "Preview";

  const prepareButton = document.createElement("button");
  prepareButton.type = "button";
  prepareButton.textContent = "Prepare device";

  const acceptButton = document.createElement("button");
  acceptButton.type = "button";
  acceptButton.textContent = "Accept";
  acceptButton.disabled = true;

  const cameraButton = document.createElement("button");
  cameraButton.type = "button";
  cameraButton.textContent = "Camera";
  cameraButton.hidden = cameraAdapter === null;

  const restoreButton = document.createElement("button");
  restoreButton.type = "button";
  restoreButton.textContent = "Restore";
  restoreButton.hidden = snapshotPersistence === null;

  const video = document.createElement("video");
  video.playsInline = true;
  video.muted = true;
  video.hidden = cameraAdapter === null;

  const status = document.createElement("output");
  const diagnostics = document.createElement("ul");

  function render() {
    const current = shell.state;
    acceptButton.disabled = !current.canAccept;
    status.value = [
      current.previewStatus ? `Preview: ${current.previewStatus}` : null,
      current.acceptStatus ? `Accept: ${current.acceptStatus}` : null,
      current.lifecycleStatus ? `Lifecycle: ${current.lifecycleStatus}` : null,
      current.lifecycleStatus ? `Devices: ${current.deviceCount}` : null,
      current.snapshotStatus ? `Snapshot: ${current.snapshotStatus}` : null,
      current.exportStatus ? `Export: ${current.exportStatus}` : null,
      `Saved: ${current.acceptedCount}`,
    ].filter(Boolean).join(" | ");
    diagnostics.replaceChildren(...current.diagnostics.map((diagnostic) => {
      const item = document.createElement("li");
      item.textContent = diagnostic;
      return item;
    }));
  }

  scanInput.addEventListener("input", () => {
    shell.setQrString(scanInput.value);
    render();
  });
  trustInput.addEventListener("input", () => {
    shell.setTrustAnchorId(trustInput.value);
    render();
  });
  previewButton.addEventListener("click", () => {
    shell.preview();
    render();
  });
  prepareButton.addEventListener("click", async () => {
    await shell.prepareLocalIdentity();
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
  cameraButton.addEventListener("click", async () => {
    if (cameraAdapter.start) {
      await cameraAdapter.start(video);
    }
    const payload = await cameraAdapter.scanOnce(video);
    shell.receiveCameraPayload(payload);
    scanInput.value = payload.qrString;
    render();
  });

  root.append(
    scanInput,
    trustInput,
    prepareButton,
    restoreButton,
    previewButton,
    acceptButton,
    cameraButton,
    video,
    status,
    diagnostics,
  );
  render();
  return shell;
}

function requireClient(client) {
  for (const method of [
    "scanPreviewWithTrustProvider",
    "scanAcceptWithTrustProvider",
    "listAcceptedScans",
    "createRootIdentity",
    "addDeviceKey",
    "clientLifecycle",
    "exportSyncBundle",
  ]) {
    if (!client || typeof client[method] !== "function") {
      throw new TypeError(`SDK_ERR_EXAMPLE_CLIENT_METHOD_MISSING:${method}`);
    }
  }
}

function requireTrustProvider(trustProvider) {
  if (!trustProvider || typeof trustProvider.trustPubB64 !== "function") {
    throw new TypeError("SDK_ERR_EXAMPLE_TRUST_PROVIDER_MISSING");
  }
}

function refreshLifecycle(state, client) {
  const lifecycle = client.clientLifecycle();
  applyLifecycle(state, lifecycle);
}

function applyLifecycle(state, lifecycle) {
  state.lifecycleStatus = lifecycle.status;
  state.deviceCount = lifecycle.deviceCount;
  state.lifecycleEventCount = lifecycle.lifecycleEventCount;
}

function normalizedTrustAnchorId(state) {
  return state.trustAnchorId.trim();
}

async function persistSnapshot(state, client, snapshotCoordinator) {
  if (snapshotCoordinator === null) {
    return;
  }
  try {
    const exported = await snapshotCoordinator.persist(client);
    state.snapshotStatus = exported.status;
    if (exported.diag.length > 0) {
      state.diagnostics = exported.diag;
    }
  } catch (_) {
    state.snapshotStatus = "PersistenceError";
    state.diagnostics = [SCANNER_SNAPSHOT_PERSISTENCE_DIAG];
  }
}

function requireCameraPayload(payload) {
  if (!payload || typeof payload.qrString !== "string" || payload.qrString.length === 0) {
    throw new TypeError("SDK_ERR_EXAMPLE_CAMERA_PAYLOAD_INVALID");
  }
  return payload;
}

function resetDecisionState(state) {
  state.previewStatus = null;
  state.acceptStatus = null;
  state.diagnostics = [];
  state.canAccept = false;
  state.acceptedScanId = null;
  state.exportStatus = null;
  state.exportAcceptedCount = 0;
  state.exportDeviceCount = 0;
  state.exportLifecycleEventCount = 0;
}
