#!/usr/bin/env python3
"""Focused tests for repo-native developer platform metadata."""

from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "tools" / "ci" / "check_repo_native_developer_platform.py"


def load_module():
    spec = importlib.util.spec_from_file_location("check_repo_native_developer_platform", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise AssertionError("Could not load check_repo_native_developer_platform.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


class RepoNativeDeveloperPlatformTests(unittest.TestCase):
    def test_current_repo_metadata_passes(self) -> None:
        module = load_module()
        module.check_all()

    def test_security_pack_requires_all_nine_findings(self) -> None:
        module = load_module()
        original = module.load_json
        try:
            module.load_json = lambda _relative: {
                "schema": "grain.security-regressions.v1",
                "findings": [{"id": "GRAIN-SEC-01", "evidence": []}],
            }
            with self.assertRaisesRegex(SystemExit, "REPO_NATIVE_PLATFORM_ERR_SECURITY_ID_COVERAGE"):
                module.validate_security_regressions({})
        finally:
            module.load_json = original

    def test_interop_matrix_rejects_unknown_wasm_vector(self) -> None:
        module = load_module()
        vectors = module.vector_index()
        original_read_text = Path.read_text

        def fake_read_text(self: Path, *args, **kwargs):
            if str(self).endswith("runner/typescript/profiles/wasm-subset.json"):
                return '{"vector_ids":["NO-SUCH-VECTOR"]}'
            return original_read_text(self, *args, **kwargs)

        original = Path.read_text
        try:
            Path.read_text = fake_read_text
            with self.assertRaisesRegex(SystemExit, "REPO_NATIVE_PLATFORM_ERR_INTEROP_WASM_VECTOR"):
                module.validate_interop_matrix(vectors)
        finally:
            Path.read_text = original


if __name__ == "__main__":
    unittest.main()
