#!/usr/bin/env python3
"""Focused tests for trust bundle governance validation."""

from __future__ import annotations

import importlib.util
import hashlib
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "tools" / "ci" / "check_trust_bundle_governance.py"


def load_module():
    spec = importlib.util.spec_from_file_location("check_trust_bundle_governance", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise AssertionError("Could not load check_trust_bundle_governance.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def governed_bundle() -> dict[str, object]:
    bundle: dict[str, object] = {
        "bundle_v": 1,
        "governance": {
            "bundle_id": "example-prod",
            "revision": "2026-05-07.1",
            "signature_ref": "signatures/example-prod-2026-05-07.sig",
            "reviewed_by": "security-review",
            "fail_closed": True,
        },
        "anchors": [
            {
                "id": "publisher:primary",
                "state": "active",
                "trust_pub_b64": "YHqypLfKbLygpiN7hlth/fzXA25wsf2wOp3LCN5uhas=",
            }
        ],
    }
    payload = {
        "bundle_v": bundle["bundle_v"],
        "anchors": bundle["anchors"],
    }
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    governance = dict(bundle["governance"])  # type: ignore[arg-type]
    governance["checksum_sha256"] = hashlib.sha256(encoded).hexdigest()
    bundle["governance"] = governance
    return bundle


class TrustBundleGovernanceTests(unittest.TestCase):
    def test_governed_bundle_is_accepted(self) -> None:
        module = load_module()
        module.validate_bundle(governed_bundle(), Path("prod-bundle.json"))

    def test_missing_checksum_is_rejected(self) -> None:
        module = load_module()
        bundle = governed_bundle()
        governance = dict(bundle["governance"])  # type: ignore[arg-type]
        del governance["checksum_sha256"]
        bundle["governance"] = governance

        with self.assertRaisesRegex(SystemExit, "TRUST_BUNDLE_GOV_ERR_GOVERNANCE"):
            module.validate_bundle(bundle, Path("prod-bundle.json"))

    def test_unknown_anchor_state_is_rejected_fail_closed(self) -> None:
        module = load_module()
        bundle = governed_bundle()
        anchors = list(bundle["anchors"])  # type: ignore[arg-type]
        anchor = dict(anchors[0])  # type: ignore[index]
        anchor["state"] = "testing"
        anchors[0] = anchor
        bundle["anchors"] = anchors

        with self.assertRaisesRegex(SystemExit, "TRUST_BUNDLE_GOV_ERR_ANCHOR_STATE"):
            module.validate_bundle(bundle, Path("prod-bundle.json"))

    def test_checksum_mismatch_is_rejected(self) -> None:
        module = load_module()
        bundle = governed_bundle()
        governance = dict(bundle["governance"])  # type: ignore[arg-type]
        governance["checksum_sha256"] = "b" * 64
        bundle["governance"] = governance

        with self.assertRaisesRegex(SystemExit, "TRUST_BUNDLE_GOV_ERR_CHECKSUM_MISMATCH"):
            module.validate_bundle(bundle, Path("prod-bundle.json"))


if __name__ == "__main__":
    unittest.main()
