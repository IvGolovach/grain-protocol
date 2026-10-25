use grain_client_core::{
    diag::SDK_ERR_TRANSPORT_VERIFY_TRUST_INVALID, grain_scan_accept_prepare, grain_scan_preview,
    FfiScanAcceptRequest, FfiScanPreviewRequest, GrainClientMemoryStore,
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
fn binding_scan_preview_returns_binding_safe_dto() {
    let preview = grain_scan_preview(FfiScanPreviewRequest {
        qr_string: qr_string(),
        trust_pub_b64: Some(trusted_pub_b64()),
    });

    assert_eq!(preview.status, "Verified");
    assert!(preview.diag.is_empty());
    assert!(preview.cose_b64.is_some());
}

#[test]
fn binding_scan_accept_prepare_returns_binding_safe_dto() {
    let accepted = grain_scan_accept_prepare(FfiScanAcceptRequest {
        qr_string: qr_string(),
        trust_pub_b64: trusted_pub_b64(),
    });

    assert_eq!(accepted.status, "Accepted");
    assert!(accepted.diag.is_empty());
    assert!(accepted.scan_id.is_some());
    assert!(accepted.cose_b64.is_some());
    assert!(accepted.trust_pub_b64.is_some());
}

#[test]
fn binding_scan_accept_prepare_rejects_with_flat_empty_record_fields() {
    let rejected = grain_scan_accept_prepare(FfiScanAcceptRequest {
        qr_string: qr_string(),
        trust_pub_b64: "not standard base64".to_string(),
    });

    assert_eq!(rejected.status, "Rejected");
    assert_eq!(rejected.diag, vec![SDK_ERR_TRANSPORT_VERIFY_TRUST_INVALID]);
    assert!(rejected.scan_id.is_none());
    assert!(rejected.cose_b64.is_none());
    assert!(rejected.trust_pub_b64.is_none());
}

#[test]
fn binding_memory_store_scan_accept_is_idempotent_and_listable() {
    let store = GrainClientMemoryStore::new();
    let request = FfiScanAcceptRequest {
        qr_string: qr_string(),
        trust_pub_b64: trusted_pub_b64(),
    };

    let first = store.scan_accept(request.clone());
    let second = store.scan_accept(request);
    let records = store.list_accepted_scans();

    assert_eq!(first.status, "Accepted");
    assert_eq!(second.status, "AlreadyAccepted");
    assert_eq!(records.len(), 1);
    assert_eq!(records[0].scan_id, first.scan_id.expect("scan id"));
}

#[test]
fn binding_old_identity_import_round_trips_snapshot_with_scans_and_revocations() {
    for backup_before_grant in [true, false] {
        let store = GrainClientMemoryStore::new();
        assert_eq!(store.create_root_identity("root".into()).status, "Created");
        let initial = store.export_identity_bundle().bundle_b64.unwrap();
        let device = store.add_device_key("device".into()).device_ak.unwrap();
        assert_eq!(store.set_active_device(device.clone()).status, "Active");
        let old = if backup_before_grant {
            initial
        } else {
            store.export_identity_bundle().bundle_b64.unwrap()
        };
        assert_eq!(store.revoke_device_key(device.clone()).status, "Revoked");
        assert_eq!(
            store
                .scan_accept(FfiScanAcceptRequest {
                    qr_string: qr_string(),
                    trust_pub_b64: trusted_pub_b64(),
                })
                .status,
            "Accepted"
        );
        assert_eq!(store.import_identity_bundle(old).status, "Imported");
        let snapshot = store.export_store_snapshot().snapshot_b64.unwrap();
        let restarted = GrainClientMemoryStore::new();
        assert_eq!(
            restarted.restore_store_snapshot(snapshot).status,
            "Restored"
        );
        let state = restarted.client_lifecycle();
        assert_eq!(state.device_count, 2);
        assert_eq!(state.revoked_count, 1);
        assert_eq!(state.lifecycle_event_count, 2);
        assert_eq!(state.accepted_record_count, 1);
        assert_eq!(restarted.set_active_device(device).status, "Rejected");
        assert_eq!(restarted.add_device_key("next".into()).status, "Added");
        assert_eq!(restarted.client_lifecycle().lifecycle_event_count, 3);
    }
}
