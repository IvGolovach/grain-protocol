use base64::engine::general_purpose::STANDARD;
use base64::Engine;
use grain_client_core::{
    client_lifecycle, device_add_key, device_revoke_key, device_set_active, identity_create_root,
    identity_export_bundle, identity_import_bundle, ClientLifecycleStatus, DeviceStatus,
    IdentityClientStore, IdentityStatus, MemoryClientStore,
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

fn decode_bundle_value(bundle_b64: &str) -> Value {
    let bytes = STANDARD.decode(bundle_b64).expect("bundle base64");
    serde_json::from_slice(&bytes).expect("bundle json")
}

fn encode_bundle_value(bundle: &Value) -> String {
    STANDARD.encode(serde_json::to_vec(bundle).expect("bundle json encode"))
}
