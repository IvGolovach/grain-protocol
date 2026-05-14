#[path = "support/signed_qr.rs"]
mod signed_qr;

use std::fmt::Write;

use base64::engine::general_purpose::STANDARD;
use base64::Engine;
use grain_client_core::{scan_accept_prepare, ScanAcceptStatus};
use serde::Deserialize;
use sha2::{Digest, Sha256};

#[derive(Deserialize)]
struct VectorFile {
    input: serde_json::Value,
}

fn vector(path: &str) -> VectorFile {
    let text = std::fs::read_to_string(path).expect("fixture must be readable");
    serde_json::from_str(&text).expect("fixture must be valid JSON")
}

fn qr_string() -> String {
    vector("../../../conformance/vectors/qr/POS-QR-001.json")
        .input
        .get("qr_string")
        .and_then(serde_json::Value::as_str)
        .expect("POS-QR-001 must carry input.qr_string")
        .to_string()
}

fn trusted_pub_b64() -> String {
    vector("../../../conformance/vectors/cose/POS-COSE-001.json")
        .input
        .get("pub_b64")
        .and_then(serde_json::Value::as_str)
        .expect("POS-COSE-001 must carry input.pub_b64")
        .to_string()
}

fn expected_scan_id(cose_b64: &str) -> String {
    let cose = STANDARD
        .decode(cose_b64)
        .expect("accepted record must carry standard base64 COSE");
    let digest = Sha256::digest(cose);
    let mut scan_id = String::with_capacity("scan-sha256:".len() + 64);
    scan_id.push_str("scan-sha256:");
    for byte in digest {
        write!(&mut scan_id, "{byte:02x}").expect("writing to string cannot fail");
    }
    scan_id
}

#[test]
fn scan_accept_prepare_accepts_valid_trusted_qr() {
    let trusted_pub_b64 = trusted_pub_b64();
    let prepared = scan_accept_prepare(&qr_string(), Some(&trusted_pub_b64));

    assert_eq!(prepared.status, ScanAcceptStatus::Accepted);
    assert!(prepared.diag.is_empty());

    let accepted = prepared
        .accepted
        .expect("accepted scan must carry prepared record");
    assert_eq!(accepted.trust_pub_b64, trusted_pub_b64);
    assert_eq!(accepted.scan_id, expected_scan_id(&accepted.cose_b64));
    assert!(accepted.scan_id.starts_with("scan-sha256:"));
    assert_eq!(accepted.scan_id.len(), "scan-sha256:".len() + 64);
}

#[test]
fn scan_accept_prepare_is_deterministic_for_same_scan_and_trust() {
    let qr_string = qr_string();
    let trusted_pub_b64 = trusted_pub_b64();

    let first = scan_accept_prepare(&qr_string, Some(&trusted_pub_b64));
    let second = scan_accept_prepare(&qr_string, Some(&trusted_pub_b64));

    assert_eq!(first.status, ScanAcceptStatus::Accepted);
    assert_eq!(first, second);
}

#[test]
fn scan_accept_prepare_requires_explicit_trust() {
    let prepared = scan_accept_prepare(&qr_string(), None);

    assert_eq!(prepared.status, ScanAcceptStatus::Rejected);
    assert_eq!(prepared.diag, vec!["SDK_ERR_SCAN_ACCEPT_TRUST_REQUIRED"]);
    assert!(prepared.accepted.is_none());
}

#[test]
fn scan_accept_prepare_rejects_malformed_qr_without_record() {
    let prepared = scan_accept_prepare("GR1:0?", Some(&trusted_pub_b64()));

    assert_eq!(prepared.status, ScanAcceptStatus::Rejected);
    assert_eq!(prepared.diag, vec!["GRAIN_ERR_SCHEMA"]);
    assert!(prepared.accepted.is_none());
}

#[test]
fn scan_accept_prepare_rejects_malformed_trust_without_record() {
    let prepared = scan_accept_prepare(&qr_string(), Some("not standard base64"));

    assert_eq!(prepared.status, ScanAcceptStatus::Rejected);
    assert_eq!(
        prepared.diag,
        vec!["SDK_ERR_TRANSPORT_VERIFY_TRUST_INVALID"]
    );
    assert!(prepared.accepted.is_none());
}

#[test]
fn scan_accept_prepare_rejects_empty_trust_without_record() {
    let prepared = scan_accept_prepare(&qr_string(), Some(""));

    assert_eq!(prepared.status, ScanAcceptStatus::Rejected);
    assert_eq!(
        prepared.diag,
        vec!["SDK_ERR_TRANSPORT_VERIFY_TRUST_INVALID"]
    );
    assert!(prepared.accepted.is_none());
}

#[test]
fn scan_accept_prepare_rejects_wrong_trust_key_without_record() {
    let wrong_pub = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    let prepared = scan_accept_prepare(&qr_string(), Some(wrong_pub));

    assert_eq!(prepared.status, ScanAcceptStatus::Rejected);
    assert_eq!(prepared.diag, vec!["GRAIN_ERR_COSE_PROFILE"]);
    assert!(prepared.accepted.is_none());
}

#[test]
fn scan_accept_prepare_rejects_signed_payload_that_is_not_serving_offer_dag_cbor() {
    let signed = signed_qr::signed_qr_for_payload(b"not dag-cbor serving offer");
    let prepared = scan_accept_prepare(&signed.qr_string, Some(&signed.trust_pub_b64));

    assert_eq!(prepared.status, ScanAcceptStatus::Rejected);
    assert_eq!(prepared.diag, vec!["GRAIN_ERR_NONCANONICAL"]);
    assert!(prepared.accepted.is_none());
}
