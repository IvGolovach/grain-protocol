use grain_client_core::{
    scan_accept, scan_preview, ClientStore, MemoryClientStore, ScanAccept, ScanPreview,
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

fn decode_request(input_ptr: u32, input_len: u32) -> Option<Value> {
    if input_ptr == 0 || input_len == 0 {
        return None;
    }
    let raw = unsafe { std::slice::from_raw_parts(input_ptr as *const u8, input_len as usize) };
    serde_json::from_slice(raw).ok()
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
