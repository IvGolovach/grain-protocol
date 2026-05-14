use base64::engine::general_purpose::STANDARD;
use base64::Engine;
use grain_client_core::platform::storage::{list_accepted_scans, put_accepted_scan_atomically};
use grain_client_core::{
    client_lifecycle, device_add_key, identity_create_root, scan_accept_prepare,
    AcceptedScanRecord, ClientStore, MemoryClientStore, StorePutResult, StoreSnapshotStatus,
};
use serde_json::Value;

fn record(scan_id: &str) -> AcceptedScanRecord {
    AcceptedScanRecord {
        scan_id: scan_id.to_string(),
        cose_b64: format!("cose-for-{scan_id}"),
        trust_pub_b64: "trust-anchor".to_string(),
    }
}

fn fixture_string(path: &str, key: &str) -> String {
    let text = std::fs::read_to_string(format!("../../../conformance/vectors/{path}"))
        .expect("fixture must be readable");
    let json: serde_json::Value = serde_json::from_str(&text).expect("fixture must parse");
    json["input"][key]
        .as_str()
        .expect("fixture value must be a string")
        .to_string()
}

fn accepted_record() -> AcceptedScanRecord {
    let prepared = scan_accept_prepare(
        &fixture_string("qr/POS-QR-001.json", "qr_string"),
        Some(&fixture_string("cose/POS-COSE-001.json", "pub_b64")),
    );
    prepared.accepted.expect("fixture scan must prepare").into()
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

#[test]
fn storage_snapshot_export_empty_store_is_explicitly_empty() {
    let store = MemoryClientStore::new();

    let snapshot = store.export_store_snapshot();

    assert_eq!(snapshot.status, StoreSnapshotStatus::Empty);
    assert!(snapshot.diag.is_empty());
    assert!(snapshot.snapshot_b64.is_none());
    assert_eq!(snapshot.accepted_record_count, 0);
    assert_eq!(snapshot.device_count, 0);
    assert_eq!(snapshot.lifecycle_event_count, 0);
}

#[test]
fn storage_snapshot_round_trips_identity_lifecycle_and_scans() {
    let mut source = MemoryClientStore::new();
    assert!(identity_create_root(&mut source, "phone").diag.is_empty());
    assert!(device_add_key(&mut source, "glasses").diag.is_empty());
    let accepted = accepted_record();
    assert_eq!(
        put_accepted_scan_atomically(&mut source, accepted.clone()),
        Ok(StorePutResult::Inserted)
    );

    let snapshot = source.export_store_snapshot();
    assert_eq!(snapshot.status, StoreSnapshotStatus::Exported);
    assert_eq!(snapshot.accepted_record_count, 1);
    assert_eq!(snapshot.device_count, 2);
    assert_eq!(snapshot.lifecycle_event_count, 1);
    let snapshot_b64 = snapshot.snapshot_b64.expect("snapshot payload");

    let mut target = MemoryClientStore::new();
    assert_eq!(
        put_accepted_scan_atomically(&mut target, record("scan-sha256:stale")),
        Ok(StorePutResult::Inserted)
    );
    let restored = target.restore_store_snapshot(&snapshot_b64);

    assert_eq!(restored.status, StoreSnapshotStatus::Restored);
    assert!(restored.diag.is_empty());
    assert_eq!(restored.accepted_record_count, 1);
    assert_eq!(restored.device_count, 2);
    assert_eq!(restored.lifecycle_event_count, 1);
    assert_eq!(list_accepted_scans(&target), vec![accepted]);
    let lifecycle = client_lifecycle(&target);
    assert_eq!(lifecycle.device_count, 2);
    assert_eq!(lifecycle.accepted_record_count, 1);
    assert_eq!(lifecycle.lifecycle_event_count, 1);
}

#[test]
fn storage_snapshot_rejects_invalid_payload_without_mutation() {
    let mut store = MemoryClientStore::new();
    let accepted = record("scan-sha256:aaa");
    assert_eq!(
        put_accepted_scan_atomically(&mut store, accepted.clone()),
        Ok(StorePutResult::Inserted)
    );

    let rejected = store.restore_store_snapshot("not base64");

    assert_eq!(rejected.status, StoreSnapshotStatus::Rejected);
    assert_eq!(list_accepted_scans(&store), vec![accepted]);
}

#[test]
fn storage_snapshot_rejects_unsupported_version_without_mutation() {
    let mut source = MemoryClientStore::new();
    assert!(identity_create_root(&mut source, "phone").diag.is_empty());
    let snapshot_b64 = source
        .export_store_snapshot()
        .snapshot_b64
        .expect("non-empty snapshot");
    let mut snapshot: serde_json::Value =
        serde_json::from_slice(&STANDARD.decode(snapshot_b64).expect("valid base64"))
            .expect("valid snapshot JSON");
    snapshot["snapshot_v"] = serde_json::json!(2);
    let unsupported = STANDARD.encode(serde_json::to_vec(&snapshot).expect("snapshot JSON bytes"));

    let mut target = MemoryClientStore::new();
    let accepted = record("scan-sha256:aaa");
    assert_eq!(
        put_accepted_scan_atomically(&mut target, accepted.clone()),
        Ok(StorePutResult::Inserted)
    );
    let rejected = target.restore_store_snapshot(&unsupported);

    assert_eq!(rejected.status, StoreSnapshotStatus::Rejected);
    assert_eq!(rejected.diag, vec!["SDK_ERR_STORE_SNAPSHOT_VERSION"]);
    assert_eq!(list_accepted_scans(&target), vec![accepted]);
}

#[test]
fn storage_snapshot_rejects_tampered_accepted_scan_without_mutation() {
    let mut source = MemoryClientStore::new();
    let accepted = accepted_record();
    assert_eq!(
        put_accepted_scan_atomically(&mut source, accepted),
        Ok(StorePutResult::Inserted)
    );
    let snapshot_b64 = source
        .export_store_snapshot()
        .snapshot_b64
        .expect("non-empty snapshot");
    let mut snapshot: Value =
        serde_json::from_slice(&STANDARD.decode(snapshot_b64).expect("valid base64"))
            .expect("valid snapshot JSON");
    snapshot["accepted_scans"][0]["scan_id"] = serde_json::json!("scan-sha256:not-the-cose");
    let tampered = STANDARD.encode(serde_json::to_vec(&snapshot).expect("snapshot JSON bytes"));

    let mut target = MemoryClientStore::new();
    let stale = record("scan-sha256:stale");
    assert_eq!(
        put_accepted_scan_atomically(&mut target, stale.clone()),
        Ok(StorePutResult::Inserted)
    );
    let rejected = target.restore_store_snapshot(&tampered);

    assert_eq!(rejected.status, StoreSnapshotStatus::Rejected);
    assert_eq!(rejected.diag, vec!["SDK_ERR_STORE_SNAPSHOT_INVALID"]);
    assert_eq!(list_accepted_scans(&target), vec![stale]);
}
