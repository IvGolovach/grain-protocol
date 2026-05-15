#!/usr/bin/env python3
"""Focused tests for Food Profile 1.0 static validation."""

from __future__ import annotations

import copy
import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "tools" / "ci" / "check_food_profile.py"


def load_module():
    spec = importlib.util.spec_from_file_location("check_food_profile", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise AssertionError("Could not load check_food_profile.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def valid_profile() -> dict[str, object]:
    return {
        "schema": "grain.food-profile.constraints.v1",
        "profile": "food-v0.1",
        "protocol_schema_major": 1,
        "source_class": {
            "allowed": ["attested", "measured", "estimated"],
            "default": "estimated",
        },
        "reducer_visible_nutrients": {
            "kcal": {
                "unit": "kilocalorie",
                "scale_exp10": 0,
                "integer_domain": "int64",
            }
        },
        "quantity_fields": {
            "amount_g": {"unit": "gram", "scale_exp10": 0, "integer_domain": "int64", "minimum": 0},
            "yield_g": {"unit": "gram", "scale_exp10": 0, "integer_domain": "int64", "minimum": 0},
            "serving_g": {"unit": "gram", "scale_exp10": 0, "integer_domain": "int64", "minimum": 0},
            "servings": {"unit": "serving", "scale_exp10": 0, "integer_domain": "int64", "minimum": 0},
        },
        "reducer_outputs": ["sum_mean", "sum_var"],
    }


def write_repo(root: Path, profile: dict[str, object]) -> None:
    (root / "spec/profiles").mkdir(parents=True)
    (root / "spec/profiles/food-profile.v1.json").write_text(json.dumps(profile) + "\n", encoding="utf-8")
    (root / "spec/profiles/food-profile.md").write_text(
        "# Food Profile 1.0\n\n"
        "Food Profile 1.0 fixes source_class to attested, measured, estimated.\n"
        "Reducer-visible kcal is integer kilocalories with scale_exp10 = 0.\n"
        "Food quantities amount_g, yield_g, serving_g, and servings use non-negative int64 values.\n",
        encoding="utf-8",
    )
    (root / "spec/schemas").mkdir(parents=True)
    (root / "spec/schemas/grain-v0.1.cddl").write_text(
        'nutrient-map = { * tstr => int }\n'
        '"source_class": tstr,   ; "attested" | "measured" | "estimated" (Food Profile 1.0)\n'
        '"amount_g": int\n'
        '"yield_g": int\n'
        '"serving_g": int\n'
        '"servings": int\n',
        encoding="utf-8",
    )
    (root / "examples/reference-fixtures").mkdir(parents=True)
    local_pilot = {
        "fixture_id": "food-local-pilot.valid.v1",
        "profile_id": "food-v0.1",
        "pilot": {
            "scope": "local-source-validation-only",
            "requires_external_apps": False,
            "requires_external_devices": False,
            "requires_external_credentials": False,
            "events": [
                {
                    "t": "IntakeEvent",
                    "payload_cid": "meal-scan:test-001",
                    "body": {
                        "source_class": "measured",
                        "mean": {"kcal": 10},
                        "var": {"kcal": 1},
                        "amount_g": 20,
                        "serving_g": 20,
                        "servings": 1,
                    },
                }
            ],
            "scanner_offer": {
                "t": "ServingOffer",
                "serving_g": 20,
                "mean": {"kcal": 10},
                "var": {"kcal": 1},
            },
            "expected_reducer": {
                "sum_mean": {"kcal": 10},
                "sum_var": {"kcal": 1},
            },
        },
    }
    (root / "examples/reference-fixtures/food-local-pilot.valid.v1.json").write_text(
        json.dumps(local_pilot) + "\n",
        encoding="utf-8",
    )
    (root / "examples/reference-fixtures/catalog.v1.json").write_text(
        json.dumps(
            {
                "schema": "grain.reference-fixtures.v1",
                "fixtures": [
                    {
                        "fixture_id": "profile.food-local-pilot.valid",
                        "kind": "sample",
                        "profile_id": "food-v0.1",
                        "path": "examples/reference-fixtures/food-local-pilot.valid.v1.json",
                    }
                ],
            }
        )
        + "\n",
        encoding="utf-8",
    )


class FoodProfileTests(unittest.TestCase):
    def test_valid_food_profile_passes(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_repo(root, valid_profile())

            result = module.check_food_profile(root=root)

            self.assertEqual(result.profile, "food-v0.1")
            self.assertEqual(result.source_classes, ["attested", "measured", "estimated"])
            self.assertEqual(result.reducer_visible_nutrients, ["kcal"])
            self.assertEqual(result.local_pilot_fixture, "examples/reference-fixtures/food-local-pilot.valid.v1.json")

    def test_source_class_drift_is_rejected(self) -> None:
        module = load_module()
        profile = copy.deepcopy(valid_profile())
        profile["source_class"]["allowed"] = ["attested", "estimated"]
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_repo(root, profile)

            with self.assertRaisesRegex(SystemExit, "FOOD_PROFILE_ERR_SOURCE_CLASS"):
                module.check_food_profile(root=root)

    def test_quantity_scale_drift_is_rejected(self) -> None:
        module = load_module()
        profile = copy.deepcopy(valid_profile())
        profile["quantity_fields"]["amount_g"]["scale_exp10"] = -3
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_repo(root, profile)

            with self.assertRaisesRegex(SystemExit, "FOOD_PROFILE_ERR_QUANTITY_SCALE"):
                module.check_food_profile(root=root)

    def test_local_food_pilot_requires_local_boundary(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_repo(root, valid_profile())
            fixture_path = root / "examples/reference-fixtures/food-local-pilot.valid.v1.json"
            fixture = json.loads(fixture_path.read_text(encoding="utf-8"))
            fixture["pilot"]["requires_external_devices"] = True
            fixture_path.write_text(json.dumps(fixture) + "\n", encoding="utf-8")

            with self.assertRaisesRegex(SystemExit, "FOOD_PROFILE_ERR_LOCAL_PILOT_BOUNDARY"):
                module.check_food_profile(root=root)

    def test_local_food_pilot_rejects_bad_expected_reducer(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_repo(root, valid_profile())
            fixture_path = root / "examples/reference-fixtures/food-local-pilot.valid.v1.json"
            fixture = json.loads(fixture_path.read_text(encoding="utf-8"))
            fixture["pilot"]["expected_reducer"]["sum_mean"]["kcal"] = 11
            fixture_path.write_text(json.dumps(fixture) + "\n", encoding="utf-8")

            with self.assertRaisesRegex(SystemExit, "FOOD_PROFILE_ERR_LOCAL_PILOT_EXPECTED"):
                module.check_food_profile(root=root)


if __name__ == "__main__":
    unittest.main()
