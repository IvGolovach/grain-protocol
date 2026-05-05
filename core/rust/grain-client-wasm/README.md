# grain-client-wasm

WASM client workflow binding for mobile-web and browser-like Grain clients.

This crate is workflow-shaped. It exports scan preview, scan accept, and list
accepted scans over `grain-client-core`. It does not expose QR, COSE,
DAG-CBOR, or protocol runner operations.

The dependency on `grain-client-core` disables the default `bindings` feature
so the target-side WASM build does not pull in UniFFI runtime code.

The ABI is pointer/length JSON, matching the repository's existing WASM smoke
style without requiring a global `wasm-bindgen` install.

Exports:
- `grain_client_alloc(len)`
- `grain_client_dealloc(ptr, len)`
- `grain_client_store_new()`
- `grain_client_store_free(store_ptr)`
- `grain_client_scan_preview(ptr, len)`
- `grain_client_scan_accept(store_ptr, ptr, len)`
- `grain_client_list_accepted_scans(store_ptr)`
