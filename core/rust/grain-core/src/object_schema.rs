#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ObjectTypeV1 {
    IngredientRef,
    NutrientProfile,
    CookRun,
    NutritionComputeResult,
    IntakeEvent,
    ServingOffer,
    LedgerGenesis,
    DeviceKeyGrant,
    DeviceKeyRevoke,
    VoidEvent,
    CorrectionEvent,
    LedgerEvent,
    EncryptedObject,
    ManifestRecord,
}

impl ObjectTypeV1 {
    const fn selector_name(self) -> &'static str {
        match self {
            Self::IngredientRef => "IngredientRef",
            Self::NutrientProfile => "NutrientProfile",
            Self::CookRun => "CookRun",
            Self::NutritionComputeResult => "NutritionComputeResult",
            Self::IntakeEvent => "IntakeEvent",
            Self::ServingOffer => "ServingOffer",
            Self::LedgerGenesis => "LedgerGenesis",
            Self::DeviceKeyGrant => "DeviceKeyGrant",
            Self::DeviceKeyRevoke => "DeviceKeyRevoke",
            Self::VoidEvent => "VoidEvent",
            Self::CorrectionEvent => "CorrectionEvent",
            Self::LedgerEvent => "LedgerEvent",
            Self::EncryptedObject => "EncryptedObject",
            Self::ManifestRecord => "ManifestRecord",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PayloadLimitV1 {
    DagCborObject,
    LedgerEvent,
    ManifestRecord,
    ServingOffer,
    EncryptedObject,
}

#[derive(Debug)]
pub struct ObjectSchemaV1 {
    pub object_type: ObjectTypeV1,
    pub name: &'static str,
    /// Most CDDL productions fix `t` to the production name. `LedgerEvent`
    /// instead carries the concrete event type as an arbitrary tstr.
    pub literal_t: Option<&'static str>,
    pub allowed_top_level_keys: &'static [&'static str],
    pub payload_limit: PayloadLimitV1,
}

const INGREDIENT_REF_KEYS: &[&str] = &[
    "v",
    "t",
    "ref_type",
    "ref_id",
    "ref_version",
    "name",
    "ext",
    "crit",
];
const NUTRIENT_PROFILE_KEYS: &[&str] = &[
    "v",
    "t",
    "dataset_snapshot_id",
    "source",
    "basis",
    "nutr",
    "uncert",
    "ext",
    "crit",
];
const COOK_RUN_KEYS: &[&str] = &["v", "t", "inputs", "yield_g", "ts_ms", "ext", "crit"];
const NUTRITION_COMPUTE_RESULT_KEYS: &[&str] = &[
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
];
const INTAKE_EVENT_KEYS: &[&str] = &[
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
];
const SERVING_OFFER_KEYS: &[&str] = &[
    "v",
    "t",
    "issuer_kid",
    "serving_g",
    "mean",
    "var",
    "nonce",
    "ext",
    "crit",
];
const LEDGER_GENESIS_KEYS: &[&str] = &["v", "t", "root_kid", "root_pub", "ext", "crit"];
const DEVICE_KEY_GRANT_KEYS: &[&str] = &["v", "t", "ak", "pub", "caps", "ext", "crit"];
const DEVICE_KEY_REVOKE_KEYS: &[&str] = &["v", "t", "ak", "ext", "crit"];
const VOID_EVENT_KEYS: &[&str] = &["v", "t", "target", "reason", "ext", "crit"];
const CORRECTION_EVENT_KEYS: &[&str] = VOID_EVENT_KEYS;
const LEDGER_EVENT_KEYS: &[&str] = &["v", "t", "ak", "seq", "ts_ms", "body", "ext", "crit"];
const ENCRYPTED_OBJECT_KEYS: &[&str] = &["v", "t", "alg", "cap_id", "nonce", "ct", "ext", "crit"];
const MANIFEST_RECORD_KEYS: &[&str] = &[
    "v", "t", "ak", "seq", "cid", "op", "cap_id", "chash", "size", "ext", "crit",
];

const SCHEMAS: &[ObjectSchemaV1] = &[
    ObjectSchemaV1 {
        object_type: ObjectTypeV1::IngredientRef,
        name: "IngredientRef",
        literal_t: Some("IngredientRef"),
        allowed_top_level_keys: INGREDIENT_REF_KEYS,
        payload_limit: PayloadLimitV1::DagCborObject,
    },
    ObjectSchemaV1 {
        object_type: ObjectTypeV1::NutrientProfile,
        name: "NutrientProfile",
        literal_t: Some("NutrientProfile"),
        allowed_top_level_keys: NUTRIENT_PROFILE_KEYS,
        payload_limit: PayloadLimitV1::DagCborObject,
    },
    ObjectSchemaV1 {
        object_type: ObjectTypeV1::CookRun,
        name: "CookRun",
        literal_t: Some("CookRun"),
        allowed_top_level_keys: COOK_RUN_KEYS,
        payload_limit: PayloadLimitV1::DagCborObject,
    },
    ObjectSchemaV1 {
        object_type: ObjectTypeV1::NutritionComputeResult,
        name: "NutritionComputeResult",
        literal_t: Some("NutritionComputeResult"),
        allowed_top_level_keys: NUTRITION_COMPUTE_RESULT_KEYS,
        payload_limit: PayloadLimitV1::DagCborObject,
    },
    ObjectSchemaV1 {
        object_type: ObjectTypeV1::IntakeEvent,
        name: "IntakeEvent",
        literal_t: Some("IntakeEvent"),
        allowed_top_level_keys: INTAKE_EVENT_KEYS,
        payload_limit: PayloadLimitV1::DagCborObject,
    },
    ObjectSchemaV1 {
        object_type: ObjectTypeV1::ServingOffer,
        name: "ServingOffer",
        literal_t: Some("ServingOffer"),
        allowed_top_level_keys: SERVING_OFFER_KEYS,
        payload_limit: PayloadLimitV1::ServingOffer,
    },
    ObjectSchemaV1 {
        object_type: ObjectTypeV1::LedgerGenesis,
        name: "LedgerGenesis",
        literal_t: Some("LedgerGenesis"),
        allowed_top_level_keys: LEDGER_GENESIS_KEYS,
        payload_limit: PayloadLimitV1::LedgerEvent,
    },
    ObjectSchemaV1 {
        object_type: ObjectTypeV1::DeviceKeyGrant,
        name: "DeviceKeyGrant",
        literal_t: Some("DeviceKeyGrant"),
        allowed_top_level_keys: DEVICE_KEY_GRANT_KEYS,
        payload_limit: PayloadLimitV1::LedgerEvent,
    },
    ObjectSchemaV1 {
        object_type: ObjectTypeV1::DeviceKeyRevoke,
        name: "DeviceKeyRevoke",
        literal_t: Some("DeviceKeyRevoke"),
        allowed_top_level_keys: DEVICE_KEY_REVOKE_KEYS,
        payload_limit: PayloadLimitV1::LedgerEvent,
    },
    ObjectSchemaV1 {
        object_type: ObjectTypeV1::VoidEvent,
        name: "VoidEvent",
        literal_t: Some("VoidEvent"),
        allowed_top_level_keys: VOID_EVENT_KEYS,
        payload_limit: PayloadLimitV1::LedgerEvent,
    },
    ObjectSchemaV1 {
        object_type: ObjectTypeV1::CorrectionEvent,
        name: "CorrectionEvent",
        literal_t: Some("CorrectionEvent"),
        allowed_top_level_keys: CORRECTION_EVENT_KEYS,
        payload_limit: PayloadLimitV1::LedgerEvent,
    },
    ObjectSchemaV1 {
        object_type: ObjectTypeV1::LedgerEvent,
        name: "LedgerEvent",
        literal_t: None,
        allowed_top_level_keys: LEDGER_EVENT_KEYS,
        payload_limit: PayloadLimitV1::LedgerEvent,
    },
    ObjectSchemaV1 {
        object_type: ObjectTypeV1::EncryptedObject,
        name: "EncryptedObject",
        literal_t: Some("EncryptedObject"),
        allowed_top_level_keys: ENCRYPTED_OBJECT_KEYS,
        payload_limit: PayloadLimitV1::EncryptedObject,
    },
    ObjectSchemaV1 {
        object_type: ObjectTypeV1::ManifestRecord,
        name: "ManifestRecord",
        literal_t: Some("ManifestRecord"),
        allowed_top_level_keys: MANIFEST_RECORD_KEYS,
        payload_limit: PayloadLimitV1::ManifestRecord,
    },
];

pub fn schema_for_object_type(name: &str) -> Option<&'static ObjectSchemaV1> {
    SCHEMAS
        .iter()
        .find(|schema| schema.object_type.selector_name() == name)
}

/// Legacy `dagcbor_validate` dispatches shallow checks from the embedded `t`.
/// Keep that lookup descriptor-driven without changing its observable behavior.
pub fn schema_for_legacy_t(t: &str) -> Option<&'static ObjectSchemaV1> {
    schema_for_object_type(t)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::BTreeSet;

    #[test]
    fn registry_contains_fourteen_unique_productions() {
        assert_eq!(SCHEMAS.len(), 14);
        let names: BTreeSet<_> = SCHEMAS.iter().map(|schema| schema.name).collect();
        assert_eq!(names.len(), SCHEMAS.len());
        for schema in SCHEMAS {
            assert_eq!(schema.name, schema.object_type.selector_name());
            let expected_literal = if schema.object_type == ObjectTypeV1::LedgerEvent {
                None
            } else {
                Some(schema.name)
            };
            assert_eq!(schema.literal_t, expected_literal);
        }
    }
}
