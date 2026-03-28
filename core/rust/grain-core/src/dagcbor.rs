use std::collections::BTreeSet;

use crate::cbor::{parse_exact_to_error, CborValue, ParseOptions};
use crate::error::{Diag, GrainError, GrainResult};
use crate::limits::Limits;

pub fn validate_strict_dagcbor(bytes: &[u8]) -> GrainResult<CborValue> {
    if bytes.len() > Limits::STRICT_BASELINE.max_dagcbor_object_bytes {
        return Err(GrainError::from_diag(Diag::Limit));
    }

    let value = parse_exact_to_error(bytes, ParseOptions::strict_dag_cbor())?;
    validate_schema_level(&value)?;
    Ok(value)
}

fn validate_schema_level(value: &CborValue) -> GrainResult<()> {
    let Some(map) = value.as_map() else {
        return Ok(());
    };

    let t = map_find_text(map, "t");
    if let Some(t) = t {
        if let Some(allowed) = allowed_top_level_keys(&t) {
            for (k, _) in map {
                let Some(key) = k.as_text() else {
                    return Err(GrainError::from_diag(Diag::NonCanonical));
                };
                if !allowed.contains(&key.as_str()) {
                    return Err(GrainError::from_diag(Diag::UnknownTopLevelKey));
                }
            }
        }

        if let Some(crit) = map_find(map, "crit") {
            validate_tstr_set_array(crit, true)?;
        }

        if t == "DeviceKeyGrant" {
            if let Some(caps) = map_find(map, "caps") {
                validate_tstr_set_array(caps, false)?;
            }
        }
    }

    Ok(())
}

fn map_find<'a>(map: &'a [(CborValue, CborValue)], key: &str) -> Option<&'a CborValue> {
    for (k, v) in map {
        if k.as_text_bytes() == Some(key.as_bytes()) {
            return Some(v);
        }
    }
    None
}

fn map_find_text(map: &[(CborValue, CborValue)], key: &str) -> Option<String> {
    map_find(map, key).and_then(|v| v.as_text())
}

fn validate_tstr_set_array(value: &CborValue, is_crit: bool) -> GrainResult<()> {
    let CborValue::Array(items) = value else {
        return Err(GrainError::from_diag(Diag::Schema));
    };

    if is_crit {
        if items.len() > Limits::STRICT_BASELINE.max_crit_entries {
            return Err(GrainError::from_diag(Diag::Limit));
        }
        let mut total: usize = 0;
        for item in items {
            let Some(b) = item.as_text_bytes() else {
                return Err(GrainError::from_diag(Diag::Schema));
            };
            total = total.saturating_add(b.len());
        }
        if total > Limits::STRICT_BASELINE.max_crit_total_utf8_bytes {
            return Err(GrainError::from_diag(Diag::Limit));
        }
    }

    let mut prev: Option<Vec<u8>> = None;
    let mut seen: BTreeSet<Vec<u8>> = BTreeSet::new();

    for item in items {
        let Some(cur) = item.as_text_bytes().map(|s| s.to_vec()) else {
            return Err(GrainError::from_diag(Diag::Schema));
        };

        if let Some(p) = &prev {
            if p > &cur {
                return Err(GrainError::from_diag(Diag::SetArrayOrder));
            }
            if p == &cur {
                return Err(GrainError::from_diag(Diag::SetArrayDup));
            }
        }

        if !seen.insert(cur.clone()) {
            return Err(GrainError::from_diag(Diag::SetArrayDup));
        }

        prev = Some(cur);
    }

    Ok(())
}

fn allowed_top_level_keys(t: &str) -> Option<&'static [&'static str]> {
    match t {
        "IngredientRef" => Some(&[
            "v",
            "t",
            "ref_type",
            "ref_id",
            "ref_version",
            "name",
            "ext",
            "crit",
        ]),
        "NutrientProfile" => Some(&[
            "v",
            "t",
            "dataset_snapshot_id",
            "source",
            "basis",
            "nutr",
            "uncert",
            "ext",
            "crit",
        ]),
        "CookRun" => Some(&["v", "t", "inputs", "yield_g", "ts_ms", "ext", "crit"]),
        "NutritionComputeResult" => Some(&[
            "v",
            "t",
            "cookrun",
            "engine_id",
            "engine_version",
            "dataset_snapshot_id",
            "map",
            "out",
            "ext",
            "crit",
        ]),
        "IntakeEvent" => Some(&[
            "v",
            "t",
            "source_class",
            "mean",
            "var",
            "mode",
            "cookrun",
            "amount_g",
            "ing",
            "profile",
            "servings",
            "ts_ms",
            "ext",
            "crit",
        ]),
        "ServingOffer" => Some(&[
            "v",
            "t",
            "issuer_kid",
            "serving_g",
            "mean",
            "var",
            "nonce",
            "ext",
            "crit",
        ]),
        "LedgerGenesis" => Some(&["v", "t", "root_kid", "root_pub", "ext", "crit"]),
        "DeviceKeyGrant" => Some(&["v", "t", "ak", "pub", "caps", "ext", "crit"]),
        "DeviceKeyRevoke" => Some(&["v", "t", "ak", "ext", "crit"]),
        "VoidEvent" => Some(&["v", "t", "target", "reason", "ext", "crit"]),
        "CorrectionEvent" => Some(&["v", "t", "target", "reason", "ext", "crit"]),
        "LedgerEvent" => Some(&["v", "t", "ak", "seq", "ts_ms", "body", "ext", "crit"]),
        "EncryptedObject" => Some(&["v", "t", "alg", "cap_id", "nonce", "ct", "ext", "crit"]),
        "ManifestRecord" => Some(&[
            "v", "t", "ak", "seq", "cid", "op", "cap_id", "chash", "size", "ext", "crit",
        ]),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::cbor::{encode_canonical, CborValue};

    fn encode(value: CborValue) -> Vec<u8> {
        let mut out = Vec::new();
        encode_canonical(&value, &mut out);
        out
    }

    #[test]
    fn accepts_known_top_level_shape() {
        let bytes = encode(CborValue::Map(vec![
            (
                CborValue::Text(b"t".to_vec()),
                CborValue::Text(b"IngredientRef".to_vec()),
            ),
            (CborValue::Text(b"v".to_vec()), CborValue::Unsigned(1)),
        ]));

        let value = validate_strict_dagcbor(&bytes).unwrap();
        assert!(matches!(value, CborValue::Map(_)));
    }

    #[test]
    fn rejects_non_text_top_level_key() {
        let bytes = encode(CborValue::Map(vec![
            (
                CborValue::Unsigned(1),
                CborValue::Text(b"IngredientRef".to_vec()),
            ),
        ]));

        let err = validate_strict_dagcbor(&bytes).unwrap_err();
        assert_eq!(err.diag(), Diag::NonCanonical);
    }

    #[test]
    fn rejects_unknown_top_level_key() {
        let bytes = encode(CborValue::Map(vec![
            (
                CborValue::Text(b"t".to_vec()),
                CborValue::Text(b"IngredientRef".to_vec()),
            ),
            (CborValue::Text(b"v".to_vec()), CborValue::Unsigned(1)),
            (CborValue::Text(b"bogus".to_vec()), CborValue::Unsigned(2)),
        ]));

        let err = validate_strict_dagcbor(&bytes).unwrap_err();
        assert_eq!(err.diag(), Diag::UnknownTopLevelKey);
    }
}
