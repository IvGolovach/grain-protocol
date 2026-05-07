#!/usr/bin/env python3
"""Focused tests for safe diagnostic telemetry policy."""

from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "tools" / "ci" / "check_no_secret_telemetry.py"


def load_module():
    spec = importlib.util.spec_from_file_location("check_no_secret_telemetry", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise AssertionError("Could not load check_no_secret_telemetry.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


class NoSecretTelemetryTests(unittest.TestCase):
    def test_safe_schema_accepts_only_redacted_diagnostics(self) -> None:
        module = load_module()
        schema = {
            "properties": {
                "event_name": {"const": "grain.scan.failed"},
                "workflow": {"enum": ["scan_preview"]},
                "error_code": {"type": "string"},
                "anchor_id": {"type": "string"},
                "redacted": {"const": True},
            }
        }

        module.validate_telemetry_object(schema, Path("safe.schema.json"))

    def test_schema_rejects_portable_secret_fields(self) -> None:
        module = load_module()
        schema = {
            "properties": {
                "event_name": {"type": "string"},
                "snapshotB64": {"type": "string"},
            }
        }

        with self.assertRaisesRegex(SystemExit, "NO_SECRET_TELEMETRY_ERR_SECRET_FIELD"):
            module.validate_telemetry_object(schema, Path("unsafe.schema.json"))

    def test_repository_scan_rejects_secret_examples(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = root / "sdk" / "workflows" / "contract"
            target.mkdir(parents=True)
            (target / "diagnostic_example.json").write_text(
                json.dumps({"event_name": "grain.debug", "identity_bundle": "secret"}) + "\n",
                encoding="utf-8",
            )

            with self.assertRaisesRegex(SystemExit, "NO_SECRET_TELEMETRY_ERR_SECRET_FIELD"):
                module.scan_root(root)


if __name__ == "__main__":
    unittest.main()
