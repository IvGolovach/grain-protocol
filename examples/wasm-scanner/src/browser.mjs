import { GrainIndexedDBSnapshotPersistence } from "../../../sdk/wasm/src/browser-storage.mjs";
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
  trustProvider = globalThis.GrainScannerTrustProvider,
  snapshotPersistence = createDefaultSnapshotPersistence(),
  wasmUrl,
  imports,
} = {}) {
  if (!root) {
    throw new Error("SDK_ERR_EXAMPLE_ROOT_MISSING");
  }
  if (!trustProvider) {
    throw new Error("SDK_ERR_EXAMPLE_TRUST_PROVIDER_MISSING");
  }
  const grainClient = client ?? await createBrowserGrainClient({ wasmUrl, imports });
  return mountScannerShell(root, grainClient, {
    cameraAdapter,
    trustProvider,
    snapshotPersistence,
  });
}

if (typeof window !== "undefined") {
  window.GrainScannerExample = {
    createBrowserCameraAdapter,
    createBrowserGrainClient,
    GrainIndexedDBSnapshotPersistence,
    mountBrowserScanner,
  };

  window.addEventListener("DOMContentLoaded", () => {
    if (window.GrainScannerClient && window.GrainScannerTrustProvider) {
      void mountBrowserScanner({
        client: window.GrainScannerClient,
        trustProvider: window.GrainScannerTrustProvider,
        cameraAdapter: window.GrainScannerQrDecoder
          ? createBrowserCameraAdapter({ qrDecoder: window.GrainScannerQrDecoder })
          : null,
      });
    }
  });
}

function createDefaultSnapshotPersistence() {
  if (globalThis.indexedDB === undefined) {
    return null;
  }
  return new GrainIndexedDBSnapshotPersistence();
}
