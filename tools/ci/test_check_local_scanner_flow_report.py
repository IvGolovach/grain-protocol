#!/usr/bin/env python3
"""Focused tests for the local scanner DevKit report contract."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "tools" / "ci" / "check_local_scanner_flow_report.py"


def load_module():
    spec = importlib.util.spec_from_file_location("check_local_scanner_flow_report", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise AssertionError("Could not load check_local_scanner_flow_report.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def valid_report() -> dict[str, object]:
    return {
        "schema": "grain.sdk.local_scanner_flow.v1",
        "commit": "a" * 40,
        "dirty": False,
        "mode": "strict",
        "publication_boundary": "local-source-validation-only",
        "external_credentials": "not_required",
        "paid_developer_accounts": "not_required",
        "registry_publication": "not_included",
        "app_store_publication": "not_included",
        "play_console_publication": "not_included",
        "flow": [
            "sdk_doctor",
            "issuer_qr",
            "local_trust_bundle",
            "scanner_examples",
        ],
        "artifacts": {
            "issuer_output": "issuer-output.json",
            "qr_string": "qr-string.txt",
            "trust_bundle": "local-trust-bundle.json",
            "logs": "logs",
        },
        "checks": {
            "sdk_doctor": {
                "status": "pass",
                "command": "scripts/sdk/doctor",
                "output": "logs/sdk_doctor.txt",
            },
            "issuer_qr": {
                "status": "pass",
                "command": "cargo run --manifest-path core/rust/Cargo.toml -p grain-issuer-kit -- --pretty",
                "output": "logs/issuer_qr.txt",
            },
            "local_trust_bundle": {
                "status": "pass",
                "command": "python3 <inline trust bundle validator>",
                "output": "logs/local_trust_bundle.txt",
            },
            "scanner_examples": {
                "status": "pass",
                "command": "scripts/sdk/check_scanner_examples.sh",
                "output": "logs/scanner_examples.txt",
                "platforms": [
                    "ios-scanner",
                    "ios-reference-app",
                    "android-scanner",
                    "android-reference-app",
                    "wasm-scanner",
                ],
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


class LocalScannerFlowReportTests(unittest.TestCase):
    def write_report(self, report: dict[str, object]) -> Path:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        path = Path(tmp.name) / "report.json"
        path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        return path

    def test_valid_strict_report_passes(self) -> None:
        module = load_module()
        path = self.write_report(valid_report())

        module.validate_report(path, expected_commit="a" * 40, require_strict=True)

    def test_report_rejects_inline_secret_or_trust_payload_fields(self) -> None:
        module = load_module()
        report = valid_report()
        report["trust_pub_b64"] = "public-but-not-safe-for-summary"
        path = self.write_report(report)

        with self.assertRaisesRegex(SystemExit, "SDK_LOCAL_FLOW_REPORT_ERR_FORBIDDEN_FIELD"):
            module.validate_report(path, expected_commit="a" * 40, require_strict=True)

    def test_strict_report_requires_scanner_examples_pass(self) -> None:
        module = load_module()
        report = valid_report()
        checks = report["checks"]
        assert isinstance(checks, dict)
        scanner_examples = checks["scanner_examples"]
        assert isinstance(scanner_examples, dict)
        scanner_examples["status"] = "unsupported_prereq"
        scanner_examples["reason"] = "swift command not found"
        path = self.write_report(report)

        with self.assertRaisesRegex(SystemExit, "SDK_LOCAL_FLOW_REPORT_ERR_CHECK_STATUS"):
            module.validate_report(path, expected_commit="a" * 40, require_strict=True)

    def test_report_requires_sdk_doctor_in_flow(self) -> None:
        module = load_module()
        report = valid_report()
        flow = report["flow"]
        assert isinstance(flow, list)
        flow.remove("sdk_doctor")
        path = self.write_report(report)

        with self.assertRaisesRegex(SystemExit, "SDK_LOCAL_FLOW_REPORT_ERR_FLOW: sdk_doctor"):
            module.validate_report(path, expected_commit="a" * 40, require_strict=True)

    def test_report_rejects_inline_qr_as_artifact_path(self) -> None:
        module = load_module()
        report = valid_report()
        artifacts = report["artifacts"]
        assert isinstance(artifacts, dict)
        artifacts["qr_string"] = "GR1:INLINE-PAYLOAD"
        path = self.write_report(report)

        with self.assertRaisesRegex(SystemExit, "SDK_LOCAL_FLOW_REPORT_ERR_ARTIFACT_PATH"):
            module.validate_report(path, expected_commit="a" * 40, require_strict=True)


if __name__ == "__main__":
    unittest.main()
