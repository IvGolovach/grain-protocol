use grain_client_core::{scan_accept, ClientStore, MemoryClientStore, ScanAcceptStatus};
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
fn scan_accept_persists_valid_trusted_scan() {
    let mut store = MemoryClientStore::new();
    let accepted = scan_accept(&mut store, &qr_string(), Some(&trusted_pub_b64()));

    assert_eq!(accepted.status, ScanAcceptStatus::Accepted);
    assert!(accepted.diag.is_empty());

    let accepted = accepted
        .accepted
        .expect("accepted scan must include record");
    let stored = store.list_accepted_scans();
    assert_eq!(stored.len(), 1);
    assert_eq!(stored[0].scan_id, accepted.scan_id);
    assert_eq!(stored[0].cose_b64, accepted.cose_b64);
    assert_eq!(stored[0].trust_pub_b64, accepted.trust_pub_b64);
}

#[test]
fn scan_accept_rejects_without_writing() {
    let mut store = MemoryClientStore::new();
    let rejected = scan_accept(&mut store, "GR1:0?", Some(&trusted_pub_b64()));

    assert_eq!(rejected.status, ScanAcceptStatus::Rejected);
    assert_eq!(rejected.diag, vec!["GRAIN_ERR_SCHEMA"]);
    assert!(rejected.accepted.is_none());
    assert!(store.list_accepted_scans().is_empty());
}

#[test]
fn scan_accept_duplicate_is_idempotent() {
    let mut store = MemoryClientStore::new();
    let qr_string = qr_string();
    let trusted_pub_b64 = trusted_pub_b64();

    let first = scan_accept(&mut store, &qr_string, Some(&trusted_pub_b64));
    let second = scan_accept(&mut store, &qr_string, Some(&trusted_pub_b64));

    assert_eq!(first.status, ScanAcceptStatus::Accepted);
    assert_eq!(second.status, ScanAcceptStatus::AlreadyAccepted);
    assert_eq!(first.accepted, second.accepted);
    assert_eq!(store.list_accepted_scans().len(), 1);
}

#[test]
fn scan_accept_rejects_empty_trust_without_writing() {
    let mut store = MemoryClientStore::new();
    let rejected = scan_accept(&mut store, &qr_string(), Some(""));

    assert_eq!(rejected.status, ScanAcceptStatus::Rejected);
    assert_eq!(
        rejected.diag,
        vec!["SDK_ERR_TRANSPORT_VERIFY_TRUST_INVALID"]
    );
    assert!(rejected.accepted.is_none());
    assert!(store.list_accepted_scans().is_empty());
}
