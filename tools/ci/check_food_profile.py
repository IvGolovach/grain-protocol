#!/usr/bin/env python3
"""Static guard for Food Profile 1.0 constraints."""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

EXPECTED_SOURCE_CLASSES = ["attested", "measured", "estimated"]
EXPECTED_REDUCER_VISIBLE_NUTRIENTS = {
    "kcal": {
        "unit": "kilocalorie",
        "scale_exp10": 0,
        "integer_domain": "int64",
    }
}
EXPECTED_QUANTITY_FIELDS = {
    "amount_g": {"unit": "gram", "scale_exp10": 0, "integer_domain": "int64", "minimum": 0},
    "yield_g": {"unit": "gram", "scale_exp10": 0, "integer_domain": "int64", "minimum": 0},
    "serving_g": {"unit": "gram", "scale_exp10": 0, "integer_domain": "int64", "minimum": 0},
    "servings": {"unit": "serving", "scale_exp10": 0, "integer_domain": "int64", "minimum": 0},
}
EXPECTED_REDUCER_OUTPUTS = ["sum_mean", "sum_var"]
EXPECTED_LOCAL_PILOT_FIXTURE_ID = "food-local-pilot.valid.v1"
EXPECTED_LOCAL_PILOT_CATALOG_ID = "profile.food-local-pilot.valid"
EXPECTED_LOCAL_PILOT_FIXTURE_PATH = "examples/reference-fixtures/food-local-pilot.valid.v1.json"


@dataclass(frozen=True)
class FoodProfileCheck:
    profile: str
    source_classes: list[str]
    reducer_visible_nutrients: list[str]
    quantity_fields: list[str]
    local_pilot_fixture: str


def err(code: str, detail: str) -> None:
    raise SystemExit(f"{code}: {detail}")


def load_json(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        err("FOOD_PROFILE_ERR_MISSING", str(path))
    if not isinstance(data, dict):
        err("FOOD_PROFILE_ERR_SCHEMA", "profile JSON must be an object")
    return data


def require_equal(actual: Any, expected: Any, code: str, detail: str) -> None:
    if actual != expected:
        err(code, f"{detail}: expected {expected!r}, got {actual!r}")


def require_contains(text: str, needle: str, code: str, path: Path) -> None:
    if needle not in text:
        err(code, f"{path} missing {needle!r}")


def require_object(value: Any, code: str, detail: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        err(code, f"{detail} must be an object")
    return value


def require_list(value: Any, code: str, detail: str) -> list[Any]:
    if not isinstance(value, list):
        err(code, f"{detail} must be a list")
    return value


def require_json_int(value: Any, code: str, detail: str) -> int:
    if not isinstance(value, int) or isinstance(value, bool):
        err(code, f"{detail} must be an integer")
    if value < -(2**63) or value > 2**63 - 1:
        err(code, f"{detail} must fit int64")
    return value


def require_non_negative_int64(value: Any, code: str, detail: str) -> int:
    parsed = require_json_int(value, code, detail)
    if parsed < 0:
        err(code, f"{detail} must be non-negative")
    return parsed


def require_kcal_map(value: Any, code: str, detail: str, *, non_negative: bool = False) -> int:
    nutrient_map = require_object(value, code, detail)
    if "kcal" not in nutrient_map:
        err(code, f"{detail}.kcal is required")
    if non_negative:
        return require_non_negative_int64(nutrient_map["kcal"], code, f"{detail}.kcal")
    return require_json_int(nutrient_map["kcal"], code, f"{detail}.kcal")


def validate_food_event(event: Any, index: int) -> tuple[int, int]:
    item = require_object(event, "FOOD_PROFILE_ERR_LOCAL_PILOT_EVENT", f"pilot.events[{index}]")
    require_equal(item.get("t"), "IntakeEvent", "FOOD_PROFILE_ERR_LOCAL_PILOT_EVENT", f"pilot.events[{index}].t")
    payload_cid = item.get("payload_cid")
    if not isinstance(payload_cid, str) or not payload_cid.startswith("meal-scan:"):
        err("FOOD_PROFILE_ERR_LOCAL_PILOT_EVENT", f"pilot.events[{index}].payload_cid must use meal-scan: identity")

    body = require_object(item.get("body"), "FOOD_PROFILE_ERR_LOCAL_PILOT_EVENT", f"pilot.events[{index}].body")
    if body.get("source_class") not in EXPECTED_SOURCE_CLASSES:
        err("FOOD_PROFILE_ERR_LOCAL_PILOT_SOURCE_CLASS", f"pilot.events[{index}].body.source_class")
    mean_kcal = require_kcal_map(body.get("mean"), "FOOD_PROFILE_ERR_LOCAL_PILOT_NUTRIENTS", f"pilot.events[{index}].body.mean")
    var_kcal = require_kcal_map(body.get("var"), "FOOD_PROFILE_ERR_LOCAL_PILOT_NUTRIENTS", f"pilot.events[{index}].body.var", non_negative=True)
    for field in ("amount_g", "serving_g", "servings"):
        if field not in body:
            err("FOOD_PROFILE_ERR_LOCAL_PILOT_QUANTITY", f"pilot.events[{index}].body.{field} is required")
        require_non_negative_int64(body[field], "FOOD_PROFILE_ERR_LOCAL_PILOT_QUANTITY", f"pilot.events[{index}].body.{field}")
    if "yield_g" in body:
        require_non_negative_int64(body["yield_g"], "FOOD_PROFILE_ERR_LOCAL_PILOT_QUANTITY", f"pilot.events[{index}].body.yield_g")
    return mean_kcal, var_kcal


def validate_scanner_offer(value: Any) -> None:
    offer = require_object(value, "FOOD_PROFILE_ERR_LOCAL_PILOT_OFFER", "pilot.scanner_offer")
    require_equal(offer.get("t"), "ServingOffer", "FOOD_PROFILE_ERR_LOCAL_PILOT_OFFER", "pilot.scanner_offer.t")
    require_non_negative_int64(offer.get("serving_g"), "FOOD_PROFILE_ERR_LOCAL_PILOT_OFFER", "pilot.scanner_offer.serving_g")
    require_kcal_map(offer.get("mean"), "FOOD_PROFILE_ERR_LOCAL_PILOT_OFFER", "pilot.scanner_offer.mean")
    require_kcal_map(offer.get("var"), "FOOD_PROFILE_ERR_LOCAL_PILOT_OFFER", "pilot.scanner_offer.var", non_negative=True)


def validate_local_pilot_fixture(root: Path) -> str:
    fixture = load_json(root / EXPECTED_LOCAL_PILOT_FIXTURE_PATH)
    require_equal(
        fixture.get("fixture_id"),
        EXPECTED_LOCAL_PILOT_FIXTURE_ID,
        "FOOD_PROFILE_ERR_LOCAL_PILOT_ID",
        "fixture_id",
    )
    require_equal(fixture.get("profile_id"), "food-v0.1", "FOOD_PROFILE_ERR_LOCAL_PILOT_PROFILE", "profile_id")
    pilot = require_object(fixture.get("pilot"), "FOOD_PROFILE_ERR_LOCAL_PILOT", "pilot")
    require_equal(
        pilot.get("scope"),
        "local-source-validation-only",
        "FOOD_PROFILE_ERR_LOCAL_PILOT_SCOPE",
        "pilot.scope",
    )
    for field in ("requires_external_apps", "requires_external_devices", "requires_external_credentials"):
        require_equal(pilot.get(field), False, "FOOD_PROFILE_ERR_LOCAL_PILOT_BOUNDARY", f"pilot.{field}")

    events = require_list(pilot.get("events"), "FOOD_PROFILE_ERR_LOCAL_PILOT_EVENT", "pilot.events")
    if not events:
        err("FOOD_PROFILE_ERR_LOCAL_PILOT_EVENT", "pilot.events must not be empty")
    sum_mean = 0
    sum_var = 0
    for index, event in enumerate(events):
        mean_kcal, var_kcal = validate_food_event(event, index)
        sum_mean += mean_kcal
        sum_var += var_kcal

    validate_scanner_offer(pilot.get("scanner_offer"))
    expected = require_object(
        pilot.get("expected_reducer"),
        "FOOD_PROFILE_ERR_LOCAL_PILOT_EXPECTED",
        "pilot.expected_reducer",
    )
    expected_reducer = {
        "sum_mean": {"kcal": sum_mean},
        "sum_var": {"kcal": sum_var},
    }
    require_equal(expected, expected_reducer, "FOOD_PROFILE_ERR_LOCAL_PILOT_EXPECTED", "pilot.expected_reducer")

    catalog = load_json(root / "examples" / "reference-fixtures" / "catalog.v1.json")
    fixtures = require_list(catalog.get("fixtures"), "FOOD_PROFILE_ERR_LOCAL_PILOT_CATALOG", "catalog.fixtures")
    for entry in fixtures:
        if not isinstance(entry, dict):
            continue
        if entry.get("fixture_id") == EXPECTED_LOCAL_PILOT_CATALOG_ID:
            require_equal(
                entry.get("path"),
                EXPECTED_LOCAL_PILOT_FIXTURE_PATH,
                "FOOD_PROFILE_ERR_LOCAL_PILOT_CATALOG",
                EXPECTED_LOCAL_PILOT_CATALOG_ID,
            )
            require_equal(
                entry.get("profile_id"),
                "food-v0.1",
                "FOOD_PROFILE_ERR_LOCAL_PILOT_CATALOG",
                EXPECTED_LOCAL_PILOT_CATALOG_ID,
            )
            return EXPECTED_LOCAL_PILOT_FIXTURE_PATH
    err("FOOD_PROFILE_ERR_LOCAL_PILOT_CATALOG", EXPECTED_LOCAL_PILOT_CATALOG_ID)


def check_food_profile(root: Path | str | None = None) -> FoodProfileCheck:
    repo_root = Path(root) if root is not None else Path(__file__).resolve().parents[2]
    profile_path = repo_root / "spec" / "profiles" / "food-profile.v1.json"
    profile_md_path = repo_root / "spec" / "profiles" / "food-profile.md"
    cddl_path = repo_root / "spec" / "schemas" / "grain-v0.1.cddl"

    profile = load_json(profile_path)
    require_equal(profile.get("schema"), "grain.food-profile.constraints.v1", "FOOD_PROFILE_ERR_SCHEMA", "schema")
    require_equal(profile.get("profile"), "food-v0.1", "FOOD_PROFILE_ERR_PROFILE", "profile")
    require_equal(profile.get("protocol_schema_major"), 1, "FOOD_PROFILE_ERR_SCHEMA_MAJOR", "protocol_schema_major")

    source_class = profile.get("source_class")
    if not isinstance(source_class, dict):
        err("FOOD_PROFILE_ERR_SOURCE_CLASS", "source_class must be an object")
    require_equal(
        source_class.get("allowed"),
        EXPECTED_SOURCE_CLASSES,
        "FOOD_PROFILE_ERR_SOURCE_CLASS",
        "source_class.allowed",
    )
    if source_class.get("default") not in EXPECTED_SOURCE_CLASSES:
        err("FOOD_PROFILE_ERR_SOURCE_CLASS", "source_class.default must be one of the allowed values")

    require_equal(
        profile.get("reducer_visible_nutrients"),
        EXPECTED_REDUCER_VISIBLE_NUTRIENTS,
        "FOOD_PROFILE_ERR_NUTRIENTS",
        "reducer_visible_nutrients",
    )
    require_equal(
        profile.get("quantity_fields"),
        EXPECTED_QUANTITY_FIELDS,
        "FOOD_PROFILE_ERR_QUANTITY_SCALE",
        "quantity_fields",
    )
    require_equal(
        profile.get("reducer_outputs"),
        EXPECTED_REDUCER_OUTPUTS,
        "FOOD_PROFILE_ERR_REDUCER_OUTPUTS",
        "reducer_outputs",
    )

    try:
        profile_md = profile_md_path.read_text(encoding="utf-8")
        cddl = cddl_path.read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        err("FOOD_PROFILE_ERR_MISSING", str(exc))

    for value in EXPECTED_SOURCE_CLASSES:
        require_contains(profile_md, value, "FOOD_PROFILE_ERR_DOC_ANCHOR", profile_md_path)
        require_contains(cddl, value, "FOOD_PROFILE_ERR_CDDL_ANCHOR", cddl_path)
    for value in ["kcal", "scale_exp10 = 0", "amount_g", "yield_g", "serving_g", "servings"]:
        require_contains(profile_md, value, "FOOD_PROFILE_ERR_DOC_ANCHOR", profile_md_path)
    require_contains(cddl, "Food Profile 1.0", "FOOD_PROFILE_ERR_CDDL_ANCHOR", cddl_path)
    local_pilot_fixture = validate_local_pilot_fixture(repo_root)

    return FoodProfileCheck(
        profile=str(profile["profile"]),
        source_classes=list(source_class["allowed"]),
        reducer_visible_nutrients=list(EXPECTED_REDUCER_VISIBLE_NUTRIENTS),
        quantity_fields=list(EXPECTED_QUANTITY_FIELDS),
        local_pilot_fixture=local_pilot_fixture,
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--root", default=str(Path(__file__).resolve().parents[2]))
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    result = check_food_profile(root=Path(args.root))
    print(
        "Food Profile static check: OK "
        f"({result.profile}, source_class={','.join(result.source_classes)}, "
        f"reducer_visible={','.join(result.reducer_visible_nutrients)}, "
        f"local_pilot={result.local_pilot_fixture})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
