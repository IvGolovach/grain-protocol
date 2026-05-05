use std::fmt::Write;

use base64::engine::general_purpose::STANDARD;
use base64::Engine;
use grain_core::cose::verify_cose_sign1;
use grain_core::qr::decode_gr1_to_cose;
use sha2::{Digest, Sha256};

use crate::diag::SDK_ERR_SCAN_ACCEPT_TRUST_REQUIRED;
use crate::trust::decode_trust_pub_b64;
use crate::types::{AcceptedScan, ScanAccept, ScanPreview};

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

    let trusted_pub = match decode_trust_pub_b64(trust_pub_b64) {
        Ok(bytes) => bytes,
        Err(diag) => return ScanPreview::rejected(diag, Some(STANDARD.encode(&cose))),
    };

    match verify_cose_sign1(&cose, &trusted_pub, &[]) {
        Ok(()) => ScanPreview::verified(&cose),
        Err(err) => ScanPreview::rejected(err.diag().code(), Some(STANDARD.encode(&cose))),
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

    let trusted_pub = match decode_trust_pub_b64(trust_pub_b64) {
        Ok(bytes) => bytes,
        Err(diag) => return ScanAccept::rejected(diag),
    };

    if let Err(err) = verify_cose_sign1(&cose, &trusted_pub, &[]) {
        return ScanAccept::rejected(err.diag().code());
    }

    ScanAccept::accepted(AcceptedScan {
        scan_id: scan_id_for_cose(&cose),
        cose_b64: STANDARD.encode(&cose),
        trust_pub_b64: trust_pub_b64.to_string(),
    })
}

fn scan_id_for_cose(cose: &[u8]) -> String {
    let digest = Sha256::digest(cose);
    let mut scan_id = String::with_capacity("scan-sha256:".len() + 64);
    scan_id.push_str("scan-sha256:");
    for byte in digest {
        write!(&mut scan_id, "{byte:02x}").expect("writing to string cannot fail");
    }
    scan_id
}
