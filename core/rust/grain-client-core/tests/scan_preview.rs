#[path = "support/signed_qr.rs"]
mod signed_qr;

use grain_client_core::{scan_preview, ScanPreviewStatus};
use serde::Deserialize;

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

#[test]
fn scan_preview_marks_valid_trusted_qr_as_verified() {
    let preview = scan_preview(&qr_string(), Some(&trusted_pub_b64()));

    assert_eq!(preview.status, ScanPreviewStatus::Verified);
    assert!(preview.diag.is_empty());
    assert!(preview.cose_b64.is_some());
}

#[test]
fn scan_preview_keeps_valid_qr_without_trust_as_untrusted_preview() {
    let preview = scan_preview(&qr_string(), None);

    assert_eq!(preview.status, ScanPreviewStatus::Untrusted);
    assert!(preview.diag.is_empty());
    assert!(preview.cose_b64.is_some());
}

#[test]
fn scan_preview_rejects_malformed_qr_without_throwing() {
    let preview = scan_preview("GR1:0?", Some(&trusted_pub_b64()));

    assert_eq!(preview.status, ScanPreviewStatus::Rejected);
    assert_eq!(preview.diag, vec!["GRAIN_ERR_SCHEMA"]);
    assert!(preview.cose_b64.is_none());
}

#[test]
fn scan_preview_rejects_valid_qr_with_wrong_trust_key() {
    let wrong_pub = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    let preview = scan_preview(&qr_string(), Some(wrong_pub));

    assert_eq!(preview.status, ScanPreviewStatus::Rejected);
    assert_eq!(preview.diag, vec!["GRAIN_ERR_COSE_PROFILE"]);
    assert!(preview.cose_b64.is_some());
}

#[test]
fn scan_preview_rejects_malformed_trust_before_verify() {
    let preview = scan_preview(&qr_string(), Some("not standard base64"));

    assert_eq!(preview.status, ScanPreviewStatus::Rejected);
    assert_eq!(preview.diag, vec!["SDK_ERR_TRANSPORT_VERIFY_TRUST_INVALID"]);
    assert!(preview.cose_b64.is_some());
}

#[test]
fn scan_preview_rejects_empty_trust_before_verify() {
    let preview = scan_preview(&qr_string(), Some(""));

    assert_eq!(preview.status, ScanPreviewStatus::Rejected);
    assert_eq!(preview.diag, vec!["SDK_ERR_TRANSPORT_VERIFY_TRUST_INVALID"]);
    assert!(preview.cose_b64.is_some());
}

#[test]
fn scan_preview_rejects_signed_payload_that_is_not_serving_offer_dag_cbor() {
    let signed = signed_qr::signed_qr_for_payload(b"not dag-cbor serving offer");
    let preview = scan_preview(&signed.qr_string, Some(&signed.trust_pub_b64));

    assert_eq!(preview.status, ScanPreviewStatus::Rejected);
    assert_eq!(preview.diag, vec!["GRAIN_ERR_NONCANONICAL"]);
    assert!(preview.cose_b64.is_some());
}
