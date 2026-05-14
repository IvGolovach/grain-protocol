use std::fmt::Write;

use base64::engine::general_purpose::STANDARD;
use base64::Engine;
use grain_core::cose::verify_cose_sign1_payload;
use grain_core::dagcbor::validate_serving_offer_payload;
use sha2::{Digest, Sha256};

use crate::trust::decode_trust_pub_b64;
use crate::types::{AcceptedScan, AcceptedScanRecord};

pub(crate) fn prepare_accepted_scan(
    cose: &[u8],
    trust_pub_b64: &str,
) -> Result<AcceptedScan, String> {
    let trusted_pub = decode_trust_pub_b64(trust_pub_b64).map_err(str::to_string)?;
    let verified = verify_cose_sign1_payload(cose, &trusted_pub, &[])
        .map_err(|err| err.diag().code().to_string())?;
    validate_serving_offer_payload(&verified.payload, &verified.kid)
        .map_err(|err| err.diag().code().to_string())?;

    Ok(AcceptedScan {
        scan_id: scan_id_for_cose(cose),
        cose_b64: STANDARD.encode(cose),
        trust_pub_b64: trust_pub_b64.to_string(),
    })
}

pub(crate) fn validate_accepted_scan_record(record: &AcceptedScanRecord) -> Result<(), String> {
    let cose = STANDARD
        .decode(&record.cose_b64)
        .map_err(|_| "GRAIN_ERR_SCHEMA".to_string())?;
    let expected = prepare_accepted_scan(&cose, &record.trust_pub_b64)?;
    if record.scan_id != expected.scan_id || record.cose_b64 != expected.cose_b64 {
        return Err("GRAIN_ERR_SCHEMA".to_string());
    }
    Ok(())
}

pub(crate) fn scan_id_for_cose(cose: &[u8]) -> String {
    let digest = Sha256::digest(cose);
    let mut scan_id = String::with_capacity("scan-sha256:".len() + 64);
    scan_id.push_str("scan-sha256:");
    for byte in digest {
        write!(&mut scan_id, "{byte:02x}").expect("writing to string cannot fail");
    }
    scan_id
}
