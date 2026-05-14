use base64::engine::general_purpose::STANDARD;
use base64::Engine;
use grain_core::qr::decode_gr1_to_cose;

use crate::accepted_scan::prepare_accepted_scan;
use crate::diag::SDK_ERR_SCAN_ACCEPT_TRUST_REQUIRED;
use crate::store::{ClientStore, StorePutResult};
use crate::types::{AcceptedScanRecord, ScanAccept, ScanPreview};

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

    match prepare_accepted_scan(&cose, trust_pub_b64) {
        Ok(_) => ScanPreview::verified(&cose),
        Err(diag) => return ScanPreview::rejected(diag, Some(STANDARD.encode(&cose))),
    }
}

/// Prepare a verified scan record for later atomic persistence.
///
/// This workflow is pure: it never writes storage. It requires explicit trust,
/// preserves core diagnostics for QR/COSE failures, and derives a deterministic
/// scan ID from the verified COSE bytes.
pub fn scan_accept_prepare(qr_string: &str, trust_pub_b64: Option<&str>) -> ScanAccept {
    let cose = match decode_gr1_to_cose(qr_string) {
        Ok(cose) => cose,
        Err(err) => return ScanAccept::rejected(err.diag().code()),
    };

    let Some(trust_pub_b64) = trust_pub_b64 else {
        return ScanAccept::rejected(SDK_ERR_SCAN_ACCEPT_TRUST_REQUIRED);
    };

    match prepare_accepted_scan(&cose, trust_pub_b64) {
        Ok(accepted) => ScanAccept::accepted(accepted),
        Err(diag) => ScanAccept::rejected(diag),
    }
}

/// Verify and atomically persist an accepted scan record.
///
/// Rejected scans never enter the store transaction. Duplicate verified scans
/// are idempotent and report `AlreadyAccepted` without adding another record.
pub fn scan_accept<S: ClientStore>(
    store: &mut S,
    qr_string: &str,
    trust_pub_b64: Option<&str>,
) -> ScanAccept {
    let prepared = scan_accept_prepare(qr_string, trust_pub_b64);
    let Some(accepted) = prepared.accepted.clone() else {
        return prepared;
    };

    let record = AcceptedScanRecord::from(accepted.clone());
    match store.atomic(|tx| tx.put_accepted_scan(record.clone())) {
        Ok(StorePutResult::Inserted) => prepared,
        Ok(StorePutResult::AlreadyExists) => ScanAccept::already_accepted(accepted),
        Err(diag) => ScanAccept::rejected(diag),
    }
}
