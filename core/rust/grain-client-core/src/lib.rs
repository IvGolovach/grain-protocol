//! Workflow-shaped client SDK core for generated platform bindings.

pub mod diag;
mod memory_store;
mod scan;
mod store;
mod trust;
mod types;

pub use memory_store::MemoryClientStore;
pub use scan::{scan_accept, scan_accept_prepare, scan_preview};
pub use store::{ClientStore, StorePutResult};
pub use types::{
    AcceptedScan, AcceptedScanRecord, ScanAccept, ScanAcceptRequest, ScanAcceptStatus, ScanPreview,
    ScanPreviewStatus,
};
