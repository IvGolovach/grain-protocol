export const OBJECT_TYPES_V1 = [
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
  "ManifestRecord"
] as const;

export type ObjectTypeV1 = (typeof OBJECT_TYPES_V1)[number];

export type PayloadLimitV1 =
  | "dagcbor_object"
  | "ledger_event"
  | "manifest_record"
  | "serving_offer"
  | "encrypted_object";

export type ObjectSchemaV1 = {
  objectType: ObjectTypeV1;
  /** LedgerEvent carries its concrete event type instead of a fixed literal. */
  literalT?: ObjectTypeV1;
  allowedTopLevelKeys: readonly string[];
  payloadLimit: PayloadLimitV1;
};

type ObjectSchemaRegistryV1 = {
  readonly [K in ObjectTypeV1]: ObjectSchemaV1 & { readonly objectType: K };
};

const OBJECT_SCHEMAS_V1 = {
  IngredientRef: {
    objectType: "IngredientRef",
    literalT: "IngredientRef",
    allowedTopLevelKeys: ["v", "t", "ref_type", "ref_id", "ref_version", "name", "ext", "crit"],
    payloadLimit: "dagcbor_object"
  },
  NutrientProfile: {
    objectType: "NutrientProfile",
    literalT: "NutrientProfile",
    allowedTopLevelKeys: ["v", "t", "dataset_snapshot_id", "source", "basis", "nutr", "uncert", "ext", "crit"],
    payloadLimit: "dagcbor_object"
  },
  CookRun: {
    objectType: "CookRun",
    literalT: "CookRun",
    allowedTopLevelKeys: ["v", "t", "inputs", "yield_g", "ts_ms", "ext", "crit"],
    payloadLimit: "dagcbor_object"
  },
  NutritionComputeResult: {
    objectType: "NutritionComputeResult",
    literalT: "NutritionComputeResult",
    allowedTopLevelKeys: [
      "v",
      "t",
      "cookrun",
      "engine_id",
      "engine_version",
      "dataset_snapshot_id",
      "map",
      "out",
      "ext",
      "crit"
    ],
    payloadLimit: "dagcbor_object"
  },
  IntakeEvent: {
    objectType: "IntakeEvent",
    literalT: "IntakeEvent",
    allowedTopLevelKeys: [
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
      "crit"
    ],
    payloadLimit: "dagcbor_object"
  },
  ServingOffer: {
    objectType: "ServingOffer",
    literalT: "ServingOffer",
    allowedTopLevelKeys: ["v", "t", "issuer_kid", "serving_g", "mean", "var", "nonce", "ext", "crit"],
    payloadLimit: "serving_offer"
  },
  LedgerGenesis: {
    objectType: "LedgerGenesis",
    literalT: "LedgerGenesis",
    allowedTopLevelKeys: ["v", "t", "root_kid", "root_pub", "ext", "crit"],
    payloadLimit: "ledger_event"
  },
  DeviceKeyGrant: {
    objectType: "DeviceKeyGrant",
    literalT: "DeviceKeyGrant",
    allowedTopLevelKeys: ["v", "t", "ak", "pub", "caps", "ext", "crit"],
    payloadLimit: "ledger_event"
  },
  DeviceKeyRevoke: {
    objectType: "DeviceKeyRevoke",
    literalT: "DeviceKeyRevoke",
    allowedTopLevelKeys: ["v", "t", "ak", "ext", "crit"],
    payloadLimit: "ledger_event"
  },
  VoidEvent: {
    objectType: "VoidEvent",
    literalT: "VoidEvent",
    allowedTopLevelKeys: ["v", "t", "target", "reason", "ext", "crit"],
    payloadLimit: "ledger_event"
  },
  CorrectionEvent: {
    objectType: "CorrectionEvent",
    literalT: "CorrectionEvent",
    allowedTopLevelKeys: ["v", "t", "target", "reason", "ext", "crit"],
    payloadLimit: "ledger_event"
  },
  LedgerEvent: {
    objectType: "LedgerEvent",
    allowedTopLevelKeys: ["v", "t", "ak", "seq", "ts_ms", "body", "ext", "crit"],
    payloadLimit: "ledger_event"
  },
  EncryptedObject: {
    objectType: "EncryptedObject",
    literalT: "EncryptedObject",
    allowedTopLevelKeys: ["v", "t", "alg", "cap_id", "nonce", "ct", "ext", "crit"],
    payloadLimit: "encrypted_object"
  },
  ManifestRecord: {
    objectType: "ManifestRecord",
    literalT: "ManifestRecord",
    allowedTopLevelKeys: ["v", "t", "ak", "seq", "cid", "op", "cap_id", "chash", "size", "ext", "crit"],
    payloadLimit: "manifest_record"
  }
} as const satisfies ObjectSchemaRegistryV1;

export function schemaForObjectTypeV1(name: string): ObjectSchemaV1 | undefined {
  return Object.prototype.hasOwnProperty.call(OBJECT_SCHEMAS_V1, name)
    ? OBJECT_SCHEMAS_V1[name as ObjectTypeV1]
    : undefined;
}

/** Legacy dagcbor_validate selects its shallow checks from the embedded t. */
export function schemaForLegacyTypeV1(t: string): ObjectSchemaV1 | undefined {
  return schemaForObjectTypeV1(t);
}
