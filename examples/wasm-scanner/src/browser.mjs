import { createGrainClientFromInstance } from "../../../sdk/wasm/src/index.mjs";
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
  wasmUrl,
  imports,
} = {}) {
  if (!root) {
    throw new Error("SDK_ERR_EXAMPLE_ROOT_MISSING");
  }
  const grainClient = client ?? await createBrowserGrainClient({ wasmUrl, imports });
  return mountScannerShell(root, grainClient);
}

if (typeof window !== "undefined") {
  window.GrainScannerExample = {
    createBrowserGrainClient,
    mountBrowserScanner,
  };

  window.addEventListener("DOMContentLoaded", () => {
    if (window.GrainScannerClient) {
      void mountBrowserScanner({ client: window.GrainScannerClient });
    }
  });
}
