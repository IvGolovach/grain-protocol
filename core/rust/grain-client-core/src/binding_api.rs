use std::sync::Mutex;

use crate::ffi_types::{
    FfiAcceptedScan, FfiScanAccept, FfiScanAcceptRequest, FfiScanPreview, FfiScanPreviewRequest,
};
use crate::memory_store::MemoryClientStore;
use crate::scan::{scan_accept, scan_accept_prepare, scan_preview};
use crate::store::ClientStore;
use crate::types::ScanAcceptRequest;

/// Binding entrypoint for camera scan previews.
pub fn grain_scan_preview(request: FfiScanPreviewRequest) -> FfiScanPreview {
    FfiScanPreview::from(scan_preview(
        &request.qr_string,
        request.trust_pub_b64.as_deref(),
    ))
}

/// Binding entrypoint for pure scan-accept preparation.
pub fn grain_scan_accept_prepare(request: FfiScanAcceptRequest) -> FfiScanAccept {
    let request = ScanAcceptRequest::from(request);
    FfiScanAccept::from(scan_accept_prepare(
        &request.qr_string,
        Some(&request.trust_pub_b64),
    ))
}

/// Reference in-memory store object for generated binding conformance tests.
///
/// Platform SDKs should provide durable storage adapters around the same
/// workflow contract. This object exists so generated bindings can prove the
/// Rust-owned `scan_accept` behavior without depending on Keychain, Keystore,
/// SQLite, IndexedDB, or other device APIs.
pub struct GrainClientMemoryStore {
    store: Mutex<MemoryClientStore>,
}

impl GrainClientMemoryStore {
    pub fn new() -> Self {
        Self {
            store: Mutex::new(MemoryClientStore::new()),
        }
    }

    pub fn scan_accept(&self, request: FfiScanAcceptRequest) -> FfiScanAccept {
        let request = ScanAcceptRequest::from(request);
        let mut store = self.store.lock().expect("memory store lock poisoned");
        FfiScanAccept::from(scan_accept(
            &mut *store,
            &request.qr_string,
            Some(&request.trust_pub_b64),
        ))
    }

    pub fn list_accepted_scans(&self) -> Vec<FfiAcceptedScan> {
        let store = self.store.lock().expect("memory store lock poisoned");
        store
            .list_accepted_scans()
            .into_iter()
            .map(FfiAcceptedScan::from)
            .collect()
    }
}
