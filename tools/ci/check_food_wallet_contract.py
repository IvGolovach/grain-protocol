#!/usr/bin/env python3
"""Guard the platform-neutral Food Wallet app-facing contract."""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

ROOT = Path(__file__).resolve().parents[2]

CONTRACT_SCHEMA = "grain.food-wallet.v1"
FIXTURE_SCHEMA = "grain.food-wallet.fixture.v1"
SAFE_SUMMARY_SCHEMA = "grain.food-wallet.safe-summary.v1"

CONCEPT_NAMES = [
    "FoodIntakeEntry",
    "MealEstimateCandidate",
    "VerifiedServingOffer",
    "FoodIntakeDraft",
    "RecordTrust",
    "NutritionConfidence",
    "FoodSourceClass",
    "NutritionInsight",
    "SafeFoodSummary",
]
RECORD_TRUST_VALUES = ["verified_source", "self_issued", "untrusted"]
NUTRITION_CONFIDENCE_VALUES = ["confirmed", "estimated", "incomplete", "unknown"]
SOURCE_CLASS_VALUES = ["attested", "measured", "estimated"]
FORBIDDEN_RAW_MATERIAL = [
    "raw_photo",
    "raw_image",
    "raw_trust_bundle",
    "raw_snapshot",
    "private_key",
    "raw_qr_payload",
]
ALLOWED_SUMMARY_FIELDS = ["schema", "summary_id", "entries", "totals", "insights", "generated_at"]
EXPECTED_FIXTURES = {
    "food-wallet-fake-photo-estimate.v1.json": "fake_photo_estimate",
    "food-wallet-verified-qr-draft.v1.json": "verified_qr_draft",
    "food-wallet-self-issued-draft.v1.json": "self_issued_draft",
    "food-wallet-safe-summary.v1.json": "safe_summary_export",
}

FORBIDDEN_FIELD_RE = re.compile(
    r"(raw[_-]?(photo|image|qr|snapshot|trust)|"
    r"(photo|image)[_-]?(b64|bytes|data)|"
    r"(trust[_-]?bundle|trust[_-]?pub|snapshot|sync[_-]?bundle|identity[_-]?bundle|qr[_-]?(payload|string)|"
    r"private[_-]?key|secret[_-]?key|seed|mnemonic|cose[_-]?b64))",
    re.IGNORECASE,
)
FORBIDDEN_CONTENT_RE = re.compile(
    r"(-----BEGIN [A-Z ]*PRIVATE KEY-----|"
    r"raw\s+qr\s+payload\s*:|"
    r"\bGR1[0-9A-Za-z_-]{8,}|"
    r"trust[_-]?pub[_-]?b64\s*:|"
    r"identity[_-]?bundle\s*:|"
    r"sync[_-]?bundle\s*:|"
    r"snapshot[_-]?b64\s*:|"
    r"raw\s+trust\s+bundle\s*:)",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class FoodWalletContractResult:
    schema: str
    checked_concepts: int
    checked_fixtures: int


def err(code: str, detail: str) -> None:
    raise SystemExit(f"{code}: {detail}")


def require(condition: bool, code: str, detail: str) -> None:
    if not condition:
        err(code, detail)


def load_json(path: Path) -> dict[str, Any]:
    require(path.is_file(), "FOOD_WALLET_CONTRACT_ERR_FILE_MISSING", str(path))
    data = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(data, dict), "FOOD_WALLET_CONTRACT_ERR_JSON_OBJECT", str(path))
    return data


def as_dict(value: Any, code: str, detail: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        err(code, f"{detail} must be an object")
    return value


def as_list(value: Any, code: str, detail: str) -> list[Any]:
    if not isinstance(value, list):
        err(code, f"{detail} must be a list")
    return value


def require_str(value: Any, code: str, detail: str) -> str:
    if not isinstance(value, str) or not value:
        err(code, f"{detail} must be a non-empty string")
    return value


def require_int(value: Any, code: str, detail: str, *, minimum: int | None = None) -> int:
    if not isinstance(value, int) or isinstance(value, bool):
        err(code, f"{detail} must be an integer")
    if value < -(2**63) or value > 2**63 - 1:
        err(code, f"{detail} must fit int64")
    if minimum is not None and value < minimum:
        err(code, f"{detail} must be >= {minimum}")
    return value


def require_equal(actual: Any, expected: Any, code: str, detail: str) -> None:
    if actual != expected:
        err(code, f"{detail}: expected {expected!r}, got {actual!r}")


def require_enum(value: Any, allowed: list[str], code: str, detail: str) -> str:
    parsed = require_str(value, code, detail)
    if parsed not in allowed:
        err(code, f"{detail}: expected one of {allowed!r}, got {parsed!r}")
    return parsed


def require_kcal_map(value: Any, code: str, detail: str, *, non_negative: bool = False) -> None:
    nutrient_map = as_dict(value, code, detail)
    require("kcal" in nutrient_map, code, f"{detail}.kcal is required")
    require_int(nutrient_map["kcal"], code, f"{detail}.kcal", minimum=0 if non_negative else None)


def walk_items(value: Any, *, path: str = "$") -> Iterable[tuple[str, str, Any]]:
    if isinstance(value, dict):
        for key, item in value.items():
            child_path = f"{path}.{key}"
            yield child_path, key, item
            yield from walk_items(item, path=child_path)
    elif isinstance(value, list):
        for index, item in enumerate(value):
            yield from walk_items(item, path=f"{path}[{index}]")


def reject_forbidden_raw_material(fixture: dict[str, Any], path: Path) -> None:
    for item_path, key, value in walk_items(fixture):
        if FORBIDDEN_FIELD_RE.search(key):
            err("FOOD_WALLET_CONTRACT_ERR_FORBIDDEN_RAW_FIELD", f"{path}:{item_path}")
        if isinstance(value, str) and FORBIDDEN_CONTENT_RE.search(value):
            err("FOOD_WALLET_CONTRACT_ERR_FORBIDDEN_RAW_CONTENT", f"{path}:{item_path}")


def validate_schema(schema: dict[str, Any]) -> None:
    properties = as_dict(schema.get("properties"), "FOOD_WALLET_CONTRACT_ERR_PROPERTIES", "properties")
    schema_field = as_dict(properties.get("schema"), "FOOD_WALLET_CONTRACT_ERR_SCHEMA", "properties.schema")
    require_equal(schema_field.get("const"), CONTRACT_SCHEMA, "FOOD_WALLET_CONTRACT_ERR_SCHEMA", "schema.const")
    version = as_dict(properties.get("version"), "FOOD_WALLET_CONTRACT_ERR_VERSION", "properties.version")
    require_equal(version.get("const"), 1, "FOOD_WALLET_CONTRACT_ERR_VERSION", "version.const")

    defs = as_dict(schema.get("$defs"), "FOOD_WALLET_CONTRACT_ERR_DEFS", "$defs")
    concepts = as_dict(properties.get("concepts"), "FOOD_WALLET_CONTRACT_ERR_CONCEPTS", "properties.concepts")
    concept_required = as_list(concepts.get("required"), "FOOD_WALLET_CONTRACT_ERR_CONCEPTS", "concepts.required")
    concept_properties = as_dict(
        concepts.get("properties"),
        "FOOD_WALLET_CONTRACT_ERR_CONCEPTS",
        "concepts.properties",
    )
    for concept in CONCEPT_NAMES:
        require(concept in defs, "FOOD_WALLET_CONTRACT_ERR_CONCEPT_MISSING", concept)
        require(concept in concept_required, "FOOD_WALLET_CONTRACT_ERR_CONCEPT_MISSING", concept)
        require(concept in concept_properties, "FOOD_WALLET_CONTRACT_ERR_CONCEPT_MISSING", concept)

    record_trust = as_dict(defs["RecordTrust"], "FOOD_WALLET_CONTRACT_ERR_RECORD_TRUST", "RecordTrust")
    nutrition_confidence = as_dict(
        defs["NutritionConfidence"],
        "FOOD_WALLET_CONTRACT_ERR_NUTRITION_CONFIDENCE",
        "NutritionConfidence",
    )
    source_class = as_dict(defs["FoodSourceClass"], "FOOD_WALLET_CONTRACT_ERR_SOURCE_CLASS", "FoodSourceClass")
    require_equal(
        record_trust.get("enum"),
        RECORD_TRUST_VALUES,
        "FOOD_WALLET_CONTRACT_ERR_RECORD_TRUST",
        "RecordTrust.enum",
    )
    require_equal(
        nutrition_confidence.get("enum"),
        NUTRITION_CONFIDENCE_VALUES,
        "FOOD_WALLET_CONTRACT_ERR_NUTRITION_CONFIDENCE",
        "NutritionConfidence.enum",
    )
    require_equal(
        source_class.get("enum"),
        SOURCE_CLASS_VALUES,
        "FOOD_WALLET_CONTRACT_ERR_SOURCE_CLASS",
        "FoodSourceClass.enum",
    )

    policy = as_dict(
        properties.get("safe_summary_policy"),
        "FOOD_WALLET_CONTRACT_ERR_SAFE_POLICY",
        "safe_summary_policy",
    )
    policy_props = as_dict(
        policy.get("properties"),
        "FOOD_WALLET_CONTRACT_ERR_SAFE_POLICY",
        "safe_summary_policy.properties",
    )
    forbidden_items = as_dict(
        as_dict(
            policy_props.get("forbidden_raw_material"),
            "FOOD_WALLET_CONTRACT_ERR_SAFE_POLICY",
            "forbidden_raw_material",
        ).get("items"),
        "FOOD_WALLET_CONTRACT_ERR_SAFE_POLICY",
        "forbidden_raw_material.items",
    )
    allowed_items = as_dict(
        as_dict(
            policy_props.get("allowed_summary_fields"),
            "FOOD_WALLET_CONTRACT_ERR_SAFE_POLICY",
            "allowed_summary_fields",
        ).get("items"),
        "FOOD_WALLET_CONTRACT_ERR_SAFE_POLICY",
        "allowed_summary_fields.items",
    )
    require_equal(
        forbidden_items.get("enum"),
        FORBIDDEN_RAW_MATERIAL,
        "FOOD_WALLET_CONTRACT_ERR_SAFE_POLICY",
        "forbidden_raw_material",
    )
    require_equal(
        allowed_items.get("enum"),
        ALLOWED_SUMMARY_FIELDS,
        "FOOD_WALLET_CONTRACT_ERR_SAFE_POLICY",
        "allowed_summary_fields",
    )


def validate_readme(path: Path) -> None:
    require(path.is_file(), "FOOD_WALLET_CONTRACT_ERR_README_MISSING", str(path))
    text = path.read_text(encoding="utf-8")
    lower = text.lower()
    for concept in CONCEPT_NAMES:
        require(concept in text, "FOOD_WALLET_CONTRACT_ERR_README_CONCEPT_MISSING", concept)
    for value in RECORD_TRUST_VALUES + NUTRITION_CONFIDENCE_VALUES + SOURCE_CLASS_VALUES:
        require(value in text, "FOOD_WALLET_CONTRACT_ERR_README_VALUE_MISSING", value)
    for phrase in ("raw photos", "raw trust bundles", "raw snapshots", "private keys", "raw QR payload"):
        require(phrase.lower() in lower, "FOOD_WALLET_CONTRACT_ERR_README_PRIVACY_MISSING", phrase)


def validate_entry(value: Any, code: str, detail: str) -> tuple[str, str, str]:
    entry = as_dict(value, code, detail)
    require_str(entry.get("entry_id"), code, f"{detail}.entry_id")
    source_class = require_enum(entry.get("source_class"), SOURCE_CLASS_VALUES, code, f"{detail}.source_class")
    record_trust = require_enum(entry.get("record_trust"), RECORD_TRUST_VALUES, code, f"{detail}.record_trust")
    nutrition_confidence = require_enum(
        entry.get("nutrition_confidence"),
        NUTRITION_CONFIDENCE_VALUES,
        code,
        f"{detail}.nutrition_confidence",
    )
    require_kcal_map(entry.get("mean"), code, f"{detail}.mean")
    require_kcal_map(entry.get("var"), code, f"{detail}.var", non_negative=True)
    for quantity in ("amount_g", "serving_g", "servings"):
        require_int(entry.get(quantity), code, f"{detail}.{quantity}", minimum=0)
    return source_class, record_trust, nutrition_confidence


def validate_draft(
    value: Any,
    code: str,
    detail: str,
    *,
    expected_record_trust: str,
    expected_nutrition_confidence: str,
) -> None:
    draft = as_dict(value, code, detail)
    require_str(draft.get("draft_id"), code, f"{detail}.draft_id")
    source_class = require_enum(draft.get("source_class"), SOURCE_CLASS_VALUES, code, f"{detail}.source_class")
    record_trust = require_enum(draft.get("record_trust"), RECORD_TRUST_VALUES, code, f"{detail}.record_trust")
    nutrition_confidence = require_enum(
        draft.get("nutrition_confidence"),
        NUTRITION_CONFIDENCE_VALUES,
        code,
        f"{detail}.nutrition_confidence",
    )
    require_equal(record_trust, expected_record_trust, code, f"{detail}.record_trust")
    require_equal(
        nutrition_confidence,
        expected_nutrition_confidence,
        code,
        f"{detail}.nutrition_confidence",
    )
    entry_source, entry_trust, entry_confidence = validate_entry(draft.get("entry"), code, f"{detail}.entry")
    require_equal(entry_source, source_class, code, f"{detail}.entry.source_class")
    require_equal(entry_trust, record_trust, code, f"{detail}.entry.record_trust")
    require_equal(entry_confidence, nutrition_confidence, code, f"{detail}.entry.nutrition_confidence")


def validate_candidate(value: Any, detail: str) -> None:
    candidate = as_dict(value, "FOOD_WALLET_CONTRACT_ERR_FAKE_PHOTO_ESTIMATE", detail)
    require_str(candidate.get("candidate_id"), "FOOD_WALLET_CONTRACT_ERR_FAKE_PHOTO_ESTIMATE", f"{detail}.candidate_id")
    require_str(candidate.get("label"), "FOOD_WALLET_CONTRACT_ERR_FAKE_PHOTO_ESTIMATE", f"{detail}.label")
    require_equal(candidate.get("source_class"), "estimated", "FOOD_WALLET_CONTRACT_ERR_FAKE_PHOTO_ESTIMATE", f"{detail}.source_class")
    require_equal(candidate.get("record_trust"), "untrusted", "FOOD_WALLET_CONTRACT_ERR_FAKE_PHOTO_ESTIMATE", f"{detail}.record_trust")
    require_equal(candidate.get("nutrition_confidence"), "estimated", "FOOD_WALLET_CONTRACT_ERR_FAKE_PHOTO_ESTIMATE", f"{detail}.nutrition_confidence")
    require_kcal_map(candidate.get("mean"), "FOOD_WALLET_CONTRACT_ERR_FAKE_PHOTO_ESTIMATE", f"{detail}.mean")
    require_kcal_map(candidate.get("var"), "FOOD_WALLET_CONTRACT_ERR_FAKE_PHOTO_ESTIMATE", f"{detail}.var", non_negative=True)


def validate_offer(value: Any, detail: str) -> None:
    offer = as_dict(value, "FOOD_WALLET_CONTRACT_ERR_VERIFIED_QR_DRAFT", detail)
    require_str(offer.get("offer_id"), "FOOD_WALLET_CONTRACT_ERR_VERIFIED_QR_DRAFT", f"{detail}.offer_id")
    require_str(offer.get("issuer"), "FOOD_WALLET_CONTRACT_ERR_VERIFIED_QR_DRAFT", f"{detail}.issuer")
    require_equal(offer.get("source_class"), "attested", "FOOD_WALLET_CONTRACT_ERR_VERIFIED_QR_DRAFT", f"{detail}.source_class")
    require_equal(offer.get("record_trust"), "verified_source", "FOOD_WALLET_CONTRACT_ERR_VERIFIED_QR_DRAFT", f"{detail}.record_trust")
    require_equal(offer.get("nutrition_confidence"), "confirmed", "FOOD_WALLET_CONTRACT_ERR_VERIFIED_QR_DRAFT", f"{detail}.nutrition_confidence")
    require_int(offer.get("serving_g"), "FOOD_WALLET_CONTRACT_ERR_VERIFIED_QR_DRAFT", f"{detail}.serving_g", minimum=0)
    require_kcal_map(offer.get("mean"), "FOOD_WALLET_CONTRACT_ERR_VERIFIED_QR_DRAFT", f"{detail}.mean")
    require_kcal_map(offer.get("var"), "FOOD_WALLET_CONTRACT_ERR_VERIFIED_QR_DRAFT", f"{detail}.var", non_negative=True)


def validate_safe_summary(value: Any, detail: str) -> None:
    summary = as_dict(value, "FOOD_WALLET_CONTRACT_ERR_SAFE_SUMMARY", detail)
    require_equal(summary.get("schema"), SAFE_SUMMARY_SCHEMA, "FOOD_WALLET_CONTRACT_ERR_SAFE_SUMMARY", f"{detail}.schema")
    require_equal(
        list(summary.keys()),
        ALLOWED_SUMMARY_FIELDS,
        "FOOD_WALLET_CONTRACT_ERR_SAFE_SUMMARY_FIELDS",
        detail,
    )
    require_str(summary.get("summary_id"), "FOOD_WALLET_CONTRACT_ERR_SAFE_SUMMARY", f"{detail}.summary_id")
    entries = as_list(summary.get("entries"), "FOOD_WALLET_CONTRACT_ERR_SAFE_SUMMARY", f"{detail}.entries")
    require(entries, "FOOD_WALLET_CONTRACT_ERR_SAFE_SUMMARY", f"{detail}.entries must not be empty")
    for index, entry in enumerate(entries):
        validate_entry(entry, "FOOD_WALLET_CONTRACT_ERR_SAFE_SUMMARY", f"{detail}.entries[{index}]")
    totals = as_dict(summary.get("totals"), "FOOD_WALLET_CONTRACT_ERR_SAFE_SUMMARY", f"{detail}.totals")
    require_kcal_map(totals.get("mean"), "FOOD_WALLET_CONTRACT_ERR_SAFE_SUMMARY", f"{detail}.totals.mean")
    require_kcal_map(totals.get("var"), "FOOD_WALLET_CONTRACT_ERR_SAFE_SUMMARY", f"{detail}.totals.var", non_negative=True)
    insights = as_list(summary.get("insights"), "FOOD_WALLET_CONTRACT_ERR_SAFE_SUMMARY", f"{detail}.insights")
    for index, insight_value in enumerate(insights):
        insight = as_dict(insight_value, "FOOD_WALLET_CONTRACT_ERR_SAFE_SUMMARY", f"{detail}.insights[{index}]")
        require_enum(
            insight.get("kind"),
            ["energy", "serving", "confidence"],
            "FOOD_WALLET_CONTRACT_ERR_SAFE_SUMMARY",
            f"{detail}.insights[{index}].kind",
        )
        require_str(insight.get("message"), "FOOD_WALLET_CONTRACT_ERR_SAFE_SUMMARY", f"{detail}.insights[{index}].message")
    require_str(summary.get("generated_at"), "FOOD_WALLET_CONTRACT_ERR_SAFE_SUMMARY", f"{detail}.generated_at")


def validate_fixture(path: Path, expected_kind: str) -> None:
    fixture = load_json(path)
    reject_forbidden_raw_material(fixture, path)
    require_equal(fixture.get("schema"), FIXTURE_SCHEMA, "FOOD_WALLET_CONTRACT_ERR_FIXTURE_SCHEMA", path.name)
    require_equal(fixture.get("kind"), expected_kind, "FOOD_WALLET_CONTRACT_ERR_FIXTURE_KIND", path.name)
    require_equal(fixture.get("fixture_id"), path.name.removesuffix(".json"), "FOOD_WALLET_CONTRACT_ERR_FIXTURE_ID", path.name)
    if expected_kind == "fake_photo_estimate":
        validate_candidate(fixture.get("candidate"), f"{path.name}.candidate")
    elif expected_kind == "verified_qr_draft":
        validate_offer(fixture.get("offer"), f"{path.name}.offer")
        validate_draft(
            fixture.get("draft"),
            "FOOD_WALLET_CONTRACT_ERR_VERIFIED_QR_DRAFT",
            f"{path.name}.draft",
            expected_record_trust="verified_source",
            expected_nutrition_confidence="confirmed",
        )
    elif expected_kind == "self_issued_draft":
        validate_draft(
            fixture.get("draft"),
            "FOOD_WALLET_CONTRACT_ERR_SELF_ISSUED_DRAFT",
            f"{path.name}.draft",
            expected_record_trust="self_issued",
            expected_nutrition_confidence="confirmed",
        )
    elif expected_kind == "safe_summary_export":
        validate_safe_summary(fixture.get("summary"), f"{path.name}.summary")


def validate_fixtures(fixture_dir: Path) -> None:
    require(fixture_dir.is_dir(), "FOOD_WALLET_CONTRACT_ERR_FIXTURE_DIR_MISSING", str(fixture_dir))
    seen = {path.name: path for path in fixture_dir.glob("food-wallet-*.json")}
    require_equal(
        sorted(seen),
        sorted(EXPECTED_FIXTURES),
        "FOOD_WALLET_CONTRACT_ERR_FIXTURE_SET",
        "food-wallet fixtures",
    )
    for filename, expected_kind in EXPECTED_FIXTURES.items():
        validate_fixture(seen[filename], expected_kind)


def check_food_wallet_contract(
    *,
    root: Path = ROOT,
    contract_path: Path | None = None,
    readme_path: Path | None = None,
    fixture_dir: Path | None = None,
) -> FoodWalletContractResult:
    root = root.resolve()
    schema = load_json(contract_path or root / "sdk/food/contract/food_wallet_v1.schema.json")
    validate_schema(schema)
    validate_readme(readme_path or root / "sdk/food/README.md")
    validate_fixtures(fixture_dir or root / "examples/reference-fixtures")
    return FoodWalletContractResult(
        schema=CONTRACT_SCHEMA,
        checked_concepts=len(CONCEPT_NAMES),
        checked_fixtures=len(EXPECTED_FIXTURES),
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--root", default=str(ROOT))
    parser.add_argument("--contract", help="Defaults to sdk/food/contract/food_wallet_v1.schema.json under --root")
    parser.add_argument("--readme", help="Defaults to sdk/food/README.md under --root")
    parser.add_argument("--fixture-dir", help="Defaults to examples/reference-fixtures under --root")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    result = check_food_wallet_contract(
        root=Path(args.root),
        contract_path=Path(args.contract) if args.contract else None,
        readme_path=Path(args.readme) if args.readme else None,
        fixture_dir=Path(args.fixture_dir) if args.fixture_dir else None,
    )
    print(f"Food Wallet contract check: OK ({result.checked_concepts} concepts, {result.checked_fixtures} fixtures)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
