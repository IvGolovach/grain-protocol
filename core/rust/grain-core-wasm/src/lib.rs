use grain_core::error::Diag;
use grain_core::execute_operation;
use serde_json::{json, Value};

fn reject_schema() -> Value {
    json!({
        "accepted": false,
        "diag": [Diag::Schema.code()],
        "out": {}
    })
}

#[no_mangle]
pub extern "C" fn grain_alloc(len: u32) -> u32 {
    let mut buf = vec![0u8; len as usize];
    let ptr = buf.as_mut_ptr() as u32;
    std::mem::forget(buf);
    ptr
}

#[no_mangle]
pub extern "C" fn grain_dealloc(ptr: u32, len: u32) {
    if ptr == 0 || len == 0 {
        return;
    }
    unsafe {
        let _ = Vec::from_raw_parts(ptr as *mut u8, len as usize, len as usize);
    }
}

fn encode_response(payload: &Value) -> u64 {
    let bytes = serde_json::to_vec(payload).unwrap_or_else(|_| {
        serde_json::to_vec(&reject_schema()).expect("reject_schema JSON serialization must not fail")
    });
    let len = bytes.len() as u32;
    let mut boxed = bytes.into_boxed_slice();
    let ptr = boxed.as_mut_ptr() as u32;
    std::mem::forget(boxed);
    ((ptr as u64) << 32) | (len as u64)
}

#[no_mangle]
pub extern "C" fn grain_run_vector(input_ptr: u32, input_len: u32) -> u64 {
    if input_ptr == 0 || input_len == 0 {
        return encode_response(&reject_schema());
    }

    let raw = unsafe {
        std::slice::from_raw_parts(input_ptr as *const u8, input_len as usize)
    };

    let vector: Value = match serde_json::from_slice(raw) {
        Ok(v) => v,
        Err(_) => return encode_response(&reject_schema()),
    };

    let op = match vector.get("op").and_then(Value::as_str) {
        Some(v) => v,
        None => return encode_response(&reject_schema()),
    };
    let strict = vector.get("strict").and_then(Value::as_bool).unwrap_or(true);
    let input = vector.get("input").cloned().unwrap_or_else(|| json!({}));

    let actual = execute_operation(op, &input, strict);
    let out = json!({
        "accepted": actual.accepted,
        "diag": actual.diag,
        "out": actual.out
    });
    encode_response(&out)
}
