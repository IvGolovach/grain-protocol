use crate::cbor::{encode_canonical, CborValue};
use crate::dagcbor::{parse_strict_dagcbor_encoding, validate_tstr_set_array};
use crate::error::{Diag, GrainError, GrainResult};
use crate::limits::Limits;
use crate::object_schema::{schema_for_object_type, ObjectSchemaV1, ObjectTypeV1, PayloadLimitV1};

type CborMap = [(CborValue, CborValue)];

const COOK_INPUT_KEYS: &[&str] = &["ing", "amount_g", "note", "ext", "crit"];
const MAP_DECISION_KEYS: &[&str] = &["ing", "profile", "ext", "crit"];
const EVENT_REF_KEYS: &[&str] = &["ak", "seq"];
const CID_LINK_PREFIX: [u8; 5] = [0x00, 0x01, 0x71, 0x12, 0x20];
const CID_LINK_BSTR_LEN: usize = CID_LINK_PREFIX.len() + 32;

pub fn validate_typed_object_v1(bytes: &[u8], object_type: &str) -> GrainResult<CborValue> {
    let schema = schema_for_object_type(object_type);
    let payload_limit = schema
        .map(|schema| schema.payload_limit)
        .unwrap_or(PayloadLimitV1::DagCborObject);
    validate_context_payload_limit(bytes, payload_limit)?;

    let value = parse_strict_dagcbor_encoding(bytes)?;
    validate_all_cid_links(&value)?;
    let schema = schema.ok_or_else(|| GrainError::from_diag(Diag::Schema))?;
    let map = value
        .as_map()
        .ok_or_else(|| GrainError::from_diag(Diag::Schema))?;

    validate_envelope(map, schema)?;
    validate_top_level_keys(map, schema.allowed_top_level_keys)?;
    validate_common_fields(map)?;

    match schema.object_type {
        ObjectTypeV1::IngredientRef => validate_ingredient_ref(map)?,
        ObjectTypeV1::NutrientProfile => validate_nutrient_profile(map)?,
        ObjectTypeV1::CookRun => validate_cook_run(map)?,
        ObjectTypeV1::NutritionComputeResult => validate_nutrition_compute_result(map)?,
        ObjectTypeV1::IntakeEvent => validate_intake_event(map)?,
        ObjectTypeV1::ServingOffer => validate_serving_offer(map)?,
        ObjectTypeV1::LedgerGenesis => validate_ledger_genesis(map)?,
        ObjectTypeV1::DeviceKeyGrant => validate_device_key_grant(map)?,
        ObjectTypeV1::DeviceKeyRevoke => validate_device_key_revoke(map)?,
        ObjectTypeV1::VoidEvent | ObjectTypeV1::CorrectionEvent => validate_target_event(map)?,
        ObjectTypeV1::LedgerEvent => validate_ledger_event(map)?,
        ObjectTypeV1::EncryptedObject => validate_encrypted_object(map)?,
        ObjectTypeV1::ManifestRecord => validate_manifest_record(map)?,
    }

    Ok(value)
}

fn validate_context_payload_limit(bytes: &[u8], limit: PayloadLimitV1) -> GrainResult<()> {
    let limits = Limits::STRICT_BASELINE;
    let max = match limit {
        PayloadLimitV1::DagCborObject => limits.max_dagcbor_object_bytes,
        PayloadLimitV1::LedgerEvent => limits.max_ledger_event_payload_bytes,
        PayloadLimitV1::ManifestRecord => limits.max_manifest_record_payload_bytes,
        PayloadLimitV1::ServingOffer => limits.max_servingoffer_payload_bytes,
        PayloadLimitV1::EncryptedObject => limits.max_e2e_ciphertext_bytes,
    };
    if bytes.len() > max {
        return Err(GrainError::from_diag(Diag::Limit));
    }
    Ok(())
}

fn validate_envelope(map: &CborMap, schema: &ObjectSchemaV1) -> GrainResult<()> {
    if !matches!(map_find(map, "v"), Some(CborValue::Unsigned(1))) {
        return Err(GrainError::from_diag(Diag::Schema));
    }

    let actual_t = require_text(map, "t")?;
    if let Some(expected_t) = schema.literal_t {
        if actual_t != expected_t.as_bytes() {
            return Err(GrainError::from_diag(Diag::Schema));
        }
    }
    Ok(())
}

fn validate_top_level_keys(map: &CborMap, allowed: &[&str]) -> GrainResult<()> {
    for (key, _) in map {
        let Some(key) = key.as_text() else {
            return Err(GrainError::from_diag(Diag::NonCanonical));
        };
        if !allowed.contains(&key.as_str()) {
            return Err(GrainError::from_diag(Diag::UnknownTopLevelKey));
        }
    }
    Ok(())
}

fn validate_nested_keys(map: &CborMap, allowed: &[&str]) -> GrainResult<()> {
    for (key, _) in map {
        let Some(key) = key.as_text() else {
            return Err(GrainError::from_diag(Diag::NonCanonical));
        };
        if !allowed.contains(&key.as_str()) {
            return Err(GrainError::from_diag(Diag::Schema));
        }
    }
    Ok(())
}

fn validate_common_fields(map: &CborMap) -> GrainResult<()> {
    if let Some(ext) = map_find(map, "ext") {
        if !matches!(ext, CborValue::Map(_)) {
            return Err(GrainError::from_diag(Diag::Schema));
        }
        let mut canonical = Vec::new();
        encode_canonical(ext, &mut canonical);
        if canonical.len() > Limits::STRICT_BASELINE.max_ext_canonical_bytes {
            return Err(GrainError::from_diag(Diag::Limit));
        }
    }
    if let Some(crit) = map_find(map, "crit") {
        validate_tstr_set_array(crit, true)?;
    }
    Ok(())
}

fn validate_ingredient_ref(map: &CborMap) -> GrainResult<()> {
    require_text(map, "ref_type")?;
    require_text(map, "ref_id")?;
    optional_text(map, "ref_version")?;
    optional_text(map, "name")?;
    Ok(())
}

fn validate_nutrient_profile(map: &CborMap) -> GrainResult<()> {
    require_text(map, "dataset_snapshot_id")?;
    require_text(map, "source")?;
    require_text(map, "basis")?;
    validate_nutrient_map(require(map, "nutr")?, false)?;
    if let Some(uncert) = map_find(map, "uncert") {
        validate_nutrient_map(uncert, true)?;
    }
    Ok(())
}

fn validate_cook_run(map: &CborMap) -> GrainResult<()> {
    validate_structured_set_array(require(map, "inputs")?, validate_cook_input)?;
    optional_nonnegative_int64(map, "yield_g")?;
    optional_int64(map, "ts_ms")?;
    Ok(())
}

fn validate_cook_input(value: &CborValue) -> GrainResult<()> {
    let map = expect_map(value)?;
    validate_nested_keys(map, COOK_INPUT_KEYS)?;
    validate_common_fields(map)?;
    validate_cid_link(require(map, "ing")?)?;
    require_nonnegative_int64(map, "amount_g")?;
    optional_text(map, "note")?;
    Ok(())
}

fn validate_nutrition_compute_result(map: &CborMap) -> GrainResult<()> {
    validate_cid_link(require(map, "cookrun")?)?;
    require_text(map, "engine_id")?;
    require_text(map, "engine_version")?;
    require_text(map, "dataset_snapshot_id")?;
    validate_structured_set_array(require(map, "map")?, validate_map_decision)?;
    validate_nutrient_map(require(map, "out")?, false)?;
    Ok(())
}

fn validate_map_decision(value: &CborValue) -> GrainResult<()> {
    let map = expect_map(value)?;
    validate_nested_keys(map, MAP_DECISION_KEYS)?;
    validate_common_fields(map)?;
    validate_cid_link(require(map, "ing")?)?;
    validate_cid_link(require(map, "profile")?)?;
    Ok(())
}

fn validate_intake_event(map: &CborMap) -> GrainResult<()> {
    let source_class = require_text(map, "source_class")?;
    if !matches!(source_class, b"attested" | b"measured" | b"estimated") {
        return Err(GrainError::from_diag(Diag::Schema));
    }

    validate_nutrient_map(require(map, "mean")?, false)?;
    validate_nutrient_map(require(map, "var")?, true)?;
    optional_int64(map, "ts_ms")?;

    match require_text(map, "mode")? {
        b"from_cookrun" => {
            validate_cid_link(require(map, "cookrun")?)?;
            require_nonnegative_int64(map, "amount_g")?;
            forbid_fields(map, &["ing", "profile", "servings"])?;
        }
        b"from_ingredient" => {
            validate_cid_link(require(map, "ing")?)?;
            require_nonnegative_int64(map, "amount_g")?;
            forbid_fields(map, &["cookrun", "profile", "servings"])?;
        }
        b"from_profile" => {
            validate_cid_link(require(map, "profile")?)?;
            require_nonnegative_int64(map, "servings")?;
            forbid_fields(map, &["cookrun", "ing", "amount_g"])?;
        }
        _ => return Err(GrainError::from_diag(Diag::Schema)),
    }

    Ok(())
}

fn validate_serving_offer(map: &CborMap) -> GrainResult<()> {
    require_bytes_len(map, "issuer_kid", 16)?;
    require_nonnegative_int64(map, "serving_g")?;
    validate_nutrient_map(require(map, "mean")?, false)?;
    validate_nutrient_map(require(map, "var")?, true)?;
    optional_bytes(map, "nonce")?;
    Ok(())
}

fn validate_ledger_genesis(map: &CborMap) -> GrainResult<()> {
    require_bytes_len(map, "root_kid", 16)?;
    require_bytes_len(map, "root_pub", 32)?;
    Ok(())
}

fn validate_device_key_grant(map: &CborMap) -> GrainResult<()> {
    require_bytes_len(map, "ak", 16)?;
    require_bytes_len(map, "pub", 32)?;
    validate_tstr_set_array(require(map, "caps")?, false)?;
    Ok(())
}

fn validate_device_key_revoke(map: &CborMap) -> GrainResult<()> {
    require_bytes_len(map, "ak", 16)?;
    Ok(())
}

fn validate_target_event(map: &CborMap) -> GrainResult<()> {
    validate_event_ref(require(map, "target")?)?;
    optional_text(map, "reason")?;
    Ok(())
}

fn validate_event_ref(value: &CborValue) -> GrainResult<()> {
    let map = expect_map(value)?;
    validate_nested_keys(map, EVENT_REF_KEYS)?;
    require_bytes_len(map, "ak", 16)?;
    require_uint63(map, "seq")?;
    Ok(())
}

fn validate_ledger_event(map: &CborMap) -> GrainResult<()> {
    require_bytes_len(map, "ak", 16)?;
    require_uint63(map, "seq")?;
    optional_int64(map, "ts_ms")?;
    require(map, "body")?;
    Ok(())
}

fn validate_encrypted_object(map: &CborMap) -> GrainResult<()> {
    require_literal_text(map, "alg", b"A256GCM")?;
    require_bytes_len(map, "cap_id", 32)?;
    require_bytes_len(map, "nonce", 12)?;
    let ct = require_bytes(map, "ct")?;
    if ct.len() > Limits::STRICT_BASELINE.max_e2e_ciphertext_bytes {
        return Err(GrainError::from_diag(Diag::Limit));
    }
    Ok(())
}

fn validate_manifest_record(map: &CborMap) -> GrainResult<()> {
    let op_value = map_find(map, "op").ok_or_else(|| GrainError::from_diag(Diag::ManifestOp))?;
    let op = op_value
        .as_text_bytes()
        .ok_or_else(|| GrainError::from_diag(Diag::ManifestOp))?;
    let is_put = match op {
        b"put" => {
            if !map_has(map, "cap_id") || !map_has(map, "chash") {
                return Err(GrainError::from_diag(Diag::ManifestOp));
            }
            true
        }
        b"del" => {
            if map_has(map, "cap_id") || map_has(map, "chash") || map_has(map, "size") {
                return Err(GrainError::from_diag(Diag::ManifestOp));
            }
            false
        }
        _ => return Err(GrainError::from_diag(Diag::ManifestOp)),
    };

    require_bytes_len(map, "ak", 16)?;
    require_uint63(map, "seq")?;
    validate_cid_link(require(map, "cid")?)?;
    if is_put {
        require_bytes_len(map, "cap_id", 32)?;
        require_bytes_len(map, "chash", 32)?;
        optional_uint63(map, "size")?;
    }
    Ok(())
}

fn validate_nutrient_map(value: &CborValue, nonnegative: bool) -> GrainResult<()> {
    let map = expect_map(value)?;
    for (key, value) in map {
        if key.as_text_bytes().is_none() {
            return Err(GrainError::from_diag(Diag::NonCanonical));
        }
        if nonnegative {
            expect_nonnegative_int64(value)?;
        } else {
            expect_int64(value)?;
        }
    }
    Ok(())
}

fn validate_structured_set_array(
    value: &CborValue,
    validate_item: fn(&CborValue) -> GrainResult<()>,
) -> GrainResult<()> {
    let CborValue::Array(items) = value else {
        return Err(GrainError::from_diag(Diag::Schema));
    };

    let mut encoded_items = Vec::with_capacity(items.len());
    for item in items {
        validate_item(item)?;
        let mut encoded = Vec::new();
        encode_canonical(item, &mut encoded);
        encoded_items.push(encoded);
    }

    for pair in encoded_items.windows(2) {
        if pair[0] == pair[1] {
            return Err(GrainError::from_diag(Diag::SetArrayDup));
        }
        if pair[0] > pair[1] {
            return Err(GrainError::from_diag(Diag::SetArrayOrder));
        }
    }
    Ok(())
}

fn validate_cid_link(value: &CborValue) -> GrainResult<()> {
    let CborValue::Tag(42, inner) = value else {
        return Err(GrainError::from_diag(Diag::BadCidLink));
    };
    let Some(bytes) = inner.as_bytes() else {
        return Err(GrainError::from_diag(Diag::BadCidLink));
    };
    if bytes.len() != CID_LINK_BSTR_LEN || bytes[..CID_LINK_PREFIX.len()] != CID_LINK_PREFIX {
        return Err(GrainError::from_diag(Diag::BadCidLink));
    }
    Ok(())
}

fn validate_all_cid_links(value: &CborValue) -> GrainResult<()> {
    match value {
        CborValue::Tag(42, _) => validate_cid_link(value),
        CborValue::Tag(_, _) => Err(GrainError::from_diag(Diag::TagForbidden)),
        CborValue::Array(items) => {
            for item in items {
                validate_all_cid_links(item)?;
            }
            Ok(())
        }
        CborValue::Map(entries) => {
            for (key, value) in entries {
                validate_all_cid_links(key)?;
                validate_all_cid_links(value)?;
            }
            Ok(())
        }
        _ => Ok(()),
    }
}

fn expect_map(value: &CborValue) -> GrainResult<&CborMap> {
    value
        .as_map()
        .map(Vec::as_slice)
        .ok_or_else(|| GrainError::from_diag(Diag::Schema))
}

fn map_find<'a>(map: &'a CborMap, key: &str) -> Option<&'a CborValue> {
    map.iter()
        .find(|(candidate, _)| candidate.as_text_bytes() == Some(key.as_bytes()))
        .map(|(_, value)| value)
}

fn map_has(map: &CborMap, key: &str) -> bool {
    map_find(map, key).is_some()
}

fn require<'a>(map: &'a CborMap, key: &str) -> GrainResult<&'a CborValue> {
    map_find(map, key).ok_or_else(|| GrainError::from_diag(Diag::Schema))
}

fn require_text<'a>(map: &'a CborMap, key: &str) -> GrainResult<&'a [u8]> {
    require(map, key)?
        .as_text_bytes()
        .ok_or_else(|| GrainError::from_diag(Diag::Schema))
}

fn require_literal_text(map: &CborMap, key: &str, expected: &[u8]) -> GrainResult<()> {
    if require_text(map, key)? != expected {
        return Err(GrainError::from_diag(Diag::Schema));
    }
    Ok(())
}

fn optional_text(map: &CborMap, key: &str) -> GrainResult<()> {
    if let Some(value) = map_find(map, key) {
        if value.as_text_bytes().is_none() {
            return Err(GrainError::from_diag(Diag::Schema));
        }
    }
    Ok(())
}

fn require_bytes<'a>(map: &'a CborMap, key: &str) -> GrainResult<&'a [u8]> {
    require(map, key)?
        .as_bytes()
        .ok_or_else(|| GrainError::from_diag(Diag::Schema))
}

fn require_bytes_len(map: &CborMap, key: &str, expected_len: usize) -> GrainResult<()> {
    if require_bytes(map, key)?.len() != expected_len {
        return Err(GrainError::from_diag(Diag::Schema));
    }
    Ok(())
}

fn optional_bytes(map: &CborMap, key: &str) -> GrainResult<()> {
    if let Some(value) = map_find(map, key) {
        if value.as_bytes().is_none() {
            return Err(GrainError::from_diag(Diag::Schema));
        }
    }
    Ok(())
}

fn expect_int64(value: &CborValue) -> GrainResult<()> {
    match value {
        CborValue::Unsigned(value) if *value <= i64::MAX as u64 => Ok(()),
        CborValue::Negative(value) if *value >= i64::MIN as i128 => Ok(()),
        _ => Err(GrainError::from_diag(Diag::Schema)),
    }
}

fn expect_nonnegative_int64(value: &CborValue) -> GrainResult<()> {
    match value {
        CborValue::Unsigned(value) if *value <= i64::MAX as u64 => Ok(()),
        _ => Err(GrainError::from_diag(Diag::Schema)),
    }
}

fn expect_uint63(value: &CborValue) -> GrainResult<()> {
    expect_nonnegative_int64(value)
}

fn optional_int64(map: &CborMap, key: &str) -> GrainResult<()> {
    if let Some(value) = map_find(map, key) {
        expect_int64(value)?;
    }
    Ok(())
}

fn require_nonnegative_int64(map: &CborMap, key: &str) -> GrainResult<()> {
    expect_nonnegative_int64(require(map, key)?)
}

fn optional_nonnegative_int64(map: &CborMap, key: &str) -> GrainResult<()> {
    if let Some(value) = map_find(map, key) {
        expect_nonnegative_int64(value)?;
    }
    Ok(())
}

fn require_uint63(map: &CborMap, key: &str) -> GrainResult<()> {
    expect_uint63(require(map, key)?)
}

fn optional_uint63(map: &CborMap, key: &str) -> GrainResult<()> {
    if let Some(value) = map_find(map, key) {
        expect_uint63(value)?;
    }
    Ok(())
}

fn forbid_fields(map: &CborMap, fields: &[&str]) -> GrainResult<()> {
    if fields.iter().any(|field| map_has(map, field)) {
        return Err(GrainError::from_diag(Diag::Schema));
    }
    Ok(())
}
