#!/usr/bin/env python3
"""Focused tests for the local Food pilot proof report contract."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "tools" / "ci" / "check_local_food_pilot_report.py"


def load_module():
    spec = importlib.util.spec_from_file_location("check_local_food_pilot_report", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise AssertionError("Could not load check_local_food_pilot_report.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def valid_proof() -> dict[str, object]:
    return {
        "schema": "grain.sdk.local_food_pilot_proof.v1",
        "fixture_id": "food-local-pilot.valid.v1",
        "profile_id": "food-v0.1",
        "event_count": 1,
        "appended_event_ids": ["event-1"],
        "reducer_pass": True,
        "reducer_diag": [],
        "reducer_out": {
            "sum_mean": {"kcal": 620},
            "sum_var": {"kcal": 9},
        },
        "proof_sha256": "a" * 64,
    }


def valid_report() -> dict[str, object]:
    return {
        "schema": "grain.sdk.local_food_pilot.v1",
        "commit": "b" * 40,
        "dirty": False,
        "publication_boundary": "local-source-validation-only",
        "external_apps": "not_required",
        "external_devices": "not_required",
        "external_credentials": "not_required",
        "registry_publication": "not_included",
        "app_store_publication": "not_included",
        "play_console_publication": "not_included",
        "flow": [
            "food_profile",
            "sdk_build",
            "sdk_reduce",
            "reference_issuer",
            "reference_issuer_verify",
            "local_trust_bundle",
        ],
        "artifacts": {
            "pilot_fixture": "food-local-pilot.valid.v1.json",
            "sdk_proof": "local-food-pilot-sdk-proof.json",
            "issuer_output": "issuer-output.json",
            "qr_string": "qr-string.txt",
            "trust_bundle": "local-trust-bundle.json",
            "logs": "logs",
        },
        "checks": {
            "food_profile": {
                "status": "pass",
                "command": "python3 tools/ci/check_food_profile.py",
                "output": "logs/food_profile.txt",
            },
            "sdk_build": {
                "status": "pass",
                "command": "npm --prefix core/ts/grain-sdk run build",
                "output": "logs/sdk_build.txt",
            },
            "sdk_reduce": {
                "status": "pass",
                "command": "node <generated local food pilot runner>",
                "output": "logs/sdk_reduce.txt",
            },
            "reference_issuer": {
                "status": "pass",
                "command": "cargo run --manifest-path core/rust/Cargo.toml -p grain-issuer-kit -- --pretty",
                "output": "logs/reference_issuer.txt",
            },
            "reference_issuer_verify": {
                "status": "pass",
                "command": "cargo test --manifest-path core/rust/Cargo.toml -p grain-issuer-kit generated_reference_qr_verifies_through_client_core",
                "output": "logs/reference_issuer_verify.txt",
            },
            "local_trust_bundle": {
                "status": "pass",
                "command": "python3 <inline local trust bundle writer>",
                "output": "logs/local_trust_bundle.txt",
            },
        },
        "reducer": {
            "expected": {
                "sum_mean": {"kcal": 620},
                "sum_var": {"kcal": 9},
            },
            "actual": {
                "sum_mean": {"kcal": 620},
                "sum_var": {"kcal": 9},
            },
        },
        "safe_report": {
            "raw_qr_string": "not_included",
            "raw_trust_material": "not_included",
            "raw_snapshot_material": "not_included",
            "raw_sync_material": "not_included",
        },
        "residual_gaps": [],
    }


class LocalFoodPilotReportTests(unittest.TestCase):
    def write_report(self, report: dict[str, object], proof: dict[str, object] | None = None) -> Path:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = Path(tmp.name)
        (root / "local-food-pilot.json").write_text(
            json.dumps(report, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        (root / "local-food-pilot-sdk-proof.json").write_text(
            json.dumps(proof if proof is not None else valid_proof(), indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        return root / "local-food-pilot.json"

    def test_valid_report_passes(self) -> None:
        module = load_module()
        path = self.write_report(valid_report())

        module.validate_report(path, expected_commit="b" * 40, require_clean=True)

    def test_report_rejects_inline_qr_or_trust_payload_fields(self) -> None:
        module = load_module()
        report = valid_report()
        report["qr_string"] = "GR1:INLINE-PAYLOAD"
        path = self.write_report(report)

        with self.assertRaisesRegex(SystemExit, "SDK_LOCAL_FOOD_PILOT_REPORT_ERR_FORBIDDEN_FIELD"):
            module.validate_report(path, expected_commit="b" * 40, require_clean=True)

    def test_report_requires_all_checks_to_pass(self) -> None:
        module = load_module()
        report = valid_report()
        checks = report["checks"]
        assert isinstance(checks, dict)
        sdk_reduce = checks["sdk_reduce"]
        assert isinstance(sdk_reduce, dict)
        sdk_reduce["status"] = "fail"
        path = self.write_report(report)

        with self.assertRaisesRegex(SystemExit, "SDK_LOCAL_FOOD_PILOT_REPORT_ERR_CHECK_STATUS"):
            module.validate_report(path, expected_commit="b" * 40, require_clean=True)

    def test_report_rejects_wrong_reducer_output(self) -> None:
        module = load_module()
        report = valid_report()
        reducer = report["reducer"]
        assert isinstance(reducer, dict)
        actual = reducer["actual"]
        assert isinstance(actual, dict)
        actual["sum_mean"] = {"kcal": 621}
        path = self.write_report(report)

        with self.assertRaisesRegex(SystemExit, "SDK_LOCAL_FOOD_PILOT_REPORT_ERR_REDUCER"):
            module.validate_report(path, expected_commit="b" * 40, require_clean=True)

    def test_report_rejects_proof_mismatch(self) -> None:
        module = load_module()
        proof = valid_proof()
        proof["reducer_out"] = {"sum_mean": {"kcal": 621}, "sum_var": {"kcal": 9}}
        path = self.write_report(valid_report(), proof)

        with self.assertRaisesRegex(SystemExit, "SDK_LOCAL_FOOD_PILOT_REPORT_ERR_PROOF_REDUCER"):
            module.validate_report(path, expected_commit="b" * 40, require_clean=True)


if __name__ == "__main__":
    unittest.main()
