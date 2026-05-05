use grain_client_core::platform::storage::{list_accepted_scans, put_accepted_scan_atomically};
use grain_client_core::{AcceptedScanRecord, ClientStore, MemoryClientStore, StorePutResult};

fn record(scan_id: &str) -> AcceptedScanRecord {
    AcceptedScanRecord {
        scan_id: scan_id.to_string(),
        cose_b64: format!("cose-for-{scan_id}"),
        trust_pub_b64: "trust-anchor".to_string(),
    }
}

#[test]
fn storage_contract_lists_records_in_deterministic_scan_id_order() {
    let mut store = MemoryClientStore::new();
    let later = record("scan-sha256:bbb");
    let earlier = record("scan-sha256:aaa");

    store
        .atomic(|tx| {
            tx.put_accepted_scan(later)?;
            tx.put_accepted_scan(earlier)?;
            Ok(())
        })
        .expect("atomic put must succeed");

    let scan_ids = list_accepted_scans(&store)
        .into_iter()
        .map(|record| record.scan_id)
        .collect::<Vec<_>>();
    assert_eq!(scan_ids, vec!["scan-sha256:aaa", "scan-sha256:bbb"]);
}

#[test]
fn storage_contract_reput_is_idempotent() {
    let mut store = MemoryClientStore::new();
    let record = record("scan-sha256:aaa");

    let first = put_accepted_scan_atomically(&mut store, record.clone());
    let second = put_accepted_scan_atomically(&mut store, record.clone());

    assert_eq!(first, Ok(StorePutResult::Inserted));
    assert_eq!(second, Ok(StorePutResult::AlreadyExists));
    assert_eq!(list_accepted_scans(&store), vec![record]);
}

#[test]
fn storage_contract_rolls_back_at_repository_boundary() {
    let mut store = MemoryClientStore::new();
    let record = record("scan-sha256:aaa");

    let err = store
        .atomic(|tx| {
            tx.put_accepted_scan(record)?;
            Err::<(), _>("SDK_ERR_STORE_INJECTED_FAILURE".to_string())
        })
        .expect_err("atomic error must roll back");

    assert_eq!(err, "SDK_ERR_STORE_INJECTED_FAILURE");
    assert!(list_accepted_scans(&store).is_empty());
}
