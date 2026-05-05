use std::sync::Mutex;

use crate::ffi_types::{
    FfiAcceptedScan, FfiClientLifecycle, FfiDeviceResult, FfiIdentityResult,
    FfiPairingEnvelopeRequest, FfiPairingResult, FfiScanAccept, FfiScanAcceptRequest,
    FfiScanPreview, FfiScanPreviewRequest, FfiSyncBundleRequest, FfiSyncResult,
};
use crate::identity::client_lifecycle;
use crate::memory_store::MemoryClientStore;
use crate::pairing::pairing_preview_envelope;
use crate::scan::{scan_accept, scan_accept_prepare, scan_preview};
use crate::store::ClientStore;
use crate::types::ScanAcceptRequest;

use crate::{
    device::{device_add_key, device_revoke_key, device_set_active},
    identity::{identity_create_root, identity_export_bundle, identity_import_bundle},
    pairing::{pairing_accept_envelope, pairing_create_envelope},
    sync::{sync_export_bundle, sync_import_bundle},
};

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

/// Binding entrypoint for pure pairing preview. This never mutates client
/// storage and can be called before an app asks the user to accept pairing.
pub fn grain_pairing_preview_envelope(request: FfiPairingEnvelopeRequest) -> FfiPairingResult {
    FfiPairingResult::from(pairing_preview_envelope(&request.envelope_b64))
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

    pub fn create_root_identity(&self, label: String) -> FfiIdentityResult {
        let mut store = self.store.lock().expect("memory store lock poisoned");
        FfiIdentityResult::from(identity_create_root(&mut *store, &label))
    }

    pub fn export_identity_bundle(&self) -> FfiIdentityResult {
        let store = self.store.lock().expect("memory store lock poisoned");
        FfiIdentityResult::from(identity_export_bundle(&*store))
    }

    pub fn import_identity_bundle(&self, bundle_b64: String) -> FfiIdentityResult {
        let mut store = self.store.lock().expect("memory store lock poisoned");
        FfiIdentityResult::from(identity_import_bundle(&mut *store, &bundle_b64))
    }

    pub fn add_device_key(&self, label: String) -> FfiDeviceResult {
        let mut store = self.store.lock().expect("memory store lock poisoned");
        FfiDeviceResult::from(device_add_key(&mut *store, &label))
    }

    pub fn revoke_device_key(&self, ak: String) -> FfiDeviceResult {
        let mut store = self.store.lock().expect("memory store lock poisoned");
        FfiDeviceResult::from(device_revoke_key(&mut *store, &ak))
    }

    pub fn set_active_device(&self, ak: String) -> FfiDeviceResult {
        let mut store = self.store.lock().expect("memory store lock poisoned");
        FfiDeviceResult::from(device_set_active(&mut *store, &ak))
    }

    pub fn client_lifecycle(&self) -> FfiClientLifecycle {
        let store = self.store.lock().expect("memory store lock poisoned");
        FfiClientLifecycle::from(client_lifecycle(&*store))
    }

    pub fn create_pairing_envelope(&self) -> FfiPairingResult {
        let store = self.store.lock().expect("memory store lock poisoned");
        FfiPairingResult::from(pairing_create_envelope(&*store))
    }

    pub fn accept_pairing_envelope(&self, request: FfiPairingEnvelopeRequest) -> FfiPairingResult {
        let mut store = self.store.lock().expect("memory store lock poisoned");
        FfiPairingResult::from(pairing_accept_envelope(&mut *store, &request.envelope_b64))
    }

    pub fn export_sync_bundle(&self) -> FfiSyncResult {
        let store = self.store.lock().expect("memory store lock poisoned");
        FfiSyncResult::from(sync_export_bundle(&*store))
    }

    pub fn import_sync_bundle(&self, request: FfiSyncBundleRequest) -> FfiSyncResult {
        let mut store = self.store.lock().expect("memory store lock poisoned");
        FfiSyncResult::from(sync_import_bundle(&mut *store, &request.bundle_b64))
    }
}
