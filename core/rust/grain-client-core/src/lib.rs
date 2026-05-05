//! Workflow-shaped client SDK core for generated platform bindings.

mod binding_api;
pub mod diag;
mod ffi_types;
mod memory_store;
pub mod platform;
mod scan;
mod store;
mod trust;
mod types;

pub use binding_api::{grain_scan_accept_prepare, grain_scan_preview, GrainClientMemoryStore};
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

uniffi::include_scaffolding!("grain_client_core");
