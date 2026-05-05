import { createGrainClientFromInstance } from "../../../sdk/wasm/src/index.mjs";
import { createBrowserCameraAdapter } from "./camera-adapter.mjs";
import { mountScannerShell } from "./scanner-shell.mjs";

export async function createBrowserGrainClient({
  wasmUrl = "./grain_client_wasm.wasm",
  imports = {},
} = {}) {
  const response = await fetch(wasmUrl);
  if (!response.ok) {
    throw new Error(`SDK_ERR_EXAMPLE_WASM_FETCH:${response.status}`);
  }
  const bytes = await response.arrayBuffer();
  const { instance } = await WebAssembly.instantiate(bytes, imports);
  return createGrainClientFromInstance(instance);
}

export async function mountBrowserScanner({
  root = document.querySelector("#grain-scanner"),
  client,
  cameraAdapter = null,
  wasmUrl,
  imports,
} = {}) {
  if (!root) {
    throw new Error("SDK_ERR_EXAMPLE_ROOT_MISSING");
  }
  const grainClient = client ?? await createBrowserGrainClient({ wasmUrl, imports });
  return mountScannerShell(root, grainClient, { cameraAdapter });
}

if (typeof window !== "undefined") {
  window.GrainScannerExample = {
    createBrowserCameraAdapter,
    createBrowserGrainClient,
    mountBrowserScanner,
  };

  window.addEventListener("DOMContentLoaded", () => {
    if (window.GrainScannerClient) {
      void mountBrowserScanner({
        client: window.GrainScannerClient,
        cameraAdapter: window.GrainScannerQrDecoder
          ? createBrowserCameraAdapter({ qrDecoder: window.GrainScannerQrDecoder })
          : null,
      });
    }
  });
}
