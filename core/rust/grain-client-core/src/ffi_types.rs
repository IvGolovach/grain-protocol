use crate::store::StorePutResult;
use crate::types::{
    AcceptedScan, AcceptedScanRecord, ScanAccept, ScanAcceptRequest, ScanAcceptStatus, ScanPreview,
    ScanPreviewStatus,
};

/// Binding-safe scan-preview request DTO.
///
/// `scan_preview` has no separate core request type today; generated bindings
/// pass these owned fields directly to the core function.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FfiScanPreviewRequest {
    pub qr_string: String,
    pub trust_pub_b64: Option<String>,
}

/// Binding-safe scan-preview result DTO.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FfiScanPreview {
    pub status: String,
    pub diag: Vec<String>,
    pub cose_b64: Option<String>,
}

impl From<ScanPreview> for FfiScanPreview {
    fn from(preview: ScanPreview) -> Self {
        Self {
            status: preview_status_string(preview.status),
            diag: preview.diag,
            cose_b64: preview.cose_b64,
        }
    }
}

/// Binding-safe scan-accept request DTO.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FfiScanAcceptRequest {
    pub qr_string: String,
    pub trust_pub_b64: String,
}

impl From<FfiScanAcceptRequest> for ScanAcceptRequest {
    fn from(request: FfiScanAcceptRequest) -> Self {
        Self {
            qr_string: request.qr_string,
            trust_pub_b64: request.trust_pub_b64,
        }
    }
}

impl From<ScanAcceptRequest> for FfiScanAcceptRequest {
    fn from(request: ScanAcceptRequest) -> Self {
        Self {
            qr_string: request.qr_string,
            trust_pub_b64: request.trust_pub_b64,
        }
    }
}

/// Binding-safe accepted scan DTO.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FfiAcceptedScan {
    pub scan_id: String,
    pub cose_b64: String,
    pub trust_pub_b64: String,
}

impl From<AcceptedScan> for FfiAcceptedScan {
    fn from(accepted: AcceptedScan) -> Self {
        Self {
            scan_id: accepted.scan_id,
            cose_b64: accepted.cose_b64,
            trust_pub_b64: accepted.trust_pub_b64,
        }
    }
}

impl From<AcceptedScanRecord> for FfiAcceptedScan {
    fn from(record: AcceptedScanRecord) -> Self {
        Self {
            scan_id: record.scan_id,
            cose_b64: record.cose_b64,
            trust_pub_b64: record.trust_pub_b64,
        }
    }
}

/// Binding-safe scan-accept result DTO.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FfiScanAccept {
    pub status: String,
    pub diag: Vec<String>,
    pub scan_id: Option<String>,
    pub cose_b64: Option<String>,
    pub trust_pub_b64: Option<String>,
}

impl From<ScanAccept> for FfiScanAccept {
    fn from(accepted: ScanAccept) -> Self {
        let (scan_id, cose_b64, trust_pub_b64) = accepted
            .accepted
            .map(|record| {
                (
                    Some(record.scan_id),
                    Some(record.cose_b64),
                    Some(record.trust_pub_b64),
                )
            })
            .unwrap_or((None, None, None));

        Self {
            status: accept_status_string(accepted.status),
            diag: accepted.diag,
            scan_id,
            cose_b64,
            trust_pub_b64,
        }
    }
}

/// Binding-safe store put result DTO.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FfiStorePutResult {
    pub status: String,
}

impl From<StorePutResult> for FfiStorePutResult {
    fn from(result: StorePutResult) -> Self {
        let status = match result {
            StorePutResult::Inserted => "Inserted",
            StorePutResult::AlreadyExists => "AlreadyExists",
        };
        Self {
            status: status.to_string(),
        }
    }
}

fn preview_status_string(status: ScanPreviewStatus) -> String {
    match status {
        ScanPreviewStatus::Verified => "Verified",
        ScanPreviewStatus::Untrusted => "Untrusted",
        ScanPreviewStatus::Rejected => "Rejected",
    }
    .to_string()
}

fn accept_status_string(status: ScanAcceptStatus) -> String {
    match status {
        ScanAcceptStatus::Accepted => "Accepted",
        ScanAcceptStatus::AlreadyAccepted => "AlreadyAccepted",
        ScanAcceptStatus::Rejected => "Rejected",
    }
    .to_string()
}
