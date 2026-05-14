#!/usr/bin/env python3
"""Focused tests for invariant audit coverage evidence."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "tools" / "ci" / "audit_invariants.py"


def write_invariants(path: Path, static_line: str) -> None:
    path.write_text(
        "# INVARIANTS\n\n"
        "## Food Profile\n\n"
        "- INV-FOOD-001: `source_class` MUST use the fixed Food Profile vocabulary.\n"
        "  Ref: spec/profiles/food-profile.md\n"
        f"  {static_line}\n",
        encoding="utf-8",
    )


class InvariantAuditTests(unittest.TestCase):
    def test_static_check_coverage_counts_as_covered(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            invariants = root / "INVARIANTS.md"
            vectors_root = root / "vectors"
            static_root = root / "static_checks"
            out_json = root / "audit.json"
            out_md = root / "audit.md"
            vectors_root.mkdir()
            static_root.mkdir()
            (static_root / "STATIC-FOOD-PROFILE-001.json").write_text("{}\n", encoding="utf-8")
            write_invariants(invariants, "Static: STATIC-FOOD-PROFILE-001")

            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "--invariants",
                    str(invariants),
                    "--vectors-root",
                    str(vectors_root),
                    "--static-checks-root",
                    str(static_root),
                    "--out-json",
                    str(out_json),
                    "--out-md",
                    str(out_md),
                ],
                check=False,
                text=True,
                capture_output=True,
            )

            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
            report = json.loads(out_json.read_text(encoding="utf-8"))
            self.assertEqual(report["status"], "PASS")
            self.assertEqual(report["uncovered_invariants"], [])
            self.assertEqual(report["rows"][0]["static_checks"], ["STATIC-FOOD-PROFILE-001"])

    def test_missing_static_check_file_is_reported(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            invariants = root / "INVARIANTS.md"
            vectors_root = root / "vectors"
            static_root = root / "static_checks"
            out_json = root / "audit.json"
            out_md = root / "audit.md"
            vectors_root.mkdir()
            static_root.mkdir()
            write_invariants(invariants, "Static: STATIC-FOOD-PROFILE-404")

            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "--invariants",
                    str(invariants),
                    "--vectors-root",
                    str(vectors_root),
                    "--static-checks-root",
                    str(static_root),
                    "--out-json",
                    str(out_json),
                    "--out-md",
                    str(out_md),
                ],
                check=False,
                text=True,
                capture_output=True,
            )

            self.assertNotEqual(result.returncode, 0)
            report = json.loads(out_json.read_text(encoding="utf-8"))
            self.assertEqual(
                report["missing_static_check_files"],
                [{"invariant": "INV-FOOD-001", "static_check_id": "STATIC-FOOD-PROFILE-404"}],
            )


if __name__ == "__main__":
    unittest.main()
