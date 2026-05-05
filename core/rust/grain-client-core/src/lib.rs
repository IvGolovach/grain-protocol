//! Workflow-shaped client SDK core for generated platform bindings.

pub mod diag;
mod ffi_types;
mod memory_store;
pub mod platform;
mod scan;
mod store;
mod trust;
mod types;

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
