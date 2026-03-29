pub mod cbor;
pub mod cborseq;
pub mod cid;
pub mod cose;
pub mod dagcbor;
pub mod e2e;
pub mod error;
pub mod ledger;
pub mod limits;
pub mod manifest;
pub mod qr;

use std::collections::BTreeSet;

use base64::engine::general_purpose::STANDARD;
use base64::Engine;
use serde_json::{json, Value};

use crate::cborseq::parse_cborseq_stream;
use crate::cid::derive_cid_v1_dag_cbor_sha256;
use crate::cose::verify_cose_sign1;
use crate::dagcbor::validate_strict_dagcbor;
use crate::e2e::{decrypt_encrypted_object, derive_key_nonce};
use crate::error::{Diag, GrainError};
use crate::ledger::{reduce_ledger, LedgerEvent};
use crate::manifest::{resolve_manifest, ManifestRecord, ManifestResolveInput};
use crate::qr::decode_gr1_to_cose;

#[derive(Debug, Clone)]
pub struct OperationResult {
    pub accepted: bool,
    pub diag: Vec<String>,
    pub out: Value,
}

impl OperationResult {
    fn ok(out: Value, diag: Vec<Diag>) -> Self {
        Self {
            accepted: true,
            diag: normalize_diag(diag),
            out,
        }
    }

    fn reject(err: GrainError) -> Self {
        Self {
            accepted: false,
            diag: vec![err.diag().code().to_string()],
            out: json!({}),
        }
    }
}

pub fn execute_operation(op: &str, input: &Value, strict: bool) -> OperationResult {
    if !strict {
        return OperationResult::reject(GrainError::from_diag(Diag::Schema));
    }

    let r = match op {
        "dagcbor_validate" => op_dagcbor_validate(input),
        "cid_derive" => op_cid_derive(input),
        "cose_verify" => op_cose_verify(input),
        "qr_decode_gr1" => op_qr_decode_gr1(input),
        "e2e_derive_v1" => op_e2e_derive_v1(input),
        "e2e_decrypt" => op_e2e_decrypt(input),
        "parse_cborseq_stream_v1" => op_parse_cborseq_stream_v1(input),
        "manifest_resolve" => op_manifest_resolve(input),
        "ledger_reduce" => op_ledger_reduce(input),
        _ => Err(GrainError::from_diag(Diag::Schema)),
    };

    match r {
        Ok((out, diag)) => OperationResult::ok(out, diag),
        Err(e) => OperationResult::reject(e),
    }
}

fn op_dagcbor_validate(input: &Value) -> Result<(Value, Vec<Diag>), GrainError> {
    let bytes = decode_b64_field(input, "bytes_b64")?;
    let _ = validate_strict_dagcbor(&bytes)?;
    Ok((json!({}), Vec::new()))
}

fn op_cid_derive(input: &Value) -> Result<(Value, Vec<Diag>), GrainError> {
    let bytes = decode_b64_field(input, "bytes_b64")?;
    let _ = validate_strict_dagcbor(&bytes)?;
    let cid = derive_cid_v1_dag_cbor_sha256(&bytes)?;
    Ok((json!({ "cid": cid }), Vec::new()))
}

fn op_cose_verify(input: &Value) -> Result<(Value, Vec<Diag>), GrainError> {
    let cose = decode_b64_field(input, "cose_b64")?;
    let pub_b = decode_b64_field(input, "pub_b64")?;
    let aad = decode_b64_field(input, "external_aad_b64")?;

    verify_cose_sign1(&cose, &pub_b, &aad)?;
    Ok((json!({}), Vec::new()))
}

fn op_qr_decode_gr1(input: &Value) -> Result<(Value, Vec<Diag>), GrainError> {
    let qr = input
        .get("qr_string")
        .and_then(Value::as_str)
        .ok_or_else(|| GrainError::from_diag(Diag::Schema))?;

    let cose = decode_gr1_to_cose(qr)?;
    Ok((json!({ "cose_b64": STANDARD.encode(cose) }), Vec::new()))
}

fn op_e2e_derive_v1(input: &Value) -> Result<(Value, Vec<Diag>), GrainError> {
    let sync_secret = decode_b64_field(input, "sync_secret_b64")?;
    let cap_id = decode_b64_field(input, "cap_id_b64")?;
    let cid_link = decode_b64_field(input, "cid_link_bstr_b64")?;

    let derived = derive_key_nonce(&sync_secret, &cap_id, &cid_link)?;

    Ok((
        json!({
            "key_b64": STANDARD.encode(derived.key),
            "nonce_b64": STANDARD.encode(derived.nonce)
        }),
        Vec::new(),
    ))
}

fn op_e2e_decrypt(input: &Value) -> Result<(Value, Vec<Diag>), GrainError> {
    let encrypted = decode_b64_field(input, "encrypted_object_b64")?;
    let sync_secret = decode_b64_field(input, "sync_secret_b64")?;
    let cid_link = decode_b64_field(input, "cid_link_b64")?;
    let manifest_chash = match input.get("manifest_chash_b64") {
        Some(v) => Some(decode_b64_value(v)?),
        None => None,
    };

    let pt = decrypt_encrypted_object(
        &encrypted,
        &sync_secret,
        &cid_link,
        manifest_chash.as_deref(),
    )?;

    Ok((json!({ "pt_b64": STANDARD.encode(pt) }), Vec::new()))
}

fn op_parse_cborseq_stream_v1(input: &Value) -> Result<(Value, Vec<Diag>), GrainError> {
    let stream_kind = input
        .get("stream_kind")
        .and_then(Value::as_str)
        .ok_or_else(|| GrainError::from_diag(Diag::Schema))?;
    if stream_kind != "ledger" && stream_kind != "manifest" {
        return Err(GrainError::from_diag(Diag::Schema));
    }

    let bytes = match (input.get("cborseq_b64"), input.get("segments_b64")) {
        (Some(v), None) => decode_b64_value(v)?,
        (None, Some(v)) => {
            let mut all = Vec::new();
            let segs = v
                .as_array()
                .ok_or_else(|| GrainError::from_diag(Diag::Schema))?;
            for seg in segs {
                let b = decode_b64_value(seg)?;
                all.extend_from_slice(&b);
            }
            all
        }
        _ => return Err(GrainError::from_diag(Diag::Schema)),
    };

    let hashes = parse_cborseq_stream(&bytes)?;
    Ok((json!({ "item_sha256_hex": hashes }), Vec::new()))
}

fn op_manifest_resolve(input: &Value) -> Result<(Value, Vec<Diag>), GrainError> {
    let eligible_records = parse_manifest_records(input.get("eligible_records"))?;
    let eligible_tombstones = parse_manifest_records(input.get("eligible_tombstones"))?;
    let ineligible_records = parse_manifest_records(input.get("ineligible_records"))?;
    let ineligible_tombstones = parse_manifest_records(input.get("ineligible_tombstones"))?;

    let resolved = resolve_manifest(ManifestResolveInput {
        eligible_records,
        eligible_tombstones,
        ineligible_records,
        ineligible_tombstones,
    })?;

    let mut out = if resolved.status_unresolvable {
        json!({ "status": "UNRESOLVABLE" })
    } else {
        let cap = resolved
            .cap_id
            .ok_or_else(|| GrainError::from_diag(Diag::Schema))?;
        json!({ "cap_id_b64": STANDARD.encode(cap) })
    };

    if !resolved.diagnostics.is_empty() {
        let diags = normalize_diag(resolved.diagnostics.clone());
        if let Some(obj) = out.as_object_mut() {
            obj.insert("diag_contains".to_string(), json!(diags));
        }
    }

    Ok((out, resolved.diagnostics))
}

fn op_ledger_reduce(input: &Value) -> Result<(Value, Vec<Diag>), GrainError> {
    let root_kid = input
        .get("root_kid")
        .and_then(Value::as_str)
        .ok_or_else(|| GrainError::from_diag(Diag::Schema))?;

    let events_value = input
        .get("events")
        .ok_or_else(|| GrainError::from_diag(Diag::Schema))?;

    let events: Vec<LedgerEvent> =
        serde_json::from_value(events_value.clone()).map_err(|_| GrainError::from_diag(Diag::Schema))?;

    let totals = reduce_ledger(root_kid, &events)?;

    let mut out = json!({
        "sum_mean": totals.sum_mean,
        "sum_var": totals.sum_var,
    });

    if !totals.diag_contains.is_empty() {
        if let Some(obj) = out.as_object_mut() {
            obj.insert("diag_contains".to_string(), json!(totals.diag_contains));
        }
    }

    Ok((out, Vec::new()))
}

fn parse_manifest_records(value: Option<&Value>) -> Result<Vec<ManifestRecord>, GrainError> {
    let Some(value) = value else {
        return Ok(Vec::new());
    };

    let arr = value
        .as_array()
        .ok_or_else(|| GrainError::from_diag(Diag::Schema))?;

    let mut out = Vec::with_capacity(arr.len());
    for item in arr {
        let op = item
            .get("op")
            .and_then(Value::as_str)
            .ok_or_else(|| GrainError::from_diag(Diag::ManifestOp))?
            .to_string();

        let cap_id = match item.get("cap_id_b64") {
            Some(v) => Some(decode_b64_value(v)?),
            None => None,
        };

        let chash = match item.get("chash_b64") {
            Some(v) => Some(decode_b64_value(v)?),
            None => None,
        };

        out.push(ManifestRecord { op, cap_id, chash });
    }

    Ok(out)
}

fn decode_b64_field(input: &Value, field: &str) -> Result<Vec<u8>, GrainError> {
    let v = input
        .get(field)
        .ok_or_else(|| GrainError::from_diag(Diag::Schema))?;
    decode_b64_value(v)
}

fn decode_b64_value(v: &Value) -> Result<Vec<u8>, GrainError> {
    let s = v
        .as_str()
        .ok_or_else(|| GrainError::from_diag(Diag::Schema))?;
    STANDARD
        .decode(s)
        .map_err(|_| GrainError::from_diag(Diag::Schema))
}

fn normalize_diag(diag: Vec<Diag>) -> Vec<String> {
    let mut set = BTreeSet::new();
    for d in diag {
        set.insert(d.code().to_string());
    }
    set.into_iter().collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_cborseq_stream_rejects_invalid_stream_kind() {
        let err = op_parse_cborseq_stream_v1(&json!({
            "stream_kind": "bogus",
            "cborseq_b64": "oWFhAaFhYgI=",
        }))
        .unwrap_err();

        assert_eq!(err.diag(), Diag::Schema);
    }

    #[test]
    fn parse_cborseq_stream_requires_xor_input_fields() {
        let err = op_parse_cborseq_stream_v1(&json!({
            "stream_kind": "ledger",
            "cborseq_b64": "oWFhAaFhYgI=",
            "segments_b64": ["oQ==", "YWEB"],
        }))
        .unwrap_err();

        assert_eq!(err.diag(), Diag::Schema);
    }

    #[test]
    fn parse_cborseq_stream_accepts_empty_segments_as_empty_stream() {
        let (out, diag) = op_parse_cborseq_stream_v1(&json!({
            "stream_kind": "manifest",
            "segments_b64": [],
        }))
        .unwrap();

        assert!(diag.is_empty());
        assert_eq!(out, json!({ "item_sha256_hex": [] }));
    }
}
