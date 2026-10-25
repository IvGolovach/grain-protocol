use base64::engine::general_purpose::STANDARD;
use base64::Engine;
use grain_client_core::{
    client_lifecycle, device_add_key, device_revoke_key, device_set_active, identity_create_root,
    identity_export_bundle, identity_import_bundle, ClientLifecycleStatus, DeviceStatus,
    IdentityClientStore, IdentityStatus, MemoryClientStore, StoreSnapshotStatus,
};
use serde_json::Value;

#[test]
fn create_root_and_device_lifecycle_are_atomic() {
    let mut store = MemoryClientStore::new();

    let root = identity_create_root(&mut store, "");
    assert_eq!(root.status, IdentityStatus::Created);
    assert!(root.diag.is_empty());
    assert_eq!(root.device_count, 1);

    let duplicate = identity_create_root(&mut store, "again");
    assert_eq!(duplicate.status, IdentityStatus::AlreadyExists);

    let added = device_add_key(&mut store, "");
    assert_eq!(added.status, DeviceStatus::Added);
    let device_ak = added.device_ak.clone().expect("device ak must be present");
    assert_eq!(added.device_count, 2);
    assert_eq!(added.lifecycle_event_count, 1);

    let active = device_set_active(&mut store, &device_ak);
    assert_eq!(active.status, DeviceStatus::Active);
    assert_eq!(active.active_ak.as_deref(), Some(device_ak.as_str()));

    let revoked = device_revoke_key(&mut store, &device_ak);
    assert_eq!(revoked.status, DeviceStatus::Revoked);
    assert_eq!(revoked.revoked_count, 1);
    assert_eq!(revoked.lifecycle_event_count, 2);
    assert_eq!(revoked.active_ak, revoked.root_kid);

    let lifecycle = client_lifecycle(&store);
    assert_eq!(lifecycle.status, ClientLifecycleStatus::Ready);
    assert_eq!(lifecycle.device_count, 2);
    assert_eq!(lifecycle.revoked_count, 1);
    assert_eq!(lifecycle.lifecycle_event_count, 2);

    let repeat_revoke = device_revoke_key(&mut store, &device_ak);
    assert_eq!(repeat_revoke.status, DeviceStatus::Revoked);
    assert_eq!(repeat_revoke.revoked_count, 1);
    assert_eq!(repeat_revoke.lifecycle_event_count, 2);
}

#[test]
fn identity_import_rejects_malformed_bundle_without_mutation() {
    let mut store = MemoryClientStore::new();
    let root = identity_create_root(&mut store, "root");
    assert_eq!(root.status, IdentityStatus::Created);
    let before = store.load_identity_bundle();

    let rejected = identity_import_bundle(&mut store, "!!!");
    assert_eq!(rejected.status, IdentityStatus::Rejected);
    assert_eq!(store.load_identity_bundle(), before);
}

#[test]
fn identity_bundle_export_import_round_trips_empty_labels() {
    let mut source = MemoryClientStore::new();
    assert_eq!(
        identity_create_root(&mut source, "").status,
        IdentityStatus::Created
    );
    assert_eq!(device_add_key(&mut source, "").status, DeviceStatus::Added);
    let exported = identity_export_bundle(&source);
    assert_eq!(exported.status, IdentityStatus::Exported);

    let mut target = MemoryClientStore::new();
    let imported = identity_import_bundle(
        &mut target,
        exported.bundle_b64.as_deref().expect("bundle present"),
    );
    assert_eq!(imported.status, IdentityStatus::Imported);
    assert_eq!(source.load_identity_bundle(), target.load_identity_bundle());
}

#[test]
fn identity_import_rejects_conflicting_root_without_mutation() {
    let mut source = MemoryClientStore::new();
    assert_eq!(
        identity_create_root(&mut source, "source").status,
        IdentityStatus::Created
    );
    let exported = identity_export_bundle(&source);
    assert_eq!(exported.status, IdentityStatus::Exported);

    let mut target = MemoryClientStore::new();
    assert_eq!(
        identity_create_root(&mut target, "target").status,
        IdentityStatus::Created
    );
    let before = target.load_identity_bundle();

    let rejected = identity_import_bundle(
        &mut target,
        exported.bundle_b64.as_deref().expect("bundle present"),
    );
    assert_eq!(rejected.status, IdentityStatus::Rejected);
    assert_eq!(target.load_identity_bundle(), before);
}

#[test]
fn identity_import_rejects_identifier_public_key_mismatch() {
    let mut source = MemoryClientStore::new();
    assert_eq!(
        identity_create_root(&mut source, "source").status,
        IdentityStatus::Created
    );
    let exported = identity_export_bundle(&source);
    let mut bundle = decode_bundle_value(exported.bundle_b64.as_deref().expect("bundle present"));
    bundle["root_kid"] = Value::String("not-derived-from-root-pub".to_string());

    let mut target = MemoryClientStore::new();
    let rejected = identity_import_bundle(&mut target, &encode_bundle_value(&bundle));
    assert_eq!(rejected.status, IdentityStatus::Rejected);
    assert!(target.load_identity_bundle().is_none());
}

#[test]
fn imported_max_sequence_rejects_next_reservation_without_panic() {
    let mut source = MemoryClientStore::new();
    assert_eq!(
        identity_create_root(&mut source, "source").status,
        IdentityStatus::Created
    );
    let exported = identity_export_bundle(&source);
    let mut bundle = decode_bundle_value(exported.bundle_b64.as_deref().expect("bundle present"));
    let root_kid = bundle["root_kid"]
        .as_str()
        .expect("root_kid string")
        .to_string();
    bundle["seq_state"][&root_kid] = Value::String(u64::MAX.to_string());

    let mut target = MemoryClientStore::new();
    let imported = identity_import_bundle(&mut target, &encode_bundle_value(&bundle));
    assert_eq!(imported.status, IdentityStatus::Imported);

    let rejected = device_add_key(&mut target, "overflow");
    assert_eq!(rejected.status, DeviceStatus::Rejected);
}

#[test]
fn stale_identity_import_preserves_sequence_after_another_identity_save() {
    let mut store = MemoryClientStore::new();
    let root = identity_create_root(&mut store, "root").root_kid.unwrap();
    let old = identity_export_bundle(&store).bundle_b64.unwrap();
    assert_eq!(
        device_add_key(&mut store, "first").status,
        DeviceStatus::Added
    );
    let first = store.list_lifecycle_events().remove(0);

    assert_eq!(
        identity_import_bundle(&mut store, &old).status,
        IdentityStatus::Imported
    );
    assert_eq!(
        device_set_active(&mut store, &root).status,
        DeviceStatus::Active
    );
    assert_eq!(
        device_add_key(&mut store, "second").status,
        DeviceStatus::Added
    );
    let second = store
        .list_lifecycle_events()
        .into_iter()
        .find(|event| event.event_id != first.event_id)
        .unwrap();
    assert_eq!(first.ak, second.ak);
    assert_ne!(first.payload_cid, second.payload_cid);
    assert_eq!(second.seq, first.seq + 1);
}

#[test]
fn stale_identity_import_persists_sequence_before_another_event() {
    let mut store = MemoryClientStore::new();
    identity_create_root(&mut store, "root");
    let device = device_add_key(&mut store, "device").device_ak.unwrap();
    let old = identity_export_bundle(&store).bundle_b64.unwrap();
    assert_eq!(
        device_revoke_key(&mut store, &device).status,
        DeviceStatus::Revoked
    );
    for _ in 0..2 {
        assert_eq!(
            identity_import_bundle(&mut store, &old).status,
            IdentityStatus::Imported
        );
    }

    let persisted_identity = identity_export_bundle(&store).bundle_b64.unwrap();
    let mut from_identity = MemoryClientStore::new();
    assert_eq!(
        identity_import_bundle(&mut from_identity, &persisted_identity).status,
        IdentityStatus::Imported
    );
    assert_eq!(
        device_add_key(&mut from_identity, "next").status,
        DeviceStatus::Added
    );
    assert_eq!(from_identity.list_lifecycle_events()[0].seq, 3);
}

#[test]
fn imported_identity_sequence_survives_snapshot_restart() {
    let mut store = MemoryClientStore::new();
    let root = identity_create_root(&mut store, "root").root_kid.unwrap();
    let old = identity_export_bundle(&store).bundle_b64.unwrap();
    let mut newer = decode_bundle_value(&old);
    newer["seq_state"][&root] = Value::String("2".into());
    assert_eq!(
        identity_import_bundle(&mut store, &encode_bundle_value(&newer)).status,
        IdentityStatus::Imported
    );
    assert_eq!(
        identity_import_bundle(&mut store, &old).status,
        IdentityStatus::Imported
    );

    let persisted_snapshot = store.export_store_snapshot().snapshot_b64.unwrap();
    let mut from_snapshot = MemoryClientStore::new();
    assert_eq!(
        from_snapshot
            .restore_store_snapshot(&persisted_snapshot)
            .status,
        StoreSnapshotStatus::Restored
    );
    assert_eq!(
        device_add_key(&mut from_snapshot, "next").status,
        DeviceStatus::Added
    );
    assert_eq!(
        from_snapshot
            .list_lifecycle_events()
            .iter()
            .map(|event| event.seq)
            .max(),
        Some(3)
    );
}

#[test]
fn identity_import_merges_sequence_maxima_with_retained_authorization() {
    let mut store = MemoryClientStore::new();
    let root = identity_create_root(&mut store, "root").root_kid.unwrap();
    let old = identity_export_bundle(&store).bundle_b64.unwrap();
    let device = device_add_key(&mut store, "local-device")
        .device_ak
        .unwrap();
    let mut current = decode_bundle_value(&identity_export_bundle(&store).bundle_b64.unwrap());
    current["seq_state"][&root] = Value::String("9".into());
    current["seq_state"][&device] = Value::String("9".into());
    assert_eq!(
        identity_import_bundle(&mut store, &encode_bundle_value(&current)).status,
        IdentityStatus::Imported
    );
    let mut incoming = decode_bundle_value(&old);
    incoming["seq_state"][&root] = Value::String("11".into());
    incoming["seq_state"]["incoming-only"] = Value::String("11".into());
    assert_eq!(
        identity_import_bundle(&mut store, &encode_bundle_value(&incoming)).status,
        IdentityStatus::Imported
    );

    let merged = store.load_identity_bundle().unwrap();
    assert_eq!(merged.seq_state[&root], "11");
    assert_eq!(merged.seq_state[&device], "9");
    assert_eq!(merged.seq_state["incoming-only"], "11");
    assert_eq!(merged.device_keys.len(), 2);
    assert_eq!(
        device_set_active(&mut store, "incoming-only").status,
        DeviceStatus::Rejected
    );
    assert_eq!(
        device_set_active(&mut store, &device).status,
        DeviceStatus::Active
    );
    assert_eq!(
        device_add_key(&mut store, "next").status,
        DeviceStatus::Added
    );
    assert_eq!(
        store
            .list_lifecycle_events()
            .iter()
            .map(|event| event.seq)
            .max(),
        Some(12)
    );

    // A missing root counter must not erase the existing high-water mark either.
    incoming["seq_state"] = serde_json::json!({});
    assert_eq!(
        identity_import_bundle(&mut store, &encode_bundle_value(&incoming)).status,
        IdentityStatus::Imported
    );
    assert_eq!(store.load_identity_bundle().unwrap().seq_state[&root], "12");
}

#[test]
fn stale_identity_import_keeps_exhausted_sequence_exhausted() {
    let mut store = MemoryClientStore::new();
    let root = identity_create_root(&mut store, "root").root_kid.unwrap();
    let old = identity_export_bundle(&store).bundle_b64.unwrap();
    let mut exhausted = decode_bundle_value(&old);
    exhausted["seq_state"][&root] = Value::String(u64::MAX.to_string());
    assert_eq!(
        identity_import_bundle(&mut store, &encode_bundle_value(&exhausted)).status,
        IdentityStatus::Imported
    );
    assert_eq!(
        identity_import_bundle(&mut store, &old).status,
        IdentityStatus::Imported
    );
    let before = store.export_store_snapshot().snapshot_b64;
    let rejected = device_add_key(&mut store, "overflow");
    assert_eq!(rejected.status, DeviceStatus::Rejected);
    assert_eq!(rejected.diag, vec!["SDK_ERR_STORE_CONFLICT"]);
    assert_eq!(store.export_store_snapshot().snapshot_b64, before);
}

#[test]
fn invalid_identity_sequence_import_leaves_live_state_unchanged() {
    let mut store = MemoryClientStore::new();
    let root = identity_create_root(&mut store, "root").root_kid.unwrap();
    assert_eq!(
        device_add_key(&mut store, "first").status,
        DeviceStatus::Added
    );
    let before = store.export_store_snapshot().snapshot_b64;
    let mut invalid = decode_bundle_value(&identity_export_bundle(&store).bundle_b64.unwrap());
    invalid["seq_state"][&root] = Value::String("18446744073709551616".into());
    let rejected = identity_import_bundle(&mut store, &encode_bundle_value(&invalid));
    assert_eq!(rejected.status, IdentityStatus::Rejected);
    assert_eq!(rejected.diag, vec!["SDK_ERR_IDENTITY_BUNDLE_INVALID"]);
    assert_eq!(store.export_store_snapshot().snapshot_b64, before);
    assert_eq!(
        device_add_key(&mut store, "second").status,
        DeviceStatus::Added
    );
    assert_eq!(
        store
            .list_lifecycle_events()
            .iter()
            .map(|event| event.seq)
            .max(),
        Some(2)
    );
}

fn decode_bundle_value(bundle_b64: &str) -> Value {
    let bytes = STANDARD.decode(bundle_b64).expect("bundle base64");
    serde_json::from_slice(&bytes).expect("bundle json")
}

fn encode_bundle_value(bundle: &Value) -> String {
    STANDARD.encode(serde_json::to_vec(bundle).expect("bundle json encode"))
}
