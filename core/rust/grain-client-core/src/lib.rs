//! Workflow-shaped client SDK core for generated platform bindings.

#[cfg(feature = "bindings")]
mod binding_api;
mod device;
pub mod diag;
#[cfg(feature = "bindings")]
mod ffi_types;
mod identity;
mod memory_store;
mod pairing;
pub mod platform;
mod scan;
mod store;
mod sync;
mod trust;
mod types;

#[cfg(feature = "bindings")]
pub use binding_api::{
    grain_pairing_preview_envelope, grain_scan_accept_prepare, grain_scan_preview,
    GrainClientMemoryStore,
};
pub use device::{device_add_key, device_revoke_key, device_set_active};
#[cfg(feature = "bindings")]
pub use ffi_types::{
    FfiAcceptedScan, FfiClientLifecycle, FfiDeviceResult, FfiIdentityResult,
    FfiPairingEnvelopeRequest, FfiPairingResult, FfiScanAccept, FfiScanAcceptRequest,
    FfiScanPreview, FfiScanPreviewRequest, FfiStorePutResult, FfiStoreSnapshotResult,
    FfiSyncBundleRequest, FfiSyncResult,
};
pub use identity::{
    client_lifecycle, identity_create_root, identity_export_bundle, identity_import_bundle,
};
pub use memory_store::MemoryClientStore;
pub use pairing::{pairing_accept_envelope, pairing_create_envelope, pairing_preview_envelope};
pub use scan::{scan_accept, scan_accept_prepare, scan_preview};
pub use store::{ClientStore, IdentityClientStore, StorePutResult};
pub use sync::{sync_export_bundle, sync_import_bundle};
pub use types::{
    AcceptedScan, AcceptedScanRecord, ClientLifecycle, ClientLifecycleStatus, DeviceKey,
    DeviceResult, DeviceStatus, IdentityBundleV1, IdentityResult, IdentityStatus,
    LifecycleEventRecord, PairingResult, PairingStatus, ScanAccept, ScanAcceptRequest,
    ScanAcceptStatus, ScanPreview, ScanPreviewStatus, StoreSnapshotResult, StoreSnapshotStatus,
    SyncResult, SyncStatus,
};

#[cfg(feature = "bindings")]
uniffi::include_scaffolding!("grain_client_core");
