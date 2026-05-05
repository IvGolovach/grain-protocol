export const SCANNER_ACCEPT_REQUIRES_VERIFIED_PREVIEW_DIAG =
  "SDK_ERR_EXAMPLE_ACCEPT_REQUIRES_VERIFIED_PREVIEW";
export const SCANNER_ACCEPT_REQUIRES_TRUST_DIAG = "SDK_ERR_EXAMPLE_ACCEPT_REQUIRES_TRUST";

export function createScannerShell(client) {
  requireClient(client);

  const state = {
    qrString: "",
    trustPubB64: "",
    previewStatus: null,
    acceptStatus: null,
    diagnostics: [],
    canAccept: false,
    acceptedCount: 0,
    acceptedScanId: null,
  };

  return {
    get state() {
      return structuredClone(state);
    },

    setQrString(value) {
      state.qrString = String(value);
      resetDecisionState(state);
    },

    setTrustPubB64(value) {
      state.trustPubB64 = String(value);
      resetDecisionState(state);
    },

    receiveCameraPayload(payload) {
      state.qrString = requireCameraPayload(payload).qrString;
      resetDecisionState(state);
    },

    preview() {
      const preview = client.scanPreview({
        qrString: state.qrString,
        trustPubB64: normalizedTrustInput(state),
      });

      state.previewStatus = preview.status;
      state.acceptStatus = null;
      state.diagnostics = preview.diag;
      state.canAccept = preview.status === "Verified";
      state.acceptedCount = client.listAcceptedScans().length;
      state.acceptedScanId = null;
      return this.state;
    },

    accept() {
      if (state.previewStatus !== "Verified" || !state.canAccept) {
        state.acceptStatus = null;
        state.diagnostics = [SCANNER_ACCEPT_REQUIRES_VERIFIED_PREVIEW_DIAG];
        state.canAccept = false;
        state.acceptedScanId = null;
        return this.state;
      }

      const trustPubB64 = normalizedTrustInput(state);
      if (trustPubB64 === null) {
        state.acceptStatus = null;
        state.diagnostics = [SCANNER_ACCEPT_REQUIRES_TRUST_DIAG];
        state.canAccept = false;
        state.acceptedScanId = null;
        return this.state;
      }

      const accepted = client.scanAccept({
        qrString: state.qrString,
        trustPubB64,
      });

      state.acceptStatus = accepted.status;
      state.acceptedScanId = accepted.scanId;
      state.diagnostics = accepted.diag;
      state.acceptedCount = client.listAcceptedScans().length;
      state.canAccept = state.previewStatus === "Verified";
      return this.state;
    },
  };
}

export function mountScannerShell(root, client, { cameraAdapter = null } = {}) {
  const shell = createScannerShell(client);
  root.replaceChildren();
  root.classList.add("grain-scanner");

  const scanInput = document.createElement("textarea");
  scanInput.placeholder = "GR1 string";
  scanInput.rows = 6;

  const trustInput = document.createElement("input");
  trustInput.placeholder = "Trust public key";
  trustInput.autocapitalize = "off";
  trustInput.autocomplete = "off";
  trustInput.spellcheck = false;

  const previewButton = document.createElement("button");
  previewButton.type = "button";
  previewButton.textContent = "Preview";

  const acceptButton = document.createElement("button");
  acceptButton.type = "button";
  acceptButton.textContent = "Accept";
  acceptButton.disabled = true;

  const cameraButton = document.createElement("button");
  cameraButton.type = "button";
  cameraButton.textContent = "Camera";
  cameraButton.hidden = cameraAdapter === null;

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
    shell.setTrustPubB64(trustInput.value);
    render();
  });
  previewButton.addEventListener("click", () => {
    shell.preview();
    render();
  });
  acceptButton.addEventListener("click", () => {
    shell.accept();
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

  root.append(scanInput, trustInput, previewButton, acceptButton, cameraButton, video, status, diagnostics);
  render();
  return shell;
}

function requireClient(client) {
  for (const method of ["scanPreview", "scanAccept", "listAcceptedScans"]) {
    if (!client || typeof client[method] !== "function") {
      throw new TypeError(`SDK_ERR_EXAMPLE_CLIENT_METHOD_MISSING:${method}`);
    }
  }
}

function normalizedTrustInput(state) {
  const trimmed = state.trustPubB64.trim();
  return trimmed.length === 0 ? null : trimmed;
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
}
