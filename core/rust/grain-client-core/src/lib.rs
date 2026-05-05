//! Workflow-shaped client SDK core for generated platform bindings.

#[cfg(feature = "bindings")]
mod binding_api;
pub mod diag;
#[cfg(feature = "bindings")]
mod ffi_types;
mod memory_store;
pub mod platform;
mod scan;
mod store;
mod trust;
mod types;

#[cfg(feature = "bindings")]
pub use binding_api::{grain_scan_accept_prepare, grain_scan_preview, GrainClientMemoryStore};
#[cfg(feature = "bindings")]
pub use ffi_types::{
    FfiAcceptedScan, FfiScanAccept, FfiScanAcceptRequest, FfiScanPreview, FfiScanPreviewRequest,
    FfiStorePutResult,
};
pub use memory_store::MemoryClientStore;
pub use scan::{scan_accept, scan_accept_prepare, scan_preview};
pub use store::{ClientStore, StorePutResult};
pub use types::{
    AcceptedScan, AcceptedScanRecord, ScanAccept, ScanAcceptRequest, ScanAcceptStatus, ScanPreview,
    ScanPreviewStatus,
};

#[cfg(feature = "bindings")]
uniffi::include_scaffolding!("grain_client_core");
