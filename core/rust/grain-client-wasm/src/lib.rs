use grain_client_core::{
    client_lifecycle, device_add_key, device_revoke_key, device_set_active, identity_create_root,
    identity_export_bundle, identity_import_bundle, pairing_accept_envelope,
    pairing_create_envelope, pairing_preview_envelope, scan_accept, scan_preview,
    sync_export_bundle, sync_import_bundle, ClientLifecycle, ClientLifecycleStatus, ClientStore,
    DeviceResult, DeviceStatus, IdentityResult, IdentityStatus, MemoryClientStore, PairingResult,
    PairingStatus, ScanAccept, ScanPreview, StoreSnapshotResult, StoreSnapshotStatus, SyncResult,
    SyncStatus,
};
use serde_json::{json, Value};
use std::cell::RefCell;

const GRAIN_ERR_SCHEMA: &str = "GRAIN_ERR_SCHEMA";
const SDK_ERR_WASM_STORE_INVALID: &str = "SDK_ERR_WASM_STORE_INVALID";
const MAX_STORE_SLOTS: usize = 0xffff;
const STORE_SLOT_MASK: u32 = 0xffff;
const STORE_GENERATION_SHIFT: u32 = 16;

thread_local! {
    static STORE_TABLE: RefCell<Vec<StoreSlot>> = const { RefCell::new(Vec::new()) };
}

struct StoreSlot {
    generation: u16,
    store: Option<MemoryClientStore>,
}

#[no_mangle]
pub extern "C" fn grain_client_alloc(len: u32) -> u32 {
    let mut buf = vec![0u8; len as usize];
    let ptr = buf.as_mut_ptr() as u32;
    std::mem::forget(buf);
    ptr
}

#[no_mangle]
pub extern "C" fn grain_client_dealloc(ptr: u32, len: u32) {
    if ptr == 0 || len == 0 {
        return;
    }
    unsafe {
        let _ = Vec::from_raw_parts(ptr as *mut u8, len as usize, len as usize);
    }
}

#[no_mangle]
pub extern "C" fn grain_client_store_new() -> u32 {
    STORE_TABLE.with(|table| {
        let mut table = table.borrow_mut();
        if let Some(index) = table.iter().position(|slot| slot.store.is_none()) {
            table[index].store = Some(MemoryClientStore::new());
            return encode_store_handle(index, table[index].generation);
        }
        if table.len() == MAX_STORE_SLOTS {
            return 0;
        }
        table.push(StoreSlot {
            generation: 1,
            store: Some(MemoryClientStore::new()),
        });
        encode_store_handle(table.len() - 1, 1)
    })
}

#[no_mangle]
pub extern "C" fn grain_client_store_free(store_ptr: u32) {
    STORE_TABLE.with(|table| {
        let mut table = table.borrow_mut();
        let Some((index, generation)) = decode_store_handle(store_ptr) else {
            return;
        };
        let Some(slot) = table.get_mut(index) else {
            return;
        };
        if slot.generation == generation && slot.store.take().is_some() {
            slot.generation = next_store_generation(slot.generation);
        }
    });
}

#[no_mangle]
pub extern "C" fn grain_client_scan_preview(input_ptr: u32, input_len: u32) -> u64 {
    let Some(request) = decode_request(input_ptr, input_len) else {
        return encode_response(&scan_preview_rejected(GRAIN_ERR_SCHEMA));
    };

    let Some(qr_string) = request.get("qr_string").and_then(Value::as_str) else {
        return encode_response(&scan_preview_rejected(GRAIN_ERR_SCHEMA));
    };
    let trust_pub_b64 = match request.get("trust_pub_b64") {
        Some(Value::String(value)) => Some(value.as_str()),
        Some(Value::Null) | None => None,
        Some(_) => return encode_response(&scan_preview_rejected(GRAIN_ERR_SCHEMA)),
    };

    encode_response(&scan_preview_response(scan_preview(
        qr_string,
        trust_pub_b64,
    )))
}

#[no_mangle]
pub extern "C" fn grain_client_scan_accept(store_ptr: u32, input_ptr: u32, input_len: u32) -> u64 {
    let Some(request) = decode_request(input_ptr, input_len) else {
        return encode_response(&scan_accept_rejected(GRAIN_ERR_SCHEMA));
    };

    let Some(qr_string) = request.get("qr_string").and_then(Value::as_str) else {
        return encode_response(&scan_accept_rejected(GRAIN_ERR_SCHEMA));
    };
    let Some(trust_pub_b64) = request.get("trust_pub_b64").and_then(Value::as_str) else {
        return encode_response(&scan_accept_rejected(GRAIN_ERR_SCHEMA));
    };

    let Some(response) = with_store_mut(store_ptr, |store| {
        scan_accept_response(scan_accept(store, qr_string, Some(trust_pub_b64)))
    }) else {
        return encode_response(&scan_accept_rejected(SDK_ERR_WASM_STORE_INVALID));
    };
    encode_response(&response)
}

#[no_mangle]
pub extern "C" fn grain_client_list_accepted_scans(store_ptr: u32) -> u64 {
    let Some(records) = with_store_mut(store_ptr, |store| {
        store
            .list_accepted_scans()
            .into_iter()
            .map(|record| {
                json!({
                    "scan_id": record.scan_id,
                    "cose_b64": record.cose_b64,
                    "trust_pub_b64": record.trust_pub_b64
                })
            })
            .collect::<Vec<Value>>()
    }) else {
        return encode_response(&json!({
            "status": "Rejected",
            "diag": [SDK_ERR_WASM_STORE_INVALID],
            "records": []
        }));
    };

    encode_response(&json!({
        "status": "Ok",
        "diag": [],
        "records": records
    }))
}

#[no_mangle]
pub extern "C" fn grain_client_create_root_identity(
    store_ptr: u32,
    input_ptr: u32,
    input_len: u32,
) -> u64 {
    let Some(request) = decode_request(input_ptr, input_len) else {
        return encode_response(&identity_response(identity_rejected(GRAIN_ERR_SCHEMA)));
    };
    let label = request
        .get("label")
        .and_then(Value::as_str)
        .unwrap_or("root");
    let Some(response) = with_store_mut(store_ptr, |store| {
        identity_response(identity_create_root(store, label))
    }) else {
        return encode_response(&identity_response(identity_rejected(
            SDK_ERR_WASM_STORE_INVALID,
        )));
    };
    encode_response(&response)
}

#[no_mangle]
pub extern "C" fn grain_client_export_identity_bundle(store_ptr: u32) -> u64 {
    let Some(response) = with_store_mut(store_ptr, |store| {
        identity_response(identity_export_bundle(store))
    }) else {
        return encode_response(&identity_response(identity_rejected(
            SDK_ERR_WASM_STORE_INVALID,
        )));
    };
    encode_response(&response)
}

#[no_mangle]
pub extern "C" fn grain_client_import_identity_bundle(
    store_ptr: u32,
    input_ptr: u32,
    input_len: u32,
) -> u64 {
    let Some(request) = decode_request(input_ptr, input_len) else {
        return encode_response(&identity_response(identity_rejected(GRAIN_ERR_SCHEMA)));
    };
    let Some(bundle_b64) = request.get("bundle_b64").and_then(Value::as_str) else {
        return encode_response(&identity_response(identity_rejected(GRAIN_ERR_SCHEMA)));
    };
    let Some(response) = with_store_mut(store_ptr, |store| {
        identity_response(identity_import_bundle(store, bundle_b64))
    }) else {
        return encode_response(&identity_response(identity_rejected(
            SDK_ERR_WASM_STORE_INVALID,
        )));
    };
    encode_response(&response)
}

#[no_mangle]
pub extern "C" fn grain_client_add_device_key(
    store_ptr: u32,
    input_ptr: u32,
    input_len: u32,
) -> u64 {
    let Some(request) = decode_request(input_ptr, input_len) else {
        return encode_response(&device_response(device_rejected(GRAIN_ERR_SCHEMA)));
    };
    let label = request
        .get("label")
        .and_then(Value::as_str)
        .unwrap_or("device");
    let Some(response) = with_store_mut(store_ptr, |store| {
        device_response(device_add_key(store, label))
    }) else {
        return encode_response(&device_response(device_rejected(
            SDK_ERR_WASM_STORE_INVALID,
        )));
    };
    encode_response(&response)
}

#[no_mangle]
pub extern "C" fn grain_client_revoke_device_key(
    store_ptr: u32,
    input_ptr: u32,
    input_len: u32,
) -> u64 {
    let Some(request) = decode_request(input_ptr, input_len) else {
        return encode_response(&device_response(device_rejected(GRAIN_ERR_SCHEMA)));
    };
    let Some(ak) = request.get("ak").and_then(Value::as_str) else {
        return encode_response(&device_response(device_rejected(GRAIN_ERR_SCHEMA)));
    };
    let Some(response) = with_store_mut(store_ptr, |store| {
        device_response(device_revoke_key(store, ak))
    }) else {
        return encode_response(&device_response(device_rejected(
            SDK_ERR_WASM_STORE_INVALID,
        )));
    };
    encode_response(&response)
}

#[no_mangle]
pub extern "C" fn grain_client_set_active_device(
    store_ptr: u32,
    input_ptr: u32,
    input_len: u32,
) -> u64 {
    let Some(request) = decode_request(input_ptr, input_len) else {
        return encode_response(&device_response(device_rejected(GRAIN_ERR_SCHEMA)));
    };
    let Some(ak) = request.get("ak").and_then(Value::as_str) else {
        return encode_response(&device_response(device_rejected(GRAIN_ERR_SCHEMA)));
    };
    let Some(response) = with_store_mut(store_ptr, |store| {
        device_response(device_set_active(store, ak))
    }) else {
        return encode_response(&device_response(device_rejected(
            SDK_ERR_WASM_STORE_INVALID,
        )));
    };
    encode_response(&response)
}

#[no_mangle]
pub extern "C" fn grain_client_lifecycle(store_ptr: u32) -> u64 {
    let Some(response) = with_store_mut(store_ptr, |store| {
        lifecycle_response(client_lifecycle(store))
    }) else {
        return encode_response(&json!({
            "status": "Uninitialized",
            "diag": [SDK_ERR_WASM_STORE_INVALID],
            "root_kid": null,
            "active_ak": null,
            "device_count": 0,
            "revoked_count": 0,
            "accepted_record_count": 0,
            "lifecycle_event_count": 0
        }));
    };
    encode_response(&response)
}

#[no_mangle]
pub extern "C" fn grain_client_pairing_preview(input_ptr: u32, input_len: u32) -> u64 {
    let Some(request) = decode_request(input_ptr, input_len) else {
        return encode_response(&pairing_response(pairing_rejected(GRAIN_ERR_SCHEMA)));
    };
    let Some(envelope_b64) = request.get("envelope_b64").and_then(Value::as_str) else {
        return encode_response(&pairing_response(pairing_rejected(GRAIN_ERR_SCHEMA)));
    };
    encode_response(&pairing_response(pairing_preview_envelope(envelope_b64)))
}

#[no_mangle]
pub extern "C" fn grain_client_create_pairing_envelope(store_ptr: u32) -> u64 {
    let Some(response) = with_store_mut(store_ptr, |store| {
        pairing_response(pairing_create_envelope(store))
    }) else {
        return encode_response(&pairing_response(pairing_rejected(
            SDK_ERR_WASM_STORE_INVALID,
        )));
    };
    encode_response(&response)
}

#[no_mangle]
pub extern "C" fn grain_client_accept_pairing_envelope(
    store_ptr: u32,
    input_ptr: u32,
    input_len: u32,
) -> u64 {
    let Some(request) = decode_request(input_ptr, input_len) else {
        return encode_response(&pairing_response(pairing_rejected(GRAIN_ERR_SCHEMA)));
    };
    let Some(envelope_b64) = request.get("envelope_b64").and_then(Value::as_str) else {
        return encode_response(&pairing_response(pairing_rejected(GRAIN_ERR_SCHEMA)));
    };
    let Some(response) = with_store_mut(store_ptr, |store| {
        pairing_response(pairing_accept_envelope(store, envelope_b64))
    }) else {
        return encode_response(&pairing_response(pairing_rejected(
            SDK_ERR_WASM_STORE_INVALID,
        )));
    };
    encode_response(&response)
}

#[no_mangle]
pub extern "C" fn grain_client_export_sync_bundle(store_ptr: u32) -> u64 {
    let Some(response) =
        with_store_mut(store_ptr, |store| sync_response(sync_export_bundle(store)))
    else {
        return encode_response(&sync_response(sync_rejected(SDK_ERR_WASM_STORE_INVALID)));
    };
    encode_response(&response)
}

#[no_mangle]
pub extern "C" fn grain_client_import_sync_bundle(
    store_ptr: u32,
    input_ptr: u32,
    input_len: u32,
) -> u64 {
    let Some(request) = decode_request(input_ptr, input_len) else {
        return encode_response(&sync_response(sync_rejected(GRAIN_ERR_SCHEMA)));
    };
    let Some(bundle_b64) = request.get("bundle_b64").and_then(Value::as_str) else {
        return encode_response(&sync_response(sync_rejected(GRAIN_ERR_SCHEMA)));
    };
    let Some(response) = with_store_mut(store_ptr, |store| {
        sync_response(sync_import_bundle(store, bundle_b64))
    }) else {
        return encode_response(&sync_response(sync_rejected(SDK_ERR_WASM_STORE_INVALID)));
    };
    encode_response(&response)
}

#[no_mangle]
pub extern "C" fn grain_client_export_store_snapshot(store_ptr: u32) -> u64 {
    let Some(response) = with_store(store_ptr, |store| {
        store_snapshot_response(store.export_store_snapshot())
    }) else {
        return encode_response(&store_snapshot_response(store_snapshot_rejected(
            SDK_ERR_WASM_STORE_INVALID,
        )));
    };
    encode_response(&response)
}

#[no_mangle]
pub extern "C" fn grain_client_restore_store_snapshot(
    store_ptr: u32,
    input_ptr: u32,
    input_len: u32,
) -> u64 {
    let Some(request) = decode_request(input_ptr, input_len) else {
        return encode_response(&store_snapshot_response(store_snapshot_rejected(
            GRAIN_ERR_SCHEMA,
        )));
    };
    let Some(snapshot_b64) = request.get("snapshot_b64").and_then(Value::as_str) else {
        return encode_response(&store_snapshot_response(store_snapshot_rejected(
            GRAIN_ERR_SCHEMA,
        )));
    };
    let Some(response) = with_store_mut(store_ptr, |store| {
        store_snapshot_response(store.restore_store_snapshot(snapshot_b64))
    }) else {
        return encode_response(&store_snapshot_response(store_snapshot_rejected(
            SDK_ERR_WASM_STORE_INVALID,
        )));
    };
    encode_response(&response)
}

fn decode_request(input_ptr: u32, input_len: u32) -> Option<Value> {
    if input_ptr == 0 || input_len == 0 {
        return None;
    }
    let raw = unsafe { std::slice::from_raw_parts(input_ptr as *const u8, input_len as usize) };
    serde_json::from_slice(raw).ok()
}

fn with_store<R>(store_handle: u32, f: impl FnOnce(&MemoryClientStore) -> R) -> Option<R> {
    STORE_TABLE.with(|table| {
        let table = table.borrow();
        let (index, generation) = decode_store_handle(store_handle)?;
        let slot = table.get(index)?;
        if slot.generation != generation {
            return None;
        }
        slot.store.as_ref().map(f)
    })
}

fn with_store_mut<R>(store_handle: u32, f: impl FnOnce(&mut MemoryClientStore) -> R) -> Option<R> {
    STORE_TABLE.with(|table| {
        let mut table = table.borrow_mut();
        let (index, generation) = decode_store_handle(store_handle)?;
        let slot = table.get_mut(index)?;
        if slot.generation != generation {
            return None;
        }
        slot.store.as_mut().map(f)
    })
}

fn encode_store_handle(index: usize, generation: u16) -> u32 {
    ((generation as u32) << STORE_GENERATION_SHIFT) | ((index as u32 + 1) & STORE_SLOT_MASK)
}

fn decode_store_handle(handle: u32) -> Option<(usize, u16)> {
    let slot = handle & STORE_SLOT_MASK;
    let generation = (handle >> STORE_GENERATION_SHIFT) as u16;
    if slot == 0 || generation == 0 {
        return None;
    }
    Some((slot as usize - 1, generation))
}

fn next_store_generation(generation: u16) -> u16 {
    match generation.wrapping_add(1) {
        0 => 1,
        next => next,
    }
}

fn encode_response(payload: &Value) -> u64 {
    let bytes = serde_json::to_vec(payload).unwrap_or_else(|_| {
        serde_json::to_vec(&scan_accept_rejected(GRAIN_ERR_SCHEMA))
            .expect("schema rejection JSON serialization must not fail")
    });
    let len = bytes.len() as u32;
    let mut boxed = bytes.into_boxed_slice();
    let ptr = boxed.as_mut_ptr() as u32;
    std::mem::forget(boxed);
    ((ptr as u64) << 32) | (len as u64)
}

fn scan_preview_response(preview: ScanPreview) -> Value {
    json!({
        "status": preview.status.status_string(),
        "diag": preview.diag,
        "cose_b64": preview.cose_b64
    })
}

fn scan_accept_response(accepted: ScanAccept) -> Value {
    let (scan_id, cose_b64, trust_pub_b64) = accepted
        .accepted
        .map(|record| {
            (
                Some(record.scan_id),
                Some(record.cose_b64),
                Some(record.trust_pub_b64),
            )
        })
        .unwrap_or((None, None, None));

    json!({
        "status": accepted.status.status_string(),
        "diag": accepted.diag,
        "scan_id": scan_id,
        "cose_b64": cose_b64,
        "trust_pub_b64": trust_pub_b64
    })
}

fn scan_preview_rejected(diag: &str) -> Value {
    json!({
        "status": "Rejected",
        "diag": [diag],
        "cose_b64": null
    })
}

fn scan_accept_rejected(diag: &str) -> Value {
    json!({
        "status": "Rejected",
        "diag": [diag],
        "scan_id": null,
        "cose_b64": null,
        "trust_pub_b64": null
    })
}

fn identity_response(result: IdentityResult) -> Value {
    json!({
        "status": result.status.status_string(),
        "diag": result.diag,
        "root_kid": result.root_kid,
        "active_ak": result.active_ak,
        "bundle_b64": result.bundle_b64,
        "device_count": result.device_count,
        "revoked_count": result.revoked_count,
        "lifecycle_event_count": result.lifecycle_event_count
    })
}

fn identity_rejected(diag: &str) -> IdentityResult {
    IdentityResult {
        status: IdentityStatus::Rejected,
        diag: vec![diag.to_string()],
        root_kid: None,
        active_ak: None,
        bundle_b64: None,
        device_count: 0,
        revoked_count: 0,
        lifecycle_event_count: 0,
    }
}

fn device_response(result: DeviceResult) -> Value {
    json!({
        "status": result.status.status_string(),
        "diag": result.diag,
        "device_ak": result.device_ak,
        "active_ak": result.active_ak,
        "root_kid": result.root_kid,
        "device_count": result.device_count,
        "revoked_count": result.revoked_count,
        "lifecycle_event_count": result.lifecycle_event_count
    })
}

fn device_rejected(diag: &str) -> DeviceResult {
    DeviceResult {
        status: DeviceStatus::Rejected,
        diag: vec![diag.to_string()],
        device_ak: None,
        active_ak: None,
        root_kid: None,
        device_count: 0,
        revoked_count: 0,
        lifecycle_event_count: 0,
    }
}

fn lifecycle_response(result: ClientLifecycle) -> Value {
    json!({
        "status": result.status.status_string(),
        "diag": result.diag,
        "root_kid": result.root_kid,
        "active_ak": result.active_ak,
        "device_count": result.device_count,
        "revoked_count": result.revoked_count,
        "accepted_record_count": result.accepted_record_count,
        "lifecycle_event_count": result.lifecycle_event_count
    })
}

fn pairing_response(result: PairingResult) -> Value {
    json!({
        "status": result.status.status_string(),
        "diag": result.diag,
        "pairing_id": result.pairing_id,
        "envelope_b64": result.envelope_b64,
        "root_kid": result.root_kid,
        "device_count": result.device_count
    })
}

fn pairing_rejected(diag: &str) -> PairingResult {
    PairingResult {
        status: PairingStatus::Rejected,
        diag: vec![diag.to_string()],
        pairing_id: None,
        envelope_b64: None,
        root_kid: None,
        device_count: 0,
    }
}

fn sync_response(result: SyncResult) -> Value {
    json!({
        "status": result.status.status_string(),
        "diag": result.diag,
        "bundle_b64": result.bundle_b64,
        "accepted_record_count": result.accepted_record_count,
        "device_count": result.device_count,
        "lifecycle_event_count": result.lifecycle_event_count
    })
}

fn sync_rejected(diag: &str) -> SyncResult {
    SyncResult {
        status: SyncStatus::Rejected,
        diag: vec![diag.to_string()],
        bundle_b64: None,
        accepted_record_count: 0,
        device_count: 0,
        lifecycle_event_count: 0,
    }
}

fn store_snapshot_response(result: StoreSnapshotResult) -> Value {
    json!({
        "status": result.status.status_string(),
        "diag": result.diag,
        "snapshot_b64": result.snapshot_b64,
        "accepted_record_count": result.accepted_record_count,
        "device_count": result.device_count,
        "lifecycle_event_count": result.lifecycle_event_count
    })
}

fn store_snapshot_rejected(diag: &str) -> StoreSnapshotResult {
    StoreSnapshotResult {
        status: StoreSnapshotStatus::Rejected,
        diag: vec![diag.to_string()],
        snapshot_b64: None,
        accepted_record_count: 0,
        device_count: 0,
        lifecycle_event_count: 0,
    }
}

trait WasmStatus {
    fn status_string(&self) -> &'static str;
}

impl WasmStatus for grain_client_core::ScanPreviewStatus {
    fn status_string(&self) -> &'static str {
        match self {
            grain_client_core::ScanPreviewStatus::Verified => "Verified",
            grain_client_core::ScanPreviewStatus::Untrusted => "Untrusted",
            grain_client_core::ScanPreviewStatus::Rejected => "Rejected",
        }
    }
}

impl WasmStatus for grain_client_core::ScanAcceptStatus {
    fn status_string(&self) -> &'static str {
        match self {
            grain_client_core::ScanAcceptStatus::Accepted => "Accepted",
            grain_client_core::ScanAcceptStatus::AlreadyAccepted => "AlreadyAccepted",
            grain_client_core::ScanAcceptStatus::Rejected => "Rejected",
        }
    }
}

impl WasmStatus for IdentityStatus {
    fn status_string(&self) -> &'static str {
        match self {
            IdentityStatus::Created => "Created",
            IdentityStatus::Exported => "Exported",
            IdentityStatus::Imported => "Imported",
            IdentityStatus::AlreadyExists => "AlreadyExists",
            IdentityStatus::Uninitialized => "Uninitialized",
            IdentityStatus::Rejected => "Rejected",
        }
    }
}

impl WasmStatus for DeviceStatus {
    fn status_string(&self) -> &'static str {
        match self {
            DeviceStatus::Added => "Added",
            DeviceStatus::Revoked => "Revoked",
            DeviceStatus::Active => "Active",
            DeviceStatus::Rejected => "Rejected",
        }
    }
}

impl WasmStatus for ClientLifecycleStatus {
    fn status_string(&self) -> &'static str {
        match self {
            ClientLifecycleStatus::Ready => "Ready",
            ClientLifecycleStatus::Uninitialized => "Uninitialized",
        }
    }
}

impl WasmStatus for PairingStatus {
    fn status_string(&self) -> &'static str {
        match self {
            PairingStatus::Created => "Created",
            PairingStatus::Valid => "Valid",
            PairingStatus::Paired => "Paired",
            PairingStatus::AlreadyPaired => "AlreadyPaired",
            PairingStatus::Rejected => "Rejected",
        }
    }
}

impl WasmStatus for SyncStatus {
    fn status_string(&self) -> &'static str {
        match self {
            SyncStatus::Exported => "Exported",
            SyncStatus::Empty => "Empty",
            SyncStatus::Imported => "Imported",
            SyncStatus::AlreadyImported => "AlreadyImported",
            SyncStatus::Rejected => "Rejected",
        }
    }
}

impl WasmStatus for StoreSnapshotStatus {
    fn status_string(&self) -> &'static str {
        match self {
            StoreSnapshotStatus::Exported => "Exported",
            StoreSnapshotStatus::Restored => "Restored",
            StoreSnapshotStatus::Empty => "Empty",
            StoreSnapshotStatus::Rejected => "Rejected",
        }
    }
}
