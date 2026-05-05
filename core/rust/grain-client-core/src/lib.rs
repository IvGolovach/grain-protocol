//! Workflow-shaped client SDK core for generated platform bindings.

pub mod diag;
mod scan;
mod trust;
mod types;

pub use scan::{scan_accept_prepare, scan_preview};
pub use types::{
    AcceptedScan, ScanAccept, ScanAcceptRequest, ScanAcceptStatus, ScanPreview, ScanPreviewStatus,
};
