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


if __name__ == "__main__":
    unittest.main()
