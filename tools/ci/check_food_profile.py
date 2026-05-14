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


@dataclass(frozen=True)
class FoodProfileCheck:
    profile: str
    source_classes: list[str]
    reducer_visible_nutrients: list[str]
    quantity_fields: list[str]


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

    return FoodProfileCheck(
        profile=str(profile["profile"]),
        source_classes=list(source_class["allowed"]),
        reducer_visible_nutrients=list(EXPECTED_REDUCER_VISIBLE_NUTRIENTS),
        quantity_fields=list(EXPECTED_QUANTITY_FIELDS),
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
        f"reducer_visible={','.join(result.reducer_visible_nutrients)})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
