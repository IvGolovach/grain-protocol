#!/usr/bin/env python3
"""Focused tests for release-evidence asset validation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "tools" / "ci" / "check_release_evidence_assets.py"
COMMIT = "0123456789abcdef0123456789abcdef01234567"
TAG = "repo-v1.2.3"


def load_module():
    spec = importlib.util.spec_from_file_location("check_release_evidence_assets", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise AssertionError("Could not load check_release_evidence_assets.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def write_evidence_zip(path: Path, *, sdk_failed: int = 0, tag: str = TAG) -> None:
    sdk_summary = {"total": 3, "passed": 3 - sdk_failed, "failed": sdk_failed}
    suite_summary = {
        "commit_sha": COMMIT,
        "strict": True,
        "rust_full": {"total": 1, "passed": 1, "failed": 0},
        "ts_c01": {"total": 1, "passed": 1, "failed": 0},
        "divergence_c01": {"total": 1, "mismatches": 0},
        "ts_full": {"total": 1, "passed": 1, "failed": 0},
        "ts_suite_runner": {"total": 1, "passed": 1, "failed": 0},
        "divergence_full": {"total": 1, "mismatches": 0},
        "properties_full": {"failed": 0},
        "sdk_suite": sdk_summary,
        "tag": tag,
    }
    suite_run = {
        "commit_sha": COMMIT,
        "tag": tag,
        "metadata": {"workflow": "release-evidence", "run_id": "1234"},
        "summary": suite_summary,
    }

    with zipfile.ZipFile(path, "w") as archive:
        archive.writestr("evidence/suite-summary.json", json.dumps(suite_summary))
        archive.writestr("evidence/suite-run.json", json.dumps(suite_run))
        archive.writestr("evidence/sdk-suite-summary.json", json.dumps(sdk_summary))
        archive.writestr(
            "evidence/evidence.sha256",
            "evidence_sha256 " + ("a" * 64) + "\n"
            + ("b" * 64) + " sdk-suite-summary.json\n",
        )


class ReleaseEvidenceAssetTests(unittest.TestCase):
    def test_valid_release_evidence_zip_passes(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            evidence_zip = Path(tmp) / f"evidence-{COMMIT}.zip"
            write_evidence_zip(evidence_zip)

            module.validate_evidence_zip(evidence_zip, expected_commit=COMMIT, expected_tag=TAG)

    def test_sdk_suite_failure_fails_release_evidence_zip(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            evidence_zip = Path(tmp) / f"evidence-{COMMIT}.zip"
            write_evidence_zip(evidence_zip, sdk_failed=1)

            with self.assertRaisesRegex(SystemExit, "RELEASE_EVIDENCE_ERR_SDK_SUITE"):
                module.validate_evidence_zip(evidence_zip, expected_commit=COMMIT, expected_tag=TAG)


if __name__ == "__main__":
    unittest.main()
