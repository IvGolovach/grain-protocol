use base64::engine::general_purpose::STANDARD;
use base64::Engine;

/// Preview status for a scanned transport payload.
///
/// `Untrusted` means the transport decoded successfully, but the caller did
/// not provide trust material. Verification failures are explicit rejections.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ScanPreviewStatus {
    Verified,
    Untrusted,
    Rejected,
}

/// Pure scan preview output for client SDKs.
///
/// This type is intentionally FFI-friendly: platform bindings can expose the
/// status, deterministic diag strings, and optional COSE bytes without exposing
/// raw protocol runner operations to app developers.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ScanPreview {
    pub status: ScanPreviewStatus,
    pub diag: Vec<String>,
    pub cose_b64: Option<String>,
}

impl ScanPreview {
    pub(crate) fn verified(cose: &[u8]) -> Self {
        Self {
            status: ScanPreviewStatus::Verified,
            diag: Vec::new(),
            cose_b64: Some(STANDARD.encode(cose)),
        }
    }

    pub(crate) fn untrusted(cose: &[u8]) -> Self {
        Self {
            status: ScanPreviewStatus::Untrusted,
            diag: Vec::new(),
            cose_b64: Some(STANDARD.encode(cose)),
        }
    }

    pub(crate) fn rejected(diag: impl Into<String>, cose_b64: Option<String>) -> Self {
        Self {
            status: ScanPreviewStatus::Rejected,
            diag: vec![diag.into()],
            cose_b64,
        }
    }
}

/// Request DTO for generated SDK scan-accept workflows.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ScanAcceptRequest {
    pub qr_string: String,
    pub trust_pub_b64: String,
}

/// Accept status for a scanned transport payload.
///
/// `Accepted` means the scan has been verified and normalized into a
/// persistence-ready record. Store mutation starts in the `scan_accept`
/// workflow; `scan_accept_prepare` itself remains pure.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ScanAcceptStatus {
    /// Verified and normalized into a persistence-ready record.
    Accepted,
    /// Rejected before any persistence-ready record exists.
    Rejected,
}

/// Verified scan record prepared for later atomic persistence.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AcceptedScan {
    pub scan_id: String,
    pub cose_b64: String,
    pub trust_pub_b64: String,
}

/// Pure scan-accept preparation output.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ScanAccept {
    pub status: ScanAcceptStatus,
    pub diag: Vec<String>,
    pub accepted: Option<AcceptedScan>,
}

impl ScanAccept {
    pub(crate) fn accepted(accepted: AcceptedScan) -> Self {
        Self {
            status: ScanAcceptStatus::Accepted,
            diag: Vec::new(),
            accepted: Some(accepted),
        }
    }

    pub(crate) fn rejected(diag: impl Into<String>) -> Self {
        Self {
            status: ScanAcceptStatus::Rejected,
            diag: vec![diag.into()],
            accepted: None,
        }
    }
}
