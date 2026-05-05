use std::fs;
use std::path::{Component, Path};

use base64::engine::general_purpose::STANDARD;
use base64::Engine;
use grain_client_core::{
    client_lifecycle, device_add_key, identity_create_root, pairing_accept_envelope,
    pairing_create_envelope, pairing_preview_envelope, scan_accept, sync_export_bundle,
    sync_import_bundle, IdentityClientStore, IdentityStatus, MemoryClientStore, PairingStatus,
    SyncStatus,
};
use serde_json::Value;

#[test]
fn pairing_envelope_preview_is_pure_and_accept_is_idempotent() {
    let mut source = MemoryClientStore::new();
    assert_eq!(
        identity_create_root(&mut source, "phone").status,
        IdentityStatus::Created
    );
    let envelope = pairing_create_envelope(&source);
    assert_eq!(envelope.status, PairingStatus::Created);

    let envelope_b64 = envelope.envelope_b64.as_deref().expect("envelope present");
    let preview = pairing_preview_envelope(envelope_b64);
    assert_eq!(preview.status, PairingStatus::Valid);

    let mut target = MemoryClientStore::new();
    let paired = pairing_accept_envelope(&mut target, envelope_b64);
    assert_eq!(paired.status, PairingStatus::Paired);

    let replay = pairing_accept_envelope(&mut target, envelope_b64);
    assert_eq!(replay.status, PairingStatus::AlreadyPaired);
}

#[test]
fn malformed_pairing_envelope_rejects_without_identity_mutation() {
    let mut target = MemoryClientStore::new();
    let rejected = pairing_accept_envelope(&mut target, "not-base64");
    assert_eq!(rejected.status, PairingStatus::Rejected);
    assert!(target.load_identity_bundle().is_none());
}

#[test]
fn sync_bundle_imports_identity_lifecycle_and_scans_idempotently() {
    let mut source = MemoryClientStore::new();
    assert_eq!(
        identity_create_root(&mut source, "phone").status,
        IdentityStatus::Created
    );
    assert_eq!(
        device_add_key(&mut source, "glasses").diag,
        Vec::<String>::new()
    );
    let qr = fixture_string("conformance/vectors/qr/POS-QR-001.json#/input/qr_string");
    let trust = fixture_string("conformance/vectors/cose/POS-COSE-001.json#/input/pub_b64");
    assert!(scan_accept(&mut source, &qr, Some(&trust)).diag.is_empty());

    let exported = sync_export_bundle(&source);
    assert_eq!(exported.status, SyncStatus::Exported);
    assert_eq!(exported.accepted_record_count, 1);
    assert_eq!(exported.device_count, 2);
    assert_eq!(exported.lifecycle_event_count, 1);

    let bundle_b64 = exported.bundle_b64.as_deref().expect("sync bundle present");
    let mut target = MemoryClientStore::new();
    let imported = sync_import_bundle(&mut target, bundle_b64);
    assert_eq!(imported.status, SyncStatus::Imported);
    assert_eq!(imported.accepted_record_count, 1);
    assert_eq!(imported.device_count, 2);
    assert_eq!(imported.lifecycle_event_count, 1);

    let replay = sync_import_bundle(&mut target, bundle_b64);
    assert_eq!(replay.status, SyncStatus::AlreadyImported);
    assert_eq!(replay.accepted_record_count, 1);
}

#[test]
fn sync_identity_conflict_rolls_back_import() {
    let mut source = MemoryClientStore::new();
    assert_eq!(
        identity_create_root(&mut source, "source").status,
        IdentityStatus::Created
    );
    let exported = sync_export_bundle(&source);
    let bundle_b64 = exported.bundle_b64.as_deref().expect("sync bundle present");

    let mut target = MemoryClientStore::new();
    assert_eq!(
        identity_create_root(&mut target, "target").status,
        IdentityStatus::Created
    );
    let before = target.load_identity_bundle();
    let rejected = sync_import_bundle(&mut target, bundle_b64);
    assert_eq!(rejected.status, SyncStatus::Rejected);
    assert_eq!(target.load_identity_bundle(), before);
}

#[test]
fn sync_import_merges_same_root_identity_without_dropping_local_device() {
    let mut source = MemoryClientStore::new();
    assert_eq!(
        identity_create_root(&mut source, "source").status,
        IdentityStatus::Created
    );
    assert_eq!(
        device_add_key(&mut source, "source-device").diag,
        Vec::<String>::new()
    );
    let exported = sync_export_bundle(&source);
    let bundle_b64 = exported.bundle_b64.as_deref().expect("sync bundle present");

    let mut target = MemoryClientStore::new();
    assert_eq!(
        sync_import_bundle(&mut target, bundle_b64).status,
        SyncStatus::Imported
    );
    assert_eq!(
        device_add_key(&mut target, "target-device").diag,
        Vec::<String>::new()
    );
    let before = client_lifecycle(&target);
    assert_eq!(before.device_count, 3);
    assert_eq!(before.lifecycle_event_count, 2);

    let replay = sync_import_bundle(&mut target, bundle_b64);
    assert_eq!(replay.status, SyncStatus::AlreadyImported);
    let after = client_lifecycle(&target);
    assert_eq!(after.device_count, before.device_count);
    assert_eq!(after.lifecycle_event_count, before.lifecycle_event_count);
}

#[test]
fn sync_import_rejects_cross_identity_lifecycle_events() {
    let mut source = MemoryClientStore::new();
    assert_eq!(
        identity_create_root(&mut source, "source").status,
        IdentityStatus::Created
    );
    assert_eq!(
        device_add_key(&mut source, "device").diag,
        Vec::<String>::new()
    );
    let exported = sync_export_bundle(&source);
    let mut bundle =
        decode_bundle_value(exported.bundle_b64.as_deref().expect("sync bundle present"));
    bundle["lifecycle_events"][0]["ak"] = Value::String("foreign-root".to_string());

    let mut target = MemoryClientStore::new();
    let rejected = sync_import_bundle(&mut target, &encode_bundle_value(&bundle));
    assert_eq!(rejected.status, SyncStatus::Rejected);
    assert!(target.load_identity_bundle().is_none());
    assert!(target.list_lifecycle_events().is_empty());
}

fn fixture_string(reference: &str) -> String {
    let (file_part, pointer) = reference
        .split_once("#/")
        .expect("fixture reference must contain JSON pointer");
    let relative = Path::new(file_part);
    assert!(!relative.is_absolute());
    assert!(!relative
        .components()
        .any(|component| matches!(component, Component::ParentDir)));

    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../..");
    let text = fs::read_to_string(root.join(relative)).expect("fixture file must read");
    let mut node = serde_json::from_str::<Value>(&text).expect("fixture JSON must parse");
    for raw_part in pointer.split('/') {
        let part = raw_part.replace("~1", "/").replace("~0", "~");
        node = match &node {
            Value::Object(object) => object.get(&part).cloned(),
            Value::Array(array) => part
                .parse::<usize>()
                .ok()
                .and_then(|index| array.get(index).cloned()),
            _ => None,
        }
        .unwrap_or_else(|| panic!("fixture pointer must resolve: {reference} at {part}"));
    }
    node.as_str()
        .expect("fixture pointer must be string")
        .to_string()
}

fn decode_bundle_value(bundle_b64: &str) -> Value {
    let bytes = STANDARD.decode(bundle_b64).expect("sync bundle base64");
    serde_json::from_slice(&bytes).expect("sync bundle json")
}

fn encode_bundle_value(bundle: &Value) -> String {
    STANDARD.encode(serde_json::to_vec(bundle).expect("sync bundle json encode"))
}
