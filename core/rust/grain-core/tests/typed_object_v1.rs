use base64::engine::general_purpose::STANDARD;
use base64::Engine;
use grain_core::cbor::{encode_canonical, CborValue};
use grain_core::execute_operation;
use grain_core::typed_object::validate_typed_object_v1;
use serde_json::json;

fn text(value: &str) -> CborValue {
    CborValue::Text(value.as_bytes().to_vec())
}

fn bytes(len: usize, fill: u8) -> CborValue {
    CborValue::Bytes(vec![fill; len])
}

fn map(entries: Vec<(&str, CborValue)>) -> CborValue {
    CborValue::Map(
        entries
            .into_iter()
            .map(|(key, value)| (text(key), value))
            .collect(),
    )
}

fn encode(value: &CborValue) -> Vec<u8> {
    let mut out = Vec::new();
    encode_canonical(value, &mut out);
    out
}

fn cid_link(fill: u8) -> CborValue {
    let mut bytes = vec![0x00, 0x01, 0x71, 0x12, 0x20];
    bytes.extend_from_slice(&[fill; 32]);
    CborValue::Tag(42, Box::new(CborValue::Bytes(bytes)))
}

fn base(t: &str, mut fields: Vec<(&str, CborValue)>) -> CborValue {
    let mut entries = vec![("v", CborValue::Unsigned(1)), ("t", text(t))];
    entries.append(&mut fields);
    map(entries)
}

fn nutrient_map(value: CborValue) -> CborValue {
    map(vec![("kcal", value)])
}

fn cook_input(fill: u8, amount: u64) -> CborValue {
    map(vec![
        ("ing", cid_link(fill)),
        ("amount_g", CborValue::Unsigned(amount)),
    ])
}

fn map_decision(fill: u8) -> CborValue {
    map(vec![
        ("ing", cid_link(fill)),
        ("profile", cid_link(fill.wrapping_add(1))),
    ])
}

fn valid_object(object_type: &str) -> CborValue {
    match object_type {
        "IngredientRef" => base(
            "IngredientRef",
            vec![("ref_type", text("local")), ("ref_id", text("apple"))],
        ),
        "NutrientProfile" => base(
            "NutrientProfile",
            vec![
                ("dataset_snapshot_id", text("snapshot-1")),
                ("source", text("test")),
                ("basis", text("per_100g")),
                ("nutr", nutrient_map(CborValue::Unsigned(52))),
                ("uncert", nutrient_map(CborValue::Unsigned(1))),
            ],
        ),
        "CookRun" => base(
            "CookRun",
            vec![
                ("inputs", CborValue::Array(vec![cook_input(1, 100)])),
                ("yield_g", CborValue::Unsigned(90)),
                ("ts_ms", CborValue::Negative(-1)),
            ],
        ),
        "NutritionComputeResult" => base(
            "NutritionComputeResult",
            vec![
                ("cookrun", cid_link(2)),
                ("engine_id", text("engine")),
                ("engine_version", text("1")),
                ("dataset_snapshot_id", text("snapshot-1")),
                ("map", CborValue::Array(vec![map_decision(3)])),
                ("out", nutrient_map(CborValue::Unsigned(100))),
            ],
        ),
        "IntakeEvent" => base(
            "IntakeEvent",
            vec![
                ("source_class", text("estimated")),
                ("mean", nutrient_map(CborValue::Unsigned(100))),
                ("var", nutrient_map(CborValue::Unsigned(4))),
                ("mode", text("from_ingredient")),
                ("ing", cid_link(4)),
                ("amount_g", CborValue::Unsigned(125)),
            ],
        ),
        "ServingOffer" => base(
            "ServingOffer",
            vec![
                ("issuer_kid", bytes(16, 5)),
                ("serving_g", CborValue::Unsigned(250)),
                ("mean", nutrient_map(CborValue::Unsigned(200))),
                ("var", nutrient_map(CborValue::Unsigned(9))),
                ("nonce", bytes(0, 0)),
            ],
        ),
        "LedgerGenesis" => base(
            "LedgerGenesis",
            vec![("root_kid", bytes(16, 6)), ("root_pub", bytes(32, 7))],
        ),
        "DeviceKeyGrant" => base(
            "DeviceKeyGrant",
            vec![
                ("ak", bytes(16, 8)),
                ("pub", bytes(32, 9)),
                ("caps", CborValue::Array(vec![text("read"), text("write")])),
            ],
        ),
        "DeviceKeyRevoke" => base("DeviceKeyRevoke", vec![("ak", bytes(16, 10))]),
        "VoidEvent" => base(
            "VoidEvent",
            vec![
                (
                    "target",
                    map(vec![("ak", bytes(16, 11)), ("seq", CborValue::Unsigned(2))]),
                ),
                ("reason", text("duplicate")),
            ],
        ),
        "CorrectionEvent" => base(
            "CorrectionEvent",
            vec![(
                "target",
                map(vec![("ak", bytes(16, 12)), ("seq", CborValue::Unsigned(3))]),
            )],
        ),
        "LedgerEvent" => base(
            "CustomDomainEvent",
            vec![
                ("ak", bytes(16, 13)),
                ("seq", CborValue::Unsigned(4)),
                ("body", CborValue::Null),
            ],
        ),
        "EncryptedObject" => base(
            "EncryptedObject",
            vec![
                ("alg", text("A256GCM")),
                ("cap_id", bytes(32, 14)),
                ("nonce", bytes(12, 15)),
                ("ct", bytes(1, 16)),
            ],
        ),
        "ManifestRecord" => base(
            "ManifestRecord",
            vec![
                ("ak", bytes(16, 17)),
                ("seq", CborValue::Unsigned(5)),
                ("cid", cid_link(18)),
                ("op", text("put")),
                ("cap_id", bytes(32, 19)),
                ("chash", bytes(32, 20)),
                ("size", CborValue::Unsigned(1)),
            ],
        ),
        other => panic!("unknown test object type {other}"),
    }
}

fn assert_diag(object_type: &str, value: &CborValue, expected: &str) {
    let err = validate_typed_object_v1(&encode(value), object_type).unwrap_err();
    assert_eq!(err.diag().code(), expected, "object type {object_type}");
}

fn remove_field(value: &CborValue, field: &str) -> CborValue {
    let CborValue::Map(entries) = value else {
        panic!("test object must be a map");
    };
    CborValue::Map(
        entries
            .iter()
            .filter(|(key, _)| key.as_text_bytes() != Some(field.as_bytes()))
            .cloned()
            .collect(),
    )
}

fn replace_field(value: &CborValue, field: &str, replacement: CborValue) -> CborValue {
    let CborValue::Map(entries) = value else {
        panic!("test object must be a map");
    };
    CborValue::Map(
        entries
            .iter()
            .map(|(key, value)| {
                if key.as_text_bytes() == Some(field.as_bytes()) {
                    (key.clone(), replacement.clone())
                } else {
                    (key.clone(), value.clone())
                }
            })
            .collect(),
    )
}

fn append_field(value: &CborValue, field: &str, field_value: CborValue) -> CborValue {
    let CborValue::Map(entries) = value else {
        panic!("test object must be a map");
    };
    let mut entries = entries.clone();
    entries.push((text(field), field_value));
    CborValue::Map(entries)
}

#[test]
fn accepts_all_fourteen_cddl_productions() {
    let object_types = [
        "IngredientRef",
        "NutrientProfile",
        "CookRun",
        "NutritionComputeResult",
        "IntakeEvent",
        "ServingOffer",
        "LedgerGenesis",
        "DeviceKeyGrant",
        "DeviceKeyRevoke",
        "VoidEvent",
        "CorrectionEvent",
        "LedgerEvent",
        "EncryptedObject",
        "ManifestRecord",
    ];
    for object_type in object_types {
        validate_typed_object_v1(&encode(&valid_object(object_type)), object_type).unwrap();
    }
}

#[test]
fn optional_object_type_preserves_legacy_observable_path() {
    let incomplete = base("IngredientRef", Vec::new());
    let bytes_b64 = STANDARD.encode(encode(&incomplete));

    let legacy = execute_operation("dagcbor_validate", &json!({ "bytes_b64": bytes_b64 }), true);
    assert!(legacy.accepted);

    let typed = execute_operation(
        "dagcbor_validate",
        &json!({ "bytes_b64": bytes_b64, "object_type": "IngredientRef" }),
        true,
    );
    assert!(!typed.accepted);
    assert_eq!(typed.diag, vec!["GRAIN_ERR_SCHEMA"]);
}

#[test]
fn unknown_selector_preserves_encoding_diagnostic_precedence() {
    let err = validate_typed_object_v1(&[0x18, 0x01], "FutureObject").unwrap_err();
    assert_eq!(err.diag().code(), "GRAIN_ERR_NONCANONICAL");

    let canonical = encode(&base("FutureObject", Vec::new()));
    let err = validate_typed_object_v1(&canonical, "FutureObject").unwrap_err();
    assert_eq!(err.diag().code(), "GRAIN_ERR_SCHEMA");
}

#[test]
fn rejects_every_missing_required_field() {
    let cases: &[(&str, &[(&str, &str)])] = &[
        (
            "IngredientRef",
            &[
                ("v", "GRAIN_ERR_SCHEMA"),
                ("t", "GRAIN_ERR_SCHEMA"),
                ("ref_type", "GRAIN_ERR_SCHEMA"),
                ("ref_id", "GRAIN_ERR_SCHEMA"),
            ],
        ),
        (
            "NutrientProfile",
            &[
                ("v", "GRAIN_ERR_SCHEMA"),
                ("t", "GRAIN_ERR_SCHEMA"),
                ("dataset_snapshot_id", "GRAIN_ERR_SCHEMA"),
                ("source", "GRAIN_ERR_SCHEMA"),
                ("basis", "GRAIN_ERR_SCHEMA"),
                ("nutr", "GRAIN_ERR_SCHEMA"),
            ],
        ),
        (
            "CookRun",
            &[
                ("v", "GRAIN_ERR_SCHEMA"),
                ("t", "GRAIN_ERR_SCHEMA"),
                ("inputs", "GRAIN_ERR_SCHEMA"),
            ],
        ),
        (
            "NutritionComputeResult",
            &[
                ("v", "GRAIN_ERR_SCHEMA"),
                ("t", "GRAIN_ERR_SCHEMA"),
                ("cookrun", "GRAIN_ERR_SCHEMA"),
                ("engine_id", "GRAIN_ERR_SCHEMA"),
                ("engine_version", "GRAIN_ERR_SCHEMA"),
                ("dataset_snapshot_id", "GRAIN_ERR_SCHEMA"),
                ("map", "GRAIN_ERR_SCHEMA"),
                ("out", "GRAIN_ERR_SCHEMA"),
            ],
        ),
        (
            "IntakeEvent",
            &[
                ("v", "GRAIN_ERR_SCHEMA"),
                ("t", "GRAIN_ERR_SCHEMA"),
                ("source_class", "GRAIN_ERR_SCHEMA"),
                ("mean", "GRAIN_ERR_SCHEMA"),
                ("var", "GRAIN_ERR_SCHEMA"),
                ("mode", "GRAIN_ERR_SCHEMA"),
                ("ing", "GRAIN_ERR_SCHEMA"),
                ("amount_g", "GRAIN_ERR_SCHEMA"),
            ],
        ),
        (
            "ServingOffer",
            &[
                ("v", "GRAIN_ERR_SCHEMA"),
                ("t", "GRAIN_ERR_SCHEMA"),
                ("issuer_kid", "GRAIN_ERR_SCHEMA"),
                ("serving_g", "GRAIN_ERR_SCHEMA"),
                ("mean", "GRAIN_ERR_SCHEMA"),
                ("var", "GRAIN_ERR_SCHEMA"),
            ],
        ),
        (
            "LedgerGenesis",
            &[
                ("v", "GRAIN_ERR_SCHEMA"),
                ("t", "GRAIN_ERR_SCHEMA"),
                ("root_kid", "GRAIN_ERR_SCHEMA"),
                ("root_pub", "GRAIN_ERR_SCHEMA"),
            ],
        ),
        (
            "DeviceKeyGrant",
            &[
                ("v", "GRAIN_ERR_SCHEMA"),
                ("t", "GRAIN_ERR_SCHEMA"),
                ("ak", "GRAIN_ERR_SCHEMA"),
                ("pub", "GRAIN_ERR_SCHEMA"),
                ("caps", "GRAIN_ERR_SCHEMA"),
            ],
        ),
        (
            "DeviceKeyRevoke",
            &[
                ("v", "GRAIN_ERR_SCHEMA"),
                ("t", "GRAIN_ERR_SCHEMA"),
                ("ak", "GRAIN_ERR_SCHEMA"),
            ],
        ),
        (
            "VoidEvent",
            &[
                ("v", "GRAIN_ERR_SCHEMA"),
                ("t", "GRAIN_ERR_SCHEMA"),
                ("target", "GRAIN_ERR_SCHEMA"),
            ],
        ),
        (
            "CorrectionEvent",
            &[
                ("v", "GRAIN_ERR_SCHEMA"),
                ("t", "GRAIN_ERR_SCHEMA"),
                ("target", "GRAIN_ERR_SCHEMA"),
            ],
        ),
        (
            "LedgerEvent",
            &[
                ("v", "GRAIN_ERR_SCHEMA"),
                ("t", "GRAIN_ERR_SCHEMA"),
                ("ak", "GRAIN_ERR_SCHEMA"),
                ("seq", "GRAIN_ERR_SCHEMA"),
                ("body", "GRAIN_ERR_SCHEMA"),
            ],
        ),
        (
            "EncryptedObject",
            &[
                ("v", "GRAIN_ERR_SCHEMA"),
                ("t", "GRAIN_ERR_SCHEMA"),
                ("alg", "GRAIN_ERR_SCHEMA"),
                ("cap_id", "GRAIN_ERR_SCHEMA"),
                ("nonce", "GRAIN_ERR_SCHEMA"),
                ("ct", "GRAIN_ERR_SCHEMA"),
            ],
        ),
        (
            "ManifestRecord",
            &[
                ("v", "GRAIN_ERR_SCHEMA"),
                ("t", "GRAIN_ERR_SCHEMA"),
                ("ak", "GRAIN_ERR_SCHEMA"),
                ("seq", "GRAIN_ERR_SCHEMA"),
                ("cid", "GRAIN_ERR_SCHEMA"),
                ("op", "GRAIN_ERR_MANIFEST_OP"),
                ("cap_id", "GRAIN_ERR_MANIFEST_OP"),
                ("chash", "GRAIN_ERR_MANIFEST_OP"),
            ],
        ),
    ];

    for (object_type, required_fields) in cases {
        let valid = valid_object(object_type);
        for (field, expected) in *required_fields {
            assert_diag(object_type, &remove_field(&valid, field), expected);
        }
    }
}

#[test]
fn enforces_envelope_closure_and_numeric_domains() {
    let ingredient = valid_object("IngredientRef");
    assert_diag(
        "IngredientRef",
        &replace_field(&ingredient, "v", CborValue::Unsigned(2)),
        "GRAIN_ERR_SCHEMA",
    );
    assert_diag(
        "IngredientRef",
        &replace_field(&ingredient, "t", text("CookRun")),
        "GRAIN_ERR_SCHEMA",
    );
    assert_diag(
        "IngredientRef",
        &append_field(&ingredient, "bogus", CborValue::Null),
        "GRAIN_ERR_UNKNOWN_TOPLEVEL_KEY",
    );

    let ledger = valid_object("LedgerEvent");
    assert_diag(
        "LedgerEvent",
        &replace_field(&ledger, "seq", CborValue::Unsigned(i64::MAX as u64 + 1)),
        "GRAIN_ERR_SCHEMA",
    );

    let intake = valid_object("IntakeEvent");
    assert_diag(
        "IntakeEvent",
        &replace_field(&intake, "amount_g", CborValue::Negative(-1)),
        "GRAIN_ERR_SCHEMA",
    );
    assert_diag(
        "IntakeEvent",
        &replace_field(&intake, "var", nutrient_map(CborValue::Negative(-1))),
        "GRAIN_ERR_SCHEMA",
    );

    let profile = valid_object("NutrientProfile");
    assert_diag(
        "NutrientProfile",
        &replace_field(&profile, "uncert", nutrient_map(CborValue::Negative(-1))),
        "GRAIN_ERR_SCHEMA",
    );
}

#[test]
fn enforces_full_blessed_cid_link_profile_recursively() {
    let ingredient = valid_object("IngredientRef");
    let mut invalid = vec![0x00, 0x02, 0x71, 0x12, 0x20];
    invalid.extend_from_slice(&[0; 32]);
    let ext = map(vec![(
        "nested",
        CborValue::Tag(42, Box::new(CborValue::Bytes(invalid))),
    )]);
    assert_diag(
        "IngredientRef",
        &append_field(&ingredient, "ext", ext),
        "GRAIN_ERR_BAD_CID_LINK",
    );

    let intake = valid_object("IntakeEvent");
    let mut trailing = vec![0x00, 0x01, 0x71, 0x12, 0x20];
    trailing.extend_from_slice(&[0; 33]);
    assert_diag(
        "IntakeEvent",
        &replace_field(
            &intake,
            "ing",
            CborValue::Tag(42, Box::new(CborValue::Bytes(trailing))),
        ),
        "GRAIN_ERR_BAD_CID_LINK",
    );
}

#[test]
fn enforces_structured_and_text_set_arrays() {
    let mut inputs = vec![cook_input(1, 10), cook_input(2, 20)];
    inputs.sort_by_key(encode);
    inputs.reverse();
    let cook_run = replace_field(&valid_object("CookRun"), "inputs", CborValue::Array(inputs));
    assert_diag("CookRun", &cook_run, "GRAIN_ERR_SET_ARRAY_ORDER");

    let duplicate = cook_input(3, 30);
    let cook_run = replace_field(
        &valid_object("CookRun"),
        "inputs",
        CborValue::Array(vec![duplicate.clone(), duplicate]),
    );
    assert_diag("CookRun", &cook_run, "GRAIN_ERR_SET_ARRAY_DUP");

    let grant = replace_field(
        &valid_object("DeviceKeyGrant"),
        "caps",
        CborValue::Array(vec![text("write"), text("read")]),
    );
    assert_diag("DeviceKeyGrant", &grant, "GRAIN_ERR_SET_ARRAY_ORDER");
}

#[test]
fn enforces_intake_union_and_food_profile_vocabularies() {
    let intake = valid_object("IntakeEvent");
    assert_diag(
        "IntakeEvent",
        &replace_field(&intake, "source_class", text("guessed")),
        "GRAIN_ERR_SCHEMA",
    );
    assert_diag(
        "IntakeEvent",
        &append_field(&intake, "profile", cid_link(21)),
        "GRAIN_ERR_SCHEMA",
    );
    assert_diag(
        "IntakeEvent",
        &replace_field(&intake, "mode", text("from_unknown")),
        "GRAIN_ERR_SCHEMA",
    );
}

#[test]
fn enforces_manifest_conditional_diagnostics() {
    let manifest = valid_object("ManifestRecord");
    assert_diag(
        "ManifestRecord",
        &replace_field(&manifest, "op", CborValue::Unsigned(1)),
        "GRAIN_ERR_MANIFEST_OP",
    );
    assert_diag(
        "ManifestRecord",
        &replace_field(&manifest, "op", text("update")),
        "GRAIN_ERR_MANIFEST_OP",
    );
    let unknown_op_and_bad_ak = replace_field(
        &replace_field(&manifest, "op", text("update")),
        "ak",
        bytes(1, 1),
    );
    assert_diag(
        "ManifestRecord",
        &unknown_op_and_bad_ak,
        "GRAIN_ERR_MANIFEST_OP",
    );
    let missing_branch_and_bad_ak =
        replace_field(&remove_field(&manifest, "cap_id"), "ak", bytes(1, 1));
    assert_diag(
        "ManifestRecord",
        &missing_branch_and_bad_ak,
        "GRAIN_ERR_MANIFEST_OP",
    );
    assert_diag(
        "ManifestRecord",
        &replace_field(&manifest, "cap_id", bytes(31, 1)),
        "GRAIN_ERR_SCHEMA",
    );
    assert_diag(
        "ManifestRecord",
        &replace_field(&manifest, "ak", bytes(1, 1)),
        "GRAIN_ERR_SCHEMA",
    );

    let del = replace_field(&manifest, "op", text("del"));
    assert_diag("ManifestRecord", &del, "GRAIN_ERR_MANIFEST_OP");

    let valid_del = replace_field(
        &remove_field(
            &remove_field(&remove_field(&manifest, "cap_id"), "chash"),
            "size",
        ),
        "op",
        text("del"),
    );
    validate_typed_object_v1(&encode(&valid_del), "ManifestRecord").unwrap();
}

#[test]
fn enforces_ext_crit_and_context_limits() {
    let ingredient = append_field(
        &valid_object("IngredientRef"),
        "ext",
        map(vec![("blob", bytes(65_536, 1))]),
    );
    assert_diag("IngredientRef", &ingredient, "GRAIN_ERR_LIMIT");

    let ingredient = append_field(
        &valid_object("IngredientRef"),
        "crit",
        CborValue::Array(vec![text("z"), text("a")]),
    );
    assert_diag("IngredientRef", &ingredient, "GRAIN_ERR_SET_ARRAY_ORDER");

    let serving = append_field(
        &valid_object("ServingOffer"),
        "ext",
        map(vec![("padding", bytes(2_048, 2))]),
    );
    assert_diag("ServingOffer", &serving, "GRAIN_ERR_LIMIT");
}
