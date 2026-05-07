#!/usr/bin/env python3
"""Focused tests for third-party client certification reports."""

from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "tools" / "ci" / "check_external_client_certification.py"


def load_module():
    spec = importlib.util.spec_from_file_location("check_external_client_certification", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise AssertionError("Could not load check_external_client_certification.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def valid_report() -> dict[str, object]:
    return {
        "schema": "grain.external_client.certification.v1",
        "client": {
            "name": "Example Scanner",
            "owner": "external-team",
            "grain_commit": "0123456789abcdef0123456789abcdef01234567",
        },
        "checks": {
            "workflow_fixtures": {"status": "pass", "command": "python3 tools/ci/check_client_workflow_fixtures.py"},
            "no_network": {"status": "pass", "command": "python3 tools/ci/check_sdk_no_network.py"},
            "trust_provider": {"status": "pass", "command": "python3 tools/ci/check_sdk_trust_provider_boundary.py"},
            "secret_logging": {"status": "pass", "command": "python3 tools/ci/check_sdk_secret_logging.py"},
            "api_compatibility": {"status": "pass", "command": "python3 tools/ci/check_public_sdk_api.py"},
            "template_smoke": {"status": "pass", "command": "scripts/sdk/check_starter_templates.sh"},
            "no_secret_telemetry": {"status": "pass", "command": "python3 tools/ci/check_no_secret_telemetry.py"},
            "trust_governance": {"status": "pass", "command": "python3 tools/ci/check_trust_bundle_governance.py"},
        },
        "artifacts": {
            "source_handoff": "artifacts/sdk-release/0123456789abcdef0123456789abcdef01234567",
            "report_path": "artifacts/external-client-certification/example-scanner.json",
        },
        "residual_gaps": [],
    }


class ExternalClientCertificationTests(unittest.TestCase):
    def test_valid_report_returns_concise_summary(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "report.json"
            path.write_text(json.dumps(valid_report()) + "\n", encoding="utf-8")

            result = module.validate_report(path)

            self.assertEqual(result.client_name, "Example Scanner")
            self.assertEqual(result.grain_commit, "0123456789abcdef0123456789abcdef01234567")
            self.assertIn("8 checks passed", result.summary)

    def test_missing_required_check_is_rejected(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            report = valid_report()
            checks = dict(report["checks"])  # type: ignore[arg-type]
            del checks["trust_provider"]
            report["checks"] = checks
            path = Path(tmp) / "report.json"
            path.write_text(json.dumps(report) + "\n", encoding="utf-8")

            with self.assertRaisesRegex(SystemExit, "EXTERNAL_CLIENT_CERT_ERR_MISSING_CHECK"):
                module.validate_report(path)

    def test_failed_check_is_rejected(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            report = valid_report()
            checks = dict(report["checks"])  # type: ignore[arg-type]
            failed = dict(checks["secret_logging"])  # type: ignore[index]
            failed["status"] = "fail"
            checks["secret_logging"] = failed
            report["checks"] = checks
            path = Path(tmp) / "report.json"
            path.write_text(json.dumps(report) + "\n", encoding="utf-8")

            with self.assertRaisesRegex(SystemExit, "EXTERNAL_CLIENT_CERT_ERR_CHECK_NOT_PASS"):
                module.validate_report(path)


if __name__ == "__main__":
    unittest.main()
