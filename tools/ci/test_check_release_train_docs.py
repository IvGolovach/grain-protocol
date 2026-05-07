#!/usr/bin/env python3
"""Focused tests for SDK security review and release train docs."""

from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "tools" / "ci" / "check_release_train_docs.py"


def load_module():
    spec = importlib.util.spec_from_file_location("check_release_train_docs", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise AssertionError("Could not load check_release_train_docs.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


SECURITY_REVIEW = """# SDK Security Review

## Review Scope
Replay, trust injection, snapshot leakage, pairing misuse, unsafe logs, backup
leakage, and app-shell divergence are reviewed before app promotion.

## Required Evidence
The review records local trust bundle evidence, no secret telemetry proof,
custody adapter decisions, and release evidence before any registry, store,
hardware custody, or robot fleet claim.
"""

RELEASE_TRAIN = """# SDK Release Train

## Trains
Protocol/core, SDK source, starter-template, registry-ready, and app release
trains move separately.

## Evidence Language
Registry, store, and hardware claims require explicit release evidence. Until
that evidence exists, the current channel is source-only.
"""


class ReleaseTrainDocsTests(unittest.TestCase):
    def test_required_docs_pass_with_evidence_language(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            docs = Path(tmp) / "docs" / "human" / "sdk"
            docs.mkdir(parents=True)
            (docs / "security-review.md").write_text(SECURITY_REVIEW, encoding="utf-8")
            (docs / "release-train.md").write_text(RELEASE_TRAIN, encoding="utf-8")

            module.check_docs(Path(tmp))

    def test_registry_claim_without_evidence_is_rejected(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            docs = Path(tmp) / "docs" / "human" / "sdk"
            docs.mkdir(parents=True)
            (docs / "security-review.md").write_text(SECURITY_REVIEW, encoding="utf-8")
            (docs / "release-train.md").write_text(
                "# SDK Release Train\n\nThe npm package is published and store ready.\n",
                encoding="utf-8",
            )

            with self.assertRaisesRegex(SystemExit, "RELEASE_TRAIN_DOCS_ERR_MISSING_TOKEN"):
                module.check_docs(Path(tmp))


if __name__ == "__main__":
    unittest.main()
