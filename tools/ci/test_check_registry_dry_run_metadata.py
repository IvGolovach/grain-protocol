#!/usr/bin/env python3
"""Focused tests for SDK registry dry-run metadata policy."""

from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "tools" / "ci" / "check_registry_dry_run_metadata.py"
COMMIT = "0123456789abcdef0123456789abcdef01234567"


def load_module():
    spec = importlib.util.spec_from_file_location("check_registry_dry_run_metadata", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise AssertionError("Could not load check_registry_dry_run_metadata.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def valid_metadata() -> dict[str, object]:
    return {
        "schema": "grain.sdk.registry_dry_run.v1",
        "commit": COMMIT,
        "dirty": False,
        "credentials": "not_required",
        "external_credentials": "not_required",
        "publication_boundary": "local-source-validation-only",
        "registry_publication": "not_included",
        "package_registry_publication": "not_included",
        "store_publication": "not_included",
        "platform_store_publication": "not_included",
        "channels": [
            {
                "name": "swiftpm",
                "ecosystem": "swiftpm",
                "mode": "dry-run-only",
                "publication": "none",
                "store_publication": "none",
                "credentials": "not_required",
                "external_credentials": "not_required",
                "command": ["swift", "package", "--package-path", "sdk/swift", "describe", "--type", "json"],
                "output": "swiftpm-package-describe.json",
            },
            {
                "name": "maven-local",
                "ecosystem": "maven-local",
                "mode": "dry-run-only",
                "publication": "local-dry-run",
                "store_publication": "none",
                "credentials": "not_required",
                "external_credentials": "not_required",
                "command": ["sdk/kotlin/gradlew", "-p", "sdk/kotlin", "publishToMavenLocal", "--dry-run"],
                "output": "maven-local-publish-dry-run.txt",
            },
            {
                "name": "npm-pack",
                "ecosystem": "npm-pack",
                "mode": "dry-run-only",
                "publication": "pack-only",
                "store_publication": "none",
                "credentials": "not_required",
                "external_credentials": "not_required",
                "command": ["npm", "pack", "--dry-run", "--json"],
                "output": "npm-pack-dry-run.json",
            },
        ],
    }


def write_metadata(path: Path, data: dict[str, object]) -> None:
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")


class RegistryDryRunMetadataTests(unittest.TestCase):
    def test_accepts_dry_run_only_registry_metadata(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "registry-dry-runs.json"
            write_metadata(path, valid_metadata())

            metadata = module.validate_metadata(path)

            self.assertEqual(metadata["commit"], COMMIT)

    def test_rejects_real_registry_publication_claim(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "registry-dry-runs.json"
            data = valid_metadata()
            data["channels"][2]["publication"] = "npm-registry"
            write_metadata(path, data)

            with self.assertRaisesRegex(SystemExit, "REGISTRY_DRY_RUN_ERR_PUBLICATION_CLAIM"):
                module.validate_metadata(path)

    def test_rejects_platform_store_publication_claim(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "registry-dry-runs.json"
            data = valid_metadata()
            data["channels"][0]["store_publication"] = "app-store-connect"
            write_metadata(path, data)

            with self.assertRaisesRegex(SystemExit, "REGISTRY_DRY_RUN_ERR_STORE_PUBLICATION_CLAIM"):
                module.validate_metadata(path)

    def test_rejects_credential_environment_contracts(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "registry-dry-runs.json"
            data = valid_metadata()
            data["channels"][1]["credential_env"] = ["MAVEN_CENTRAL_TOKEN"]
            write_metadata(path, data)

            with self.assertRaisesRegex(SystemExit, "REGISTRY_DRY_RUN_ERR_CREDENTIAL_CLAIM"):
                module.validate_metadata(path)

    def test_rejects_top_level_registry_publication_claim(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "registry-dry-runs.json"
            data = valid_metadata()
            data["registry_publication"] = "maven-central"
            write_metadata(path, data)

            with self.assertRaisesRegex(SystemExit, "REGISTRY_DRY_RUN_ERR_PUBLICATION_CLAIM"):
                module.validate_metadata(path)

    def test_rejects_publication_claim_in_freeform_metadata(self) -> None:
        module = load_module()
        forbidden_values = [
            "Ready for App Store review",
            "TestFlight upload completed",
            "Play Console release is configured",
            "npm publish is available",
            "Maven Central credentials are required",
        ]
        for value in forbidden_values:
            with self.subTest(value=value), tempfile.TemporaryDirectory() as tmp:
                path = Path(tmp) / "registry-dry-runs.json"
                data = valid_metadata()
                data["notes"] = value
                write_metadata(path, data)

                with self.assertRaisesRegex(
                    SystemExit,
                    "REGISTRY_DRY_RUN_ERR_FORBIDDEN_PUBLICATION_CLAIM",
                ):
                    module.validate_metadata(path)

    def test_rejects_required_external_credentials(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "registry-dry-runs.json"
            data = valid_metadata()
            data["external_credentials"] = "required"
            write_metadata(path, data)

            with self.assertRaisesRegex(SystemExit, "REGISTRY_DRY_RUN_ERR_CREDENTIAL_CLAIM"):
                module.validate_metadata(path)


if __name__ == "__main__":
    unittest.main()
