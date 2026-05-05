use grain_client_core::platform::{scan_accept_with_trust_provider, StaticTrustProvider};
use grain_client_core::{
    ClientStore, FfiScanAccept, FfiScanAcceptRequest, MemoryClientStore, ScanAcceptRequest,
    ScanAcceptStatus,
};
use serde::Deserialize;
use std::path::{Path, PathBuf};

#[derive(Deserialize)]
struct VectorFile {
    input: serde_json::Value,
}

fn fixture_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../../../conformance/vectors")
}

fn vector(relative: &str) -> VectorFile {
    let text =
        std::fs::read_to_string(fixture_root().join(relative)).expect("fixture must be readable");
    serde_json::from_str(&text).expect("fixture must be valid JSON")
}

fn qr_string() -> String {
    vector("qr/POS-QR-001.json")
        .input
        .get("qr_string")
        .and_then(serde_json::Value::as_str)
        .expect("POS-QR-001 must carry input.qr_string")
        .to_string()
}

fn trusted_pub_b64() -> String {
    vector("cose/POS-COSE-001.json")
        .input
        .get("pub_b64")
        .and_then(serde_json::Value::as_str)
        .expect("POS-COSE-001 must carry input.pub_b64")
        .to_string()
}

#[test]
fn platform_scan_accept_resolves_trust_and_persists_record() {
    let mut store = MemoryClientStore::new();
    let provider = StaticTrustProvider::new().with_anchor("primary", trusted_pub_b64());

    let accepted =
        scan_accept_with_trust_provider(&mut store, &qr_string(), Some("primary"), &provider);

    assert_eq!(accepted.status, ScanAcceptStatus::Accepted);
    assert!(accepted.diag.is_empty());
    assert_eq!(store.list_accepted_scans().len(), 1);

    let ffi = FfiScanAccept::from(accepted);
    assert_eq!(ffi.status, "Accepted");
    assert!(ffi.scan_id.is_some());
    assert!(ffi.cose_b64.is_some());
    assert!(ffi.trust_pub_b64.is_some());
}

#[test]
fn platform_scan_accept_rejects_without_anchor_and_does_not_write() {
    let mut store = MemoryClientStore::new();
    let provider = StaticTrustProvider::new().with_anchor("primary", trusted_pub_b64());

    let rejected = scan_accept_with_trust_provider(&mut store, &qr_string(), None, &provider);

    assert_eq!(rejected.status, ScanAcceptStatus::Rejected);
    assert_eq!(rejected.diag, vec!["SDK_ERR_TRUST_ANCHOR_REQUIRED"]);
    assert!(rejected.accepted.is_none());
    assert!(store.list_accepted_scans().is_empty());
}

#[test]
fn platform_scan_accept_rejects_malformed_anchor_and_does_not_write() {
    let mut store = MemoryClientStore::new();
    let provider = StaticTrustProvider::new().with_anchor("primary", "not base64");

    let rejected =
        scan_accept_with_trust_provider(&mut store, &qr_string(), Some("primary"), &provider);

    assert_eq!(rejected.status, ScanAcceptStatus::Rejected);
    assert_eq!(
        rejected.diag,
        vec!["SDK_ERR_TRANSPORT_VERIFY_TRUST_INVALID"]
    );
    assert!(rejected.accepted.is_none());
    assert!(store.list_accepted_scans().is_empty());
}

#[test]
fn platform_scan_accept_duplicate_is_idempotent() {
    let mut store = MemoryClientStore::new();
    let provider = StaticTrustProvider::new().with_anchor("primary", trusted_pub_b64());
    let qr_string = qr_string();

    let first = scan_accept_with_trust_provider(&mut store, &qr_string, Some("primary"), &provider);
    let second =
        scan_accept_with_trust_provider(&mut store, &qr_string, Some("primary"), &provider);

    assert_eq!(first.status, ScanAcceptStatus::Accepted);
    assert_eq!(second.status, ScanAcceptStatus::AlreadyAccepted);
    assert_eq!(store.list_accepted_scans().len(), 1);
}

#[test]
fn ffi_scan_accept_request_round_trips_to_core_request() {
    let ffi = FfiScanAcceptRequest {
        qr_string: "GR1:placeholder".to_string(),
        trust_pub_b64: "trust".to_string(),
    };

    let core: ScanAcceptRequest = ffi.clone().into();
    let round_trip = FfiScanAcceptRequest::from(core);

    assert_eq!(round_trip, ffi);
}
