#!/usr/bin/env python3
"""Focused tests for SDK compatibility matrix validation."""

from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "tools" / "ci" / "check_sdk_compatibility_matrix.py"
COMMIT = "0123456789abcdef0123456789abcdef01234567"


def load_module():
    spec = importlib.util.spec_from_file_location("check_sdk_compatibility_matrix", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise AssertionError("Could not load check_sdk_compatibility_matrix.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def write_manifest(path: Path, *, kotlin_version: str = "0.1.0", wasm_commit: str = COMMIT) -> None:
    path.write_text(
        json.dumps(
            {
                "schema": "grain.sdk.release.manifest.v1",
                "commit": COMMIT,
                "workflow_contract": "client_workflow_v1",
                "version_matrix": {"rule": "same-repo-sha"},
                "sdk_versions": {
                    "swift_client": {"version": "repo-sha", "commit": COMMIT},
                    "kotlin_client": {"version": kotlin_version, "commit": COMMIT},
                    "wasm_client": {"version": "0.1.0", "commit": wasm_commit},
                    "grain_client_core": {"version": "0.1.0", "commit": COMMIT},
                    "grain_client_wasm": {"version": "0.1.0", "commit": COMMIT},
                },
                "artifacts": [
                    {"name": "grain-swift-client", "kind": "swift-client", "file": f"grain-swift-client-{COMMIT}.tar.gz"},
                    {"name": "grain-kotlin-client", "kind": "kotlin-client", "file": f"grain-kotlin-client-{COMMIT}.tar.gz"},
                    {"name": "grain-wasm-client", "kind": "wasm-client", "file": f"grain-wasm-client-{wasm_commit}.tar.gz"},
                ],
            }
        )
        + "\n",
        encoding="utf-8",
    )


def matrix() -> dict[str, object]:
    return {
        "schema": "grain.sdk.compatibility-matrix.v1",
        "default_rule": "same-repo-sha",
        "supported": [
            {
                "grain_commit": COMMIT,
                "workflow_contract": "client_workflow_v1",
                "swift_client": "repo-sha",
                "kotlin_client": "0.1.0",
                "wasm_client": "0.1.0",
                "grain_client_core": "0.1.0",
                "grain_client_wasm": "0.1.0",
            }
        ],
    }


def repo_sha_matrix() -> dict[str, object]:
    data = matrix()
    data["supported"][0]["grain_commit"] = "repo-sha"
    return data


class SdkCompatibilityMatrixTests(unittest.TestCase):
    def test_same_sha_manifest_matches_matrix(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            manifest_path = Path(tmp) / "manifest.json"
            write_manifest(manifest_path)

            result = module.check_sdk_compatibility_matrix(
                manifest_path=manifest_path,
                matrix_data=matrix(),
            )

            self.assertEqual(result.commit, COMMIT)
            self.assertEqual(result.rule, "same-repo-sha")

    def test_repo_sha_placeholder_matches_same_sha_manifest(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            manifest_path = Path(tmp) / "manifest.json"
            write_manifest(manifest_path)

            result = module.check_sdk_compatibility_matrix(
                manifest_path=manifest_path,
                matrix_data=repo_sha_matrix(),
            )

            self.assertEqual(result.commit, COMMIT)

    def test_mixed_sha_manifest_is_rejected(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            manifest_path = Path(tmp) / "manifest.json"
            write_manifest(manifest_path, wasm_commit="fedcba9876543210fedcba9876543210fedcba98")

            with self.assertRaisesRegex(SystemExit, "SDK_COMPAT_MATRIX_ERR_COMPONENT_COMMIT"):
                module.check_sdk_compatibility_matrix(
                    manifest_path=manifest_path,
                    matrix_data=matrix(),
                )

    def test_version_not_in_matrix_is_rejected(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            manifest_path = Path(tmp) / "manifest.json"
            write_manifest(manifest_path, kotlin_version="0.2.0")

            with self.assertRaisesRegex(SystemExit, "SDK_COMPAT_MATRIX_ERR_UNSUPPORTED_COMBINATION"):
                module.check_sdk_compatibility_matrix(
                    manifest_path=manifest_path,
                    matrix_data=matrix(),
                )


if __name__ == "__main__":
    unittest.main()
