#!/usr/bin/env python3
"""Tests for GitHub workflow and composite-action pinning policy."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from tools.ci import check_workflow_action_pinning as pinning

PINNED_SHA = "de0fac2e4500dabe0009e67214ff5f5447ce83dd"


class WorkflowActionPinningTests(unittest.TestCase):
    def test_accepts_sha_pinned_workflow_and_composite_action_refs(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            workflow = root / ".github" / "workflows" / "ci.yml"
            action = root / ".github" / "actions" / "setup" / "action.yml"
            workflow.parent.mkdir(parents=True)
            action.parent.mkdir(parents=True)
            workflow.write_text(
                f"steps:\n  - uses: actions/checkout@{PINNED_SHA}\n",
                encoding="utf-8",
            )
            action.write_text(
                f"runs:\n  using: composite\n  steps:\n    - uses: actions/setup-node@{PINNED_SHA}\n",
                encoding="utf-8",
            )

            self.assertEqual([], pinning.find_violations(root))

    def test_flags_unpinned_composite_action_refs(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            action = root / ".github" / "actions" / "setup" / "action.yml"
            action.parent.mkdir(parents=True)
            action.write_text(
                "runs:\n  using: composite\n  steps:\n    - uses: actions/setup-node@v4\n",
                encoding="utf-8",
            )

            self.assertEqual(
                [
                    ".github/actions/setup/action.yml:4 action not SHA-pinned: actions/setup-node@v4",
                ],
                pinning.find_violations(root),
            )


if __name__ == "__main__":
    unittest.main()
