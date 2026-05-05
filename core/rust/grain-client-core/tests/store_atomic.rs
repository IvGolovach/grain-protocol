use grain_client_core::{
    scan_accept_prepare, AcceptedScanRecord, ClientStore, MemoryClientStore, StorePutResult,
};
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

fn accepted_record() -> AcceptedScanRecord {
    let prepared = scan_accept_prepare(&qr_string(), Some(&trusted_pub_b64()));
    prepared
        .accepted
        .expect("valid scan must prepare an accepted record")
        .into()
}

#[test]
fn memory_store_persists_atomic_mutation() {
    let mut store = MemoryClientStore::new();
    let record = accepted_record();

    let put = store.atomic(|tx| tx.put_accepted_scan(record.clone()));

    assert_eq!(put, Ok(StorePutResult::Inserted));
    assert_eq!(store.list_accepted_scans(), vec![record]);
}

#[test]
fn memory_store_rejects_mutation_outside_atomic() {
    let mut store = MemoryClientStore::new();
    let err = store
        .put_accepted_scan(accepted_record())
        .expect_err("mutation outside atomic must fail");

    assert_eq!(err, "SDK_ERR_STORE_MUTATION_OUTSIDE_ATOMIC");
    assert!(store.list_accepted_scans().is_empty());
}

#[test]
fn memory_store_rolls_back_failed_atomic_mutation() {
    let mut store = MemoryClientStore::new();
    let record = accepted_record();

    let err = store
        .atomic(|tx| {
            tx.put_accepted_scan(record)?;
            Err::<(), _>("SDK_ERR_STORE_INJECTED_FAILURE".to_string())
        })
        .expect_err("injected failure must roll back");

    assert_eq!(err, "SDK_ERR_STORE_INJECTED_FAILURE");
    assert!(store.list_accepted_scans().is_empty());
}

#[test]
fn memory_store_rejects_nested_atomic_mutation() {
    let mut store = MemoryClientStore::new();
    let err = store
        .atomic(|tx| tx.atomic(|_| Ok(())))
        .expect_err("nested atomic must fail");

    assert_eq!(err, "SDK_ERR_STORE_ATOMIC_NESTED");
    assert!(store.list_accepted_scans().is_empty());
}
