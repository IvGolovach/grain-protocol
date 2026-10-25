use base64::engine::general_purpose::STANDARD;
use base64::Engine;
use grain_client_core::{
    device_add_key, device_revoke_key, device_set_active, identity_create_root,
    identity_export_bundle, identity_import_bundle, ClientStore, DeviceStatus, IdentityClientStore,
    IdentityStatus, MemoryClientStore, StoreSnapshotStatus,
};

fn exported(store: &MemoryClientStore) -> String {
    identity_export_bundle(store).bundle_b64.unwrap()
}

fn restart(store: &MemoryClientStore) -> MemoryClientStore {
    let snapshot = store.export_store_snapshot().snapshot_b64.unwrap();
    let mut restarted = MemoryClientStore::new();
    let result = restarted.restore_store_snapshot(&snapshot);
    assert_eq!(
        result.status,
        StoreSnapshotStatus::Restored,
        "{:?}",
        result.diag
    );
    assert_eq!(
        restarted.load_identity_bundle(),
        store.load_identity_bundle()
    );
    assert_eq!(
        restarted.list_lifecycle_events(),
        store.list_lifecycle_events()
    );
    restarted
}

#[test]
fn older_identity_keeps_local_grants_and_snapshot_restorable() {
    let mut store = MemoryClientStore::new();
    identity_create_root(&mut store, "root");
    let old = exported(&store);
    let device = device_add_key(&mut store, "local").device_ak.unwrap();
    let before_events = store.list_lifecycle_events();
    assert_eq!(
        identity_import_bundle(&mut store, &old).status,
        IdentityStatus::Imported
    );
    assert!(store
        .load_identity_bundle()
        .unwrap()
        .device_keys
        .iter()
        .any(|d| d.ak == device));
    assert_eq!(store.list_lifecycle_events(), before_events);
    let mut restarted = restart(&store);
    assert_eq!(
        device_set_active(&mut restarted, &device).status,
        DeviceStatus::Active
    );
    assert_eq!(
        device_add_key(&mut restarted, "next").status,
        DeviceStatus::Added
    );
    assert_eq!(
        restarted
            .list_lifecycle_events()
            .iter()
            .map(|e| e.seq)
            .max(),
        Some(2)
    );
}

#[test]
fn older_identity_cannot_undo_revocation_or_break_snapshot() {
    let mut store = MemoryClientStore::new();
    let root = identity_create_root(&mut store, "root").root_kid.unwrap();
    let device = device_add_key(&mut store, "device").device_ak.unwrap();
    assert_eq!(
        device_set_active(&mut store, &device).status,
        DeviceStatus::Active
    );
    let old = exported(&store);
    assert_eq!(
        device_revoke_key(&mut store, &device).status,
        DeviceStatus::Revoked
    );
    let before = store.export_store_snapshot().snapshot_b64;
    for _ in 0..2 {
        assert_eq!(
            identity_import_bundle(&mut store, &old).status,
            IdentityStatus::Imported
        );
    }
    assert!(
        store.export_store_snapshot().snapshot_b64 == before,
        "store snapshot changed"
    );
    let bundle = store.load_identity_bundle().unwrap();
    assert!(bundle.revoked_aks.contains(&device));
    assert_eq!(bundle.active_ak, root);
    let mut restarted = restart(&store);
    assert_eq!(
        device_set_active(&mut restarted, &device).status,
        DeviceStatus::Rejected
    );
    assert_eq!(
        device_add_key(&mut restarted, "next").status,
        DeviceStatus::Added
    );
    assert_eq!(
        restarted
            .list_lifecycle_events()
            .iter()
            .map(|e| e.seq)
            .max(),
        Some(3)
    );
}

#[test]
fn identity_merge_accepts_new_devices_and_revocations_without_losing_local_history() {
    let mut source = MemoryClientStore::new();
    let root = identity_create_root(&mut source, "root").root_kid.unwrap();
    let common = device_add_key(&mut source, "common").device_ak.unwrap();
    let mut target = MemoryClientStore::new();
    assert_eq!(
        identity_import_bundle(&mut target, &exported(&source)).status,
        IdentityStatus::Imported
    );
    assert_eq!(
        device_set_active(&mut target, &common).status,
        DeviceStatus::Active
    );
    let local = device_add_key(&mut target, "local").device_ak.unwrap();
    let before_events = target.list_lifecycle_events();
    assert_eq!(
        device_revoke_key(&mut source, &common).status,
        DeviceStatus::Revoked
    );
    let remote = device_add_key(&mut source, "remote").device_ak.unwrap();
    let incoming = exported(&source);
    assert_eq!(
        identity_import_bundle(&mut target, &incoming).status,
        IdentityStatus::Imported
    );
    let merged = target.load_identity_bundle().unwrap();
    assert_eq!(merged.device_keys.len(), 4);
    assert!(merged.device_keys.iter().any(|d| d.ak == local));
    assert!(merged.device_keys.iter().any(|d| d.ak == remote));
    assert!(merged.revoked_aks.contains(&common));
    assert_eq!(merged.active_ak, root);
    assert_eq!(merged.seq_state[&root], "3");
    assert_eq!(target.list_lifecycle_events(), before_events);
    let snapshot = target.export_store_snapshot().snapshot_b64;
    assert_eq!(
        identity_import_bundle(&mut target, &incoming).status,
        IdentityStatus::Imported
    );
    assert!(
        target.export_store_snapshot().snapshot_b64 == snapshot,
        "reimport changed snapshot"
    );
    let mut restarted = restart(&target);
    assert_eq!(
        device_add_key(&mut restarted, "next").status,
        DeviceStatus::Added
    );
    assert_eq!(
        restarted
            .list_lifecycle_events()
            .iter()
            .map(|e| e.seq)
            .max(),
        Some(4)
    );
}

#[test]
fn same_root_with_different_sync_secret_rejects_without_mutation() {
    let mut store = MemoryClientStore::new();
    identity_create_root(&mut store, "root");
    device_add_key(&mut store, "device");
    let before = store.export_store_snapshot().snapshot_b64;
    let mut incoming = store.load_identity_bundle().unwrap();
    let mut secret = STANDARD.decode(&incoming.sync_secret_b64).unwrap();
    secret[0] ^= 1;
    incoming.sync_secret_b64 = STANDARD.encode(secret);
    let encoded = STANDARD.encode(serde_json::to_vec(&incoming).unwrap());
    let rejected = identity_import_bundle(&mut store, &encoded);
    assert_eq!(rejected.status, IdentityStatus::Rejected);
    assert_eq!(rejected.diag, vec!["SDK_ERR_IDENTITY_CONFLICT"]);
    assert!(
        store.export_store_snapshot().snapshot_b64 == before,
        "store snapshot changed"
    );
    restart(&store);
}

#[test]
fn inconsistent_legacy_history_requires_complete_identity_data_to_recover() {
    let mut store = MemoryClientStore::new();
    identity_create_root(&mut store, "root");
    let old = exported(&store);
    let old_bundle = store.load_identity_bundle().unwrap();
    device_add_key(&mut store, "device");
    let complete = exported(&store);
    // Model the state left by the old replacement-only importer.
    store
        .atomic(|tx| tx.save_identity_bundle(old_bundle))
        .unwrap();
    let before = store.export_store_snapshot().snapshot_b64;
    let rejected = identity_import_bundle(&mut store, &old);
    assert_eq!(rejected.status, IdentityStatus::Rejected);
    assert_eq!(rejected.diag, vec!["SDK_ERR_IDENTITY_CONFLICT"]);
    assert!(
        store.export_store_snapshot().snapshot_b64 == before,
        "store snapshot changed"
    );

    assert_eq!(
        identity_import_bundle(&mut store, &complete).status,
        IdentityStatus::Imported
    );
    let mut restarted = restart(&store);
    assert_eq!(
        device_add_key(&mut restarted, "next").status,
        DeviceStatus::Added
    );
    assert_eq!(
        restarted
            .list_lifecycle_events()
            .iter()
            .map(|e| e.seq)
            .max(),
        Some(2)
    );
}
