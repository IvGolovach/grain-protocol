#!/usr/bin/env python3
"""Focused tests for SDK release package archive policy."""

from __future__ import annotations

import importlib.util
import io
import tarfile
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "tools" / "ci" / "check_sdk_release_package.py"


def load_module():
    spec = importlib.util.spec_from_file_location("check_sdk_release_package", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise AssertionError("Could not load check_sdk_release_package.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def write_archive_with_member(path: Path, member_name: str) -> None:
    payload = b"do-not-package-local-env"
    info = tarfile.TarInfo(member_name)
    info.size = len(payload)
    info.mode = 0o600
    with tarfile.open(path, "w:gz") as archive:
        archive.addfile(info, io.BytesIO(payload))


class SdkReleasePackageArchivePolicyTests(unittest.TestCase):
    def test_dotenv_variant_is_rejected_from_source_archives(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            archive_path = Path(tmp) / "artifact.tar.gz"
            write_archive_with_member(archive_path, "sdk/wasm/.env.local")

            with self.assertRaisesRegex(SystemExit, "SDK_RELEASE_CHECK_ERR_SECRET_ARCHIVE_ENTRY"):
                module.validate_archive(archive_path, {"required_entries": []})

    def test_release_policy_rejects_store_and_registry_publication_claims(self) -> None:
        module = load_module()
        policy = {
            "release_kind": "source-archive",
            "wasm_binary": "not_included_source_only",
            "platform_store_packages": "not_included",
            "registry_publication": "not_included",
            "notes": "Ready for TestFlight and npm publish",
        }

        with self.assertRaisesRegex(SystemExit, "SDK_RELEASE_CHECK_ERR_PUBLICATION_CLAIM"):
            module.validate_artifact_policy(policy)

    def test_reference_apps_and_device_contract_are_required_entries(self) -> None:
        module = load_module()

        rust_core = module.EXPECTED_ARTIFACTS["grain-rust-client-core"]["required_entries"]
        typescript = module.EXPECTED_ARTIFACTS["grain-typescript-sdk"]["required_entries"]
        workflow = module.EXPECTED_ARTIFACTS["grain-sdk-workflow-contract"]["required_entries"]
        starters = module.EXPECTED_ARTIFACTS["grain-starter-templates"]["required_entries"]

        self.assertIn("core/rust/Cargo.toml", rust_core)
        self.assertIn("core/rust/grain-core/Cargo.toml", rust_core)
        self.assertIn("core/rust/grain-client-core/Cargo.toml", rust_core)
        self.assertIn("core/ts/grain-ts-core/package.json", typescript)
        self.assertIn("core/ts/grain-sdk/package.json", typescript)
        self.assertIn("core/ts/grain-sdk-ai/package.json", typescript)
        self.assertIn("fixtures/external-consumers/npm-sdk/src/runtime-smoke.mjs", typescript)
        self.assertIn("sdk/device/device_adapter_v1.schema.json", workflow)
        self.assertIn("sdk/device/README.md", workflow)
        self.assertIn("examples/ios-reference-app/Package.swift", starters)
        self.assertIn("examples/android-reference-app/build.gradle.kts", starters)
        self.assertIn("scripts/sdk/run_local_scanner_flow.sh", starters)
        self.assertIn("tools/ci/check_local_scanner_flow_report.py", starters)

    def test_consumer_install_paths_are_required_and_bounded(self) -> None:
        module = load_module()

        module.validate_consumer_paths(
            "grain-swift-client",
            {"consumer_paths": ["sdk/swift"]},
        )
        module.validate_consumer_paths(
            "grain-typescript-sdk",
            {
                "consumer_paths": [
                    "core/ts/grain-ts-core",
                    "core/ts/grain-sdk",
                    "core/ts/grain-sdk-ai",
                    "fixtures/external-consumers/npm-sdk",
                ]
            },
        )

        with self.assertRaisesRegex(SystemExit, "SDK_RELEASE_CHECK_ERR_CONSUMER_PATHS"):
            module.validate_consumer_paths("grain-swift-client", {})

        with self.assertRaisesRegex(SystemExit, "SDK_RELEASE_CHECK_ERR_CONSUMER_PATH"):
            module.validate_consumer_paths(
                "grain-swift-client",
                {"consumer_paths": ["/tmp/grain"]},
            )


if __name__ == "__main__":
    unittest.main()
