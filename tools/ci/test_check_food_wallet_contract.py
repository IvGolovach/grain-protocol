#!/usr/bin/env python3
"""Focused tests for the Food Wallet app-facing contract guard."""

from __future__ import annotations

import copy
import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "tools" / "ci" / "check_food_wallet_contract.py"


def load_module():
    spec = importlib.util.spec_from_file_location("check_food_wallet_contract", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise AssertionError("Could not load check_food_wallet_contract.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def valid_schema() -> dict[str, object]:
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://grain.local/sdk/food/contract/food_wallet_v1.schema.json",
        "title": "Grain Food Wallet Contract v1",
        "type": "object",
        "additionalProperties": False,
        "required": ["schema", "version", "concepts", "safe_summary_policy"],
        "properties": {
            "schema": {"const": "grain.food-wallet.v1"},
            "version": {"const": 1},
            "concepts": {
                "type": "object",
                "additionalProperties": False,
                "required": [
                    "FoodIntakeEntry",
                    "MealEstimateCandidate",
                    "VerifiedServingOffer",
                    "FoodIntakeDraft",
                    "TrustStatus",
                    "FoodSourceClass",
                    "NutritionInsight",
                    "SafeFoodSummary",
                ],
                "properties": {
                    "FoodIntakeEntry": {"$ref": "#/$defs/FoodIntakeEntry"},
                    "MealEstimateCandidate": {"$ref": "#/$defs/MealEstimateCandidate"},
                    "VerifiedServingOffer": {"$ref": "#/$defs/VerifiedServingOffer"},
                    "FoodIntakeDraft": {"$ref": "#/$defs/FoodIntakeDraft"},
                    "TrustStatus": {"$ref": "#/$defs/TrustStatus"},
                    "FoodSourceClass": {"$ref": "#/$defs/FoodSourceClass"},
                    "NutritionInsight": {"$ref": "#/$defs/NutritionInsight"},
                    "SafeFoodSummary": {"$ref": "#/$defs/SafeFoodSummary"},
                },
            },
            "safe_summary_policy": {
                "type": "object",
                "additionalProperties": False,
                "required": ["forbidden_raw_material", "allowed_summary_fields"],
                "properties": {
                    "forbidden_raw_material": {
                        "type": "array",
                        "items": {
                            "enum": [
                                "raw_photo",
                                "raw_image",
                                "raw_trust_bundle",
                                "raw_snapshot",
                                "private_key",
                                "raw_qr_payload",
                            ]
                        },
                    },
                    "allowed_summary_fields": {
                        "type": "array",
                        "items": {
                            "enum": ["schema", "summary_id", "entries", "totals", "insights", "generated_at"]
                        },
                    },
                },
            },
        },
        "$defs": {
            "TrustStatus": {"enum": ["verified", "self_issued", "estimated", "untrusted"]},
            "FoodSourceClass": {"enum": ["attested", "measured", "estimated"]},
            "NutritionInsight": {
                "type": "object",
                "additionalProperties": False,
                "required": ["kind", "message"],
                "properties": {"kind": {"enum": ["energy", "serving", "confidence"]}, "message": {"type": "string"}},
            },
            "MealEstimateCandidate": {
                "type": "object",
                "additionalProperties": False,
                "required": ["candidate_id", "source_class", "trust_status", "label", "mean", "var"],
                "properties": {
                    "candidate_id": {"type": "string"},
                    "source_class": {"$ref": "#/$defs/FoodSourceClass"},
                    "trust_status": {"$ref": "#/$defs/TrustStatus"},
                    "label": {"type": "string"},
                    "mean": {"type": "object"},
                    "var": {"type": "object"},
                },
            },
            "VerifiedServingOffer": {
                "type": "object",
                "additionalProperties": False,
                "required": ["offer_id", "issuer", "source_class", "trust_status", "serving_g", "mean", "var"],
                "properties": {
                    "offer_id": {"type": "string"},
                    "issuer": {"type": "string"},
                    "source_class": {"const": "attested"},
                    "trust_status": {"const": "verified"},
                    "serving_g": {"type": "integer", "minimum": 0},
                    "mean": {"type": "object"},
                    "var": {"type": "object"},
                },
            },
            "FoodIntakeDraft": {
                "type": "object",
                "additionalProperties": False,
                "required": ["draft_id", "trust_status", "source_class", "entry"],
                "properties": {
                    "draft_id": {"type": "string"},
                    "trust_status": {"$ref": "#/$defs/TrustStatus"},
                    "source_class": {"$ref": "#/$defs/FoodSourceClass"},
                    "entry": {"$ref": "#/$defs/FoodIntakeEntry"},
                },
            },
            "FoodIntakeEntry": {
                "type": "object",
                "additionalProperties": False,
                "required": [
                    "entry_id",
                    "source_class",
                    "trust_status",
                    "mean",
                    "var",
                    "amount_g",
                    "serving_g",
                    "servings",
                ],
                "properties": {
                    "entry_id": {"type": "string"},
                    "source_class": {"$ref": "#/$defs/FoodSourceClass"},
                    "trust_status": {"$ref": "#/$defs/TrustStatus"},
                    "mean": {"type": "object"},
                    "var": {"type": "object"},
                    "amount_g": {"type": "integer", "minimum": 0},
                    "serving_g": {"type": "integer", "minimum": 0},
                    "servings": {"type": "integer", "minimum": 0},
                },
            },
            "SafeFoodSummary": {
                "type": "object",
                "additionalProperties": False,
                "required": ["schema", "summary_id", "entries", "totals", "insights", "generated_at"],
                "properties": {
                    "schema": {"const": "grain.food-wallet.safe-summary.v1"},
                    "summary_id": {"type": "string"},
                    "entries": {"type": "array", "items": {"$ref": "#/$defs/FoodIntakeEntry"}},
                    "totals": {"type": "object"},
                    "insights": {"type": "array", "items": {"$ref": "#/$defs/NutritionInsight"}},
                    "generated_at": {"type": "string"},
                },
            },
        },
    }


def readme_text() -> str:
    return "\n".join(
        [
            "# Food Wallet Contract",
            "FoodIntakeEntry MealEstimateCandidate VerifiedServingOffer FoodIntakeDraft",
            "TrustStatus FoodSourceClass NutritionInsight SafeFoodSummary",
            "verified self_issued estimated untrusted",
            "attested measured estimated",
            "Safe summaries must not include raw photos, raw trust bundles, raw snapshots, private keys, raw QR payload material, sync bundles, or identity bundles.",
        ]
    )


def valid_entry(
    *,
    entry_id: str = "entry-breakfast-001",
    source_class: str = "estimated",
    trust_status: str = "estimated",
    kcal: int = 420,
    var: int = 36,
    amount_g: int = 280,
    serving_g: int = 280,
    servings: int = 1,
) -> dict[str, object]:
    return {
        "entry_id": entry_id,
        "source_class": source_class,
        "trust_status": trust_status,
        "mean": {"kcal": kcal},
        "var": {"kcal": var},
        "amount_g": amount_g,
        "serving_g": serving_g,
        "servings": servings,
    }


def fixtures() -> dict[str, dict[str, object]]:
    return {
        "food-wallet-fake-photo-estimate.v1.json": {
            "fixture_id": "food-wallet-fake-photo-estimate.v1",
            "schema": "grain.food-wallet.fixture.v1",
            "kind": "fake_photo_estimate",
            "candidate": {
                "candidate_id": "candidate-fake-photo-001",
                "source_class": "estimated",
                "trust_status": "estimated",
                "label": "breakfast bowl estimate",
                "mean": {"kcal": 420},
                "var": {"kcal": 36},
            },
            "meta": {"desc": "Synthetic estimate metadata only."},
        },
        "food-wallet-verified-qr-draft.v1.json": {
            "fixture_id": "food-wallet-verified-qr-draft.v1",
            "schema": "grain.food-wallet.fixture.v1",
            "kind": "verified_qr_draft",
            "offer": {
                "offer_id": "offer-cafe-yogurt-001",
                "issuer": "demo-cafe",
                "source_class": "attested",
                "trust_status": "verified",
                "serving_g": 180,
                "mean": {"kcal": 260},
                "var": {"kcal": 4},
            },
            "draft": {
                "draft_id": "draft-cafe-yogurt-001",
                "trust_status": "verified",
                "source_class": "attested",
                "entry": valid_entry(
                    entry_id="entry-cafe-yogurt-001",
                    source_class="attested",
                    trust_status="verified",
                    kcal=260,
                    var=4,
                    amount_g=180,
                    serving_g=180,
                ),
            },
        },
        "food-wallet-self-issued-draft.v1.json": {
            "fixture_id": "food-wallet-self-issued-draft.v1",
            "schema": "grain.food-wallet.fixture.v1",
            "kind": "self_issued_draft",
            "draft": {
                "draft_id": "draft-home-soup-001",
                "trust_status": "self_issued",
                "source_class": "measured",
                "entry": valid_entry(
                    entry_id="entry-home-soup-001",
                    source_class="measured",
                    trust_status="self_issued",
                    kcal=310,
                    var=9,
                    amount_g=350,
                    serving_g=350,
                ),
            },
        },
        "food-wallet-safe-summary.v1.json": {
            "fixture_id": "food-wallet-safe-summary.v1",
            "schema": "grain.food-wallet.fixture.v1",
            "kind": "safe_summary_export",
            "summary": {
                "schema": "grain.food-wallet.safe-summary.v1",
                "summary_id": "safe-summary-demo-day-001",
                "entries": [valid_entry()],
                "totals": {"mean": {"kcal": 420}, "var": {"kcal": 36}},
                "insights": [{"kind": "confidence", "message": "Estimate-only meal; verify before sharing."}],
                "generated_at": "2026-05-17T00:00:00Z",
            },
        },
    }


def write_contract_repo(root: Path) -> None:
    (root / "sdk/food/contract").mkdir(parents=True)
    (root / "sdk/food/contract/food_wallet_v1.schema.json").write_text(
        json.dumps(valid_schema(), indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    (root / "sdk/food/README.md").write_text(readme_text(), encoding="utf-8")
    (root / "examples/reference-fixtures").mkdir(parents=True)
    for filename, data in fixtures().items():
        (root / f"examples/reference-fixtures/{filename}").write_text(
            json.dumps(data, indent=2) + "\n",
            encoding="utf-8",
        )


class FoodWalletContractTests(unittest.TestCase):
    def test_valid_contract_passes(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_contract_repo(root)

            result = module.check_food_wallet_contract(root=root)

            self.assertEqual(result.schema, "grain.food-wallet.v1")
            self.assertEqual(result.checked_concepts, 8)
            self.assertEqual(result.checked_fixtures, 4)

    def test_contract_requires_all_trust_statuses(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_contract_repo(root)
            schema_path = root / "sdk/food/contract/food_wallet_v1.schema.json"
            schema = valid_schema()
            schema["$defs"]["TrustStatus"]["enum"] = ["verified", "estimated"]
            schema_path.write_text(json.dumps(schema) + "\n", encoding="utf-8")

            with self.assertRaisesRegex(SystemExit, "FOOD_WALLET_CONTRACT_ERR_TRUST_STATUS"):
                module.check_food_wallet_contract(root=root)

    def test_safe_summary_rejects_raw_photo_or_snapshot_fields(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_contract_repo(root)
            fixture_path = root / "examples/reference-fixtures/food-wallet-safe-summary.v1.json"
            fixture = json.loads(fixture_path.read_text(encoding="utf-8"))
            fixture["summary"]["raw_photo_b64"] = "not-allowed"
            fixture_path.write_text(json.dumps(fixture) + "\n", encoding="utf-8")

            with self.assertRaisesRegex(SystemExit, "FOOD_WALLET_CONTRACT_ERR_FORBIDDEN_RAW_FIELD"):
                module.check_food_wallet_contract(root=root)

    def test_safe_summary_rejects_identity_bundle_transfer_fields(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_contract_repo(root)
            fixture_path = root / "examples/reference-fixtures/food-wallet-safe-summary.v1.json"
            fixture = json.loads(fixture_path.read_text(encoding="utf-8"))
            fixture["summary"]["identityBundle"] = "opaque-identity-payload"
            fixture_path.write_text(json.dumps(fixture) + "\n", encoding="utf-8")

            with self.assertRaisesRegex(SystemExit, "FOOD_WALLET_CONTRACT_ERR_FORBIDDEN_RAW_FIELD"):
                module.check_food_wallet_contract(root=root)

    def test_safe_summary_allows_only_safe_export_fields(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_contract_repo(root)
            fixture_path = root / "examples/reference-fixtures/food-wallet-safe-summary.v1.json"
            fixture = json.loads(fixture_path.read_text(encoding="utf-8"))
            fixture["summary"] = copy.deepcopy(fixture["summary"])
            fixture["summary"]["debug"] = "extra field"
            fixture_path.write_text(json.dumps(fixture) + "\n", encoding="utf-8")

            with self.assertRaisesRegex(SystemExit, "FOOD_WALLET_CONTRACT_ERR_SAFE_SUMMARY_FIELDS"):
                module.check_food_wallet_contract(root=root)


if __name__ == "__main__":
    unittest.main()
