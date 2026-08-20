use std::collections::BTreeSet;

use crate::cbor::{parse_exact_to_error, CborValue, ParseOptions};
use crate::error::{Diag, GrainError, GrainResult};
use crate::limits::Limits;
use crate::object_schema::schema_for_legacy_t;
use crate::typed_object::validate_typed_object_v1;

pub fn validate_strict_dagcbor(bytes: &[u8]) -> GrainResult<CborValue> {
    let value = parse_strict_dagcbor_encoding(bytes)?;
    validate_schema_level(&value)?;
    Ok(value)
}

pub(crate) fn parse_strict_dagcbor_encoding(bytes: &[u8]) -> GrainResult<CborValue> {
    if bytes.len() > Limits::STRICT_BASELINE.max_dagcbor_object_bytes {
        return Err(GrainError::from_diag(Diag::Limit));
    }

    parse_exact_to_error(bytes, ParseOptions::strict_dag_cbor())
}

pub fn validate_serving_offer_payload(
    payload: &[u8],
    expected_issuer_kid: &[u8],
) -> GrainResult<CborValue> {
    if expected_issuer_kid.len() != 16 {
        return Err(GrainError::from_diag(Diag::Schema));
    }

    let value = validate_typed_object_v1(payload, "ServingOffer")?;
    match value.map_get("issuer_kid").and_then(CborValue::as_bytes) {
        Some(kid) if kid == expected_issuer_kid => {}
        _ => return Err(GrainError::from_diag(Diag::Schema)),
    }

    Ok(value)
}

fn validate_schema_level(value: &CborValue) -> GrainResult<()> {
    let Some(map) = value.as_map() else {
        return Ok(());
    };

    let t = map_find_text(map, "t");
    if let Some(t) = t {
        if let Some(schema) = schema_for_legacy_t(&t) {
            for (k, _) in map {
                let Some(key) = k.as_text() else {
                    return Err(GrainError::from_diag(Diag::NonCanonical));
                };
                if !schema.allowed_top_level_keys.contains(&key.as_str()) {
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

pub(crate) fn validate_tstr_set_array(value: &CborValue, is_crit: bool) -> GrainResult<()> {
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
        let bytes = encode(CborValue::Map(vec![(
            CborValue::Unsigned(1),
            CborValue::Text(b"IngredientRef".to_vec()),
        )]));

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

    fn serving_offer_payload(kid: &[u8]) -> Vec<u8> {
        encode(CborValue::Map(vec![
            (CborValue::Text(b"v".to_vec()), CborValue::Unsigned(1)),
            (
                CborValue::Text(b"t".to_vec()),
                CborValue::Text(b"ServingOffer".to_vec()),
            ),
            (
                CborValue::Text(b"issuer_kid".to_vec()),
                CborValue::Bytes(kid.to_vec()),
            ),
            (
                CborValue::Text(b"serving_g".to_vec()),
                CborValue::Unsigned(250),
            ),
            (
                CborValue::Text(b"mean".to_vec()),
                CborValue::Map(Vec::new()),
            ),
            (CborValue::Text(b"var".to_vec()), CborValue::Map(Vec::new())),
        ]))
    }

    #[test]
    fn serving_offer_payload_accepts_required_profile_shape() {
        let kid = [7u8; 16];
        let value = validate_serving_offer_payload(&serving_offer_payload(&kid), &kid).unwrap();

        assert_eq!(
            value.map_get("t").and_then(CborValue::as_text_bytes),
            Some(&b"ServingOffer"[..])
        );
    }

    #[test]
    fn serving_offer_payload_rejects_wrong_object_type() {
        let bytes = encode(CborValue::Map(vec![
            (
                CborValue::Text(b"t".to_vec()),
                CborValue::Text(b"IngredientRef".to_vec()),
            ),
            (CborValue::Text(b"v".to_vec()), CborValue::Unsigned(1)),
        ]));

        let err = validate_serving_offer_payload(&bytes, &[7u8; 16]).unwrap_err();

        assert_eq!(err.diag(), Diag::Schema);
    }

    #[test]
    fn serving_offer_payload_rejects_issuer_kid_mismatch() {
        let err = validate_serving_offer_payload(&serving_offer_payload(&[7u8; 16]), &[8u8; 16])
            .unwrap_err();

        assert_eq!(err.diag(), Diag::Schema);
    }

    #[test]
    fn serving_offer_payload_rejects_missing_required_fields() {
        let bytes = encode(CborValue::Map(vec![
            (CborValue::Text(b"v".to_vec()), CborValue::Unsigned(1)),
            (
                CborValue::Text(b"t".to_vec()),
                CborValue::Text(b"ServingOffer".to_vec()),
            ),
            (
                CborValue::Text(b"issuer_kid".to_vec()),
                CborValue::Bytes(vec![7u8; 16]),
            ),
        ]));

        let err = validate_serving_offer_payload(&bytes, &[7u8; 16]).unwrap_err();

        assert_eq!(err.diag(), Diag::Schema);
    }
}
