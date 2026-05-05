//! Workflow-shaped client SDK core for generated platform bindings.

use base64::engine::general_purpose::STANDARD;
use base64::Engine;
use grain_core::cose::verify_cose_sign1;
use grain_core::qr::decode_gr1_to_cose;

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
    fn verified(cose: &[u8]) -> Self {
        Self {
            status: ScanPreviewStatus::Verified,
            diag: Vec::new(),
            cose_b64: Some(STANDARD.encode(cose)),
        }
    }

    fn untrusted(cose: &[u8]) -> Self {
        Self {
            status: ScanPreviewStatus::Untrusted,
            diag: Vec::new(),
            cose_b64: Some(STANDARD.encode(cose)),
        }
    }

    fn rejected(diag: impl Into<String>, cose_b64: Option<String>) -> Self {
        Self {
            status: ScanPreviewStatus::Rejected,
            diag: vec![diag.into()],
            cose_b64,
        }
    }
}

/// Decode a GR1 scan and optionally verify it against explicit trust material.
///
/// This is the first portable-client workflow surface. It deliberately keeps
/// decode-only preview (`Untrusted`) separate from verified preview
/// (`Verified`), matching the existing SDK invariant that verification must
/// require explicit trust.
pub fn scan_preview(qr_string: &str, trust_pub_b64: Option<&str>) -> ScanPreview {
    let cose = match decode_gr1_to_cose(qr_string) {
        Ok(cose) => cose,
        Err(err) => return ScanPreview::rejected(err.diag().code(), None),
    };

    let Some(trust_pub_b64) = trust_pub_b64 else {
        return ScanPreview::untrusted(&cose);
    };

    let trusted_pub = match STANDARD.decode(trust_pub_b64) {
        Ok(bytes) => bytes,
        Err(_) => {
            return ScanPreview::rejected(
                "SDK_ERR_TRANSPORT_VERIFY_TRUST_INVALID",
                Some(STANDARD.encode(&cose)),
            )
        }
    };

    match verify_cose_sign1(&cose, &trusted_pub, &[]) {
        Ok(()) => ScanPreview::verified(&cose),
        Err(err) => ScanPreview::rejected(err.diag().code(), Some(STANDARD.encode(&cose))),
    }
}
