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
        "certification_scope": {
            "mode": "local-source-validation",
            "publication_boundary": "source-validation-only",
            "registry_publication": "not_included",
            "app_store_publication": "not_included",
            "play_console_publication": "not_included",
            "npm_publication": "not_included",
            "maven_central_publication": "not_included",
            "external_credentials": "not_required",
            "paid_developer_accounts": "not_required",
        },
        "client": {
            "name": "Example Scanner",
            "owner": "external-team",
            "grain_commit": "0123456789abcdef0123456789abcdef01234567",
        },
        "checks": {
            "workflow_fixtures": {
                "status": "pass",
                "command": "python3 tools/ci/check_client_workflow_fixtures.py",
                "output": "logs/workflow_fixtures.txt",
            },
            "no_network": {
                "status": "pass",
                "command": "python3 tools/ci/check_sdk_no_network.py",
                "output": "logs/no_network.txt",
            },
            "trust_provider": {
                "status": "pass",
                "command": "python3 tools/ci/check_sdk_trust_provider_boundary.py",
                "output": "logs/trust_provider.txt",
            },
            "secret_logging": {
                "status": "pass",
                "command": "python3 tools/ci/check_sdk_secret_logging.py",
                "output": "logs/secret_logging.txt",
            },
            "api_compatibility": {
                "status": "pass",
                "command": "python3 tools/ci/check_public_sdk_api.py",
                "output": "logs/api_compatibility.txt",
            },
            "starter_templates": {
                "status": "pass",
                "command": "scripts/sdk/check_starter_templates.sh",
                "output": "logs/starter_templates.txt",
            },
            "ios_reference_app": {
                "status": "pass",
                "command": "scripts/sdk/check_ios_reference_app.sh",
                "output": "logs/ios_reference_app.txt",
            },
            "android_reference_app": {
                "status": "pass",
                "command": "scripts/sdk/check_android_reference_app.sh",
                "output": "logs/android_reference_app.txt",
            },
            "device_contract": {
                "status": "pass",
                "command": "python3 tools/ci/check_device_adapter_contract.py",
                "output": "logs/device_contract.txt",
            },
            "no_secret_telemetry": {
                "status": "pass",
                "command": "python3 tools/ci/check_no_secret_telemetry.py",
                "output": "logs/no_secret_telemetry.txt",
            },
            "trust_governance": {
                "status": "pass",
                "command": "python3 tools/ci/check_trust_bundle_governance.py",
                "output": "logs/trust_governance.txt",
            },
            "registry_dry_runs": {
                "status": "pass",
                "command": "scripts/sdk/check_registry_dry_runs.sh --out-dir artifacts/cert/registry-dry-runs",
                "output": "logs/registry_dry_runs.txt",
            },
            "sdk_release_package": {
                "status": "pass",
                "command": "scripts/sdk/package_client_sdks.sh --out-dir artifacts/cert/sdk-release --skip-verify --allow-dirty",
                "output": "logs/sdk_release_package.txt",
            },
            "release_consumer": {
                "status": "pass",
                "command": "python3 tools/ci/check_external_consumer_templates.py --out-dir artifacts/cert/sdk-release",
                "output": "logs/release_consumer.txt",
            },
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
            self.assertIn("14 checks passed", result.summary)

    def test_missing_required_check_is_rejected(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            report = valid_report()
            checks = dict(report["checks"])  # type: ignore[arg-type]
            del checks["device_contract"]
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

    def test_publication_claim_is_rejected_from_scope(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            report = valid_report()
            scope = dict(report["certification_scope"])  # type: ignore[arg-type]
            scope["app_store_publication"] = "TestFlight beta"
            report["certification_scope"] = scope
            path = Path(tmp) / "report.json"
            path.write_text(json.dumps(report) + "\n", encoding="utf-8")

            with self.assertRaisesRegex(SystemExit, "EXTERNAL_CLIENT_CERT_ERR_PUBLICATION_CLAIM"):
                module.validate_report(path)

    def test_required_credentials_are_rejected(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            report = valid_report()
            scope = dict(report["certification_scope"])  # type: ignore[arg-type]
            scope["external_credentials"] = "required"
            report["certification_scope"] = scope
            path = Path(tmp) / "report.json"
            path.write_text(json.dumps(report) + "\n", encoding="utf-8")

            with self.assertRaisesRegex(SystemExit, "EXTERNAL_CLIENT_CERT_ERR_CREDENTIAL_CLAIM"):
                module.validate_report(path)


if __name__ == "__main__":
    unittest.main()
