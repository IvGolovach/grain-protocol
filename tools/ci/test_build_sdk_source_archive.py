#!/usr/bin/env python3
"""Prove source package bytes survive distinct checkout metadata and ordering."""

from __future__ import annotations

import os
import tarfile
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path

from tools.ci.build_sdk_source_archive import build_archive
from tools.ci.build_sdk_release_metadata import source_created_at
from tools.ci.check_sdk_package_reproducibility import compare_packages


class SdkSourceArchiveTests(unittest.TestCase):
    def test_distinct_checkouts_produce_identical_archives(self) -> None:
        """Host metadata and creation order must not change source archive bytes."""
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            outputs = []
            long_name = "\u0434" * 80 + ".txt"
            files = [("src/run.sh", b"#!/bin/sh\nexit 0\n"), (f"src/{long_name}", b"content\n")]
            for index in range(2):
                root = base / f"checkout-{index}"
                root.mkdir()
                (root / "src").mkdir(mode=0o700 if index else 0o755)
                (root / "src/empty").mkdir()
                for name, content in (files if index == 0 else list(reversed(files))):
                    path = root / name
                    path.write_bytes(content)
                    path.chmod((0o711 if index else 0o755) if name.endswith(".sh") else (0o600 if index else 0o644))
                    os.utime(path, (100 + index, 200 + index))
                (root / "src/build").mkdir()
                (root / "src/build/cache").write_text("excluded")
                (root / "src/._metadata").write_text("excluded")
                output = base / f"different-output-{index}.tar.gz"
                build_archive(output, root, ["src"], ["src/build", "._*"], 1_700_000_000)
                outputs.append(output.read_bytes())
                with tarfile.open(output) as archive:
                    names = archive.getnames()
                    self.assertEqual(names, sorted(names))
                    self.assertNotIn("src/build", names)
                    self.assertNotIn("src/._metadata", names)
                    self.assertEqual(archive.extractfile("src/run.sh").read(), files[0][1])
                    self.assertEqual(archive.getmember("src/run.sh").mode, 0o755)
                    self.assertEqual(archive.getmember(f"src/{long_name}").mode, 0o644)
                    for member in archive:
                        self.assertEqual((member.uid, member.gid, member.uname, member.gname, member.mtime), (0, 0, "", "", 1_700_000_000))
                        self.assertFalse({"atime", "ctime"} & member.pax_headers.keys())
            self.assertEqual(outputs[0], outputs[1])
            self.assertEqual(outputs[0][3], 0)  # No original output filename in gzip.
            self.assertEqual(int.from_bytes(outputs[0][4:8], "little"), 1_700_000_000)

    def test_input_order_and_overlapping_roots_do_not_duplicate_entries(self) -> None:
        """Overlapping roots must preserve one sorted entry for each source path."""
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "src").mkdir()
            (root / "src/a").write_text("a")
            (root / "src/b").write_text("b")
            a, b = root / "a.gz", root / "b.gz"
            build_archive(a, root, ["src", "src/a"], [], 0)
            build_archive(b, root, ["src/a", "src"], [], 0)
            self.assertEqual(a.read_bytes(), b.read_bytes())

    def test_rejects_symlinks_traversal_and_invalid_epoch(self) -> None:
        """Reject paths and timestamps outside the source archive contract."""
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "link").symlink_to("/tmp")
            for paths, epoch, code in [(["link"], 0, "FILE_TYPE"), (["link/child"], 0, "FILE_TYPE"), (["../escape"], 0, "PATH"), (["/tmp"], 0, "PATH"), (["link"], -1, "SOURCE_EPOCH")]:
                with self.subTest(paths=paths, epoch=epoch):
                    with self.assertRaisesRegex(ValueError, f"SDK_ARCHIVE_ERR_{code}"):
                        build_archive(root / "result.gz", root, paths, [], epoch)

    def test_metadata_uses_commit_time_in_utc(self) -> None:
        """Release timestamps must identify the supplied full commit in UTC."""
        with patch("tools.ci.build_sdk_release_metadata.subprocess.check_output", return_value="1700000000\n"):
            self.assertEqual(source_created_at("a" * 40), "2023-11-14T22:13:20Z")
        with self.assertRaisesRegex(ValueError, "SDK_RELEASE_METADATA_ERR_COMMIT"):
            source_created_at("HEAD")

    def test_comparison_rejects_missing_or_changed_artifacts_and_metadata(self) -> None:
        """A reproducibility report requires the same archive set and file bytes."""
        with tempfile.TemporaryDirectory() as tmp:
            a, b = Path(tmp) / "a", Path(tmp) / "b"
            a.mkdir()
            b.mkdir()
            with self.assertRaisesRegex(ValueError, "SDK_REPRO_ERR_ARTIFACT_SET"):
                compare_packages(a, b)
            for name in ("source.tar.gz", "manifest.json", "SHA256SUMS", "sbom.spdx.json"):
                (a / name).write_bytes(b"same")
                (b / name).write_bytes(b"same")
            self.assertEqual(compare_packages(a, b)["file_count"], 4)
            for name in ("source.tar.gz", "manifest.json", "sbom.spdx.json"):
                (b / name).write_bytes(b"changed")
                with self.assertRaisesRegex(ValueError, "SDK_REPRO_ERR_BYTES"):
                    compare_packages(a, b)
                (b / name).write_bytes(b"same")
            (b / "source.tar.gz").unlink()
            with self.assertRaisesRegex(ValueError, "SDK_REPRO_ERR_ARTIFACT_SET"):
                compare_packages(a, b)


if __name__ == "__main__":
    unittest.main()
