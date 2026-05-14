#!/usr/bin/env python3
"""Tests for golden image publication policy guard."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from tools.ci import check_golden_images_policy as policy


GOOD_WORKFLOW = """
on:
  push:
    tags:
      - "repo-*"
      - "repo-rc-*"
steps:
  - run: |
      if [[ "${GITHUB_REF_TYPE}" != "tag" ]]; then
        echo "GOLDEN_ERR_TAG_REQUIRED"
      fi
      if [[ "${GITHUB_REF_NAME}" == repo-rc-* ]]; then
        echo "PUBLISH_TAG=${GITHUB_REF_NAME}"
      elif [[ "${GITHUB_REF_NAME}" == repo-* ]]; then
        echo "PUBLISH_TAG=stable"
      fi
"""

GOOD_DOC = """
golden-images publishes repo-* to stable and repo-rc-* to an RC tag.
manual dispatch must not publish stable; GOLDEN_ERR_TAG_REQUIRED is the fail-closed diagnostic.
"""


class GoldenImagesPolicyTests(unittest.TestCase):
    def test_current_policy_accepts_tag_only_publish(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            workflow = root / "golden-images.yml"
            doc = root / "release-process.md"
            workflow.write_text(GOOD_WORKFLOW, encoding="utf-8")
            doc.write_text(GOOD_DOC, encoding="utf-8")

            errors: list[str] = []
            errors.extend(policy.require_tokens(workflow, policy.REQUIRED_WORKFLOW_TOKENS, "workflow"))
            errors.extend(policy.forbid_tokens(workflow, policy.FORBIDDEN_WORKFLOW_TOKENS, "workflow"))
            errors.extend(policy.require_tokens(doc, policy.REQUIRED_DOC_TOKENS, "release-doc"))

            self.assertEqual([], errors)

    def test_flags_manual_dispatch_publish_path(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            workflow = Path(td) / "golden-images.yml"
            workflow.write_text(f"{GOOD_WORKFLOW}\nworkflow_dispatch:\n", encoding="utf-8")

            self.assertEqual(
                ["workflow: forbidden token present: workflow_dispatch:"],
                policy.forbid_tokens(workflow, policy.FORBIDDEN_WORKFLOW_TOKENS, "workflow"),
            )


if __name__ == "__main__":
    unittest.main()
