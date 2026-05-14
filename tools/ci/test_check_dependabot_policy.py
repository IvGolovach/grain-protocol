#!/usr/bin/env python3
"""Tests for Dependabot auto-merge policy guard."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from tools.ci import check_dependabot_policy as policy


GOOD_WORKFLOW = """
on:
  workflow_run:
    workflows: ["ci"]
env:
  DEPENDABOT_AUTOMERGE_TOKEN: ${{ secrets.DEPENDABOT_AUTOMERGE_TOKEN }}
  BLOCK_SEMVER_MAJOR_ACTIONS: "true"
steps:
  - run: |
      repos/$REPO/actions/workflows
      dependabot[bot]
      app/dependabot
      case "$f" in
        .github/dependabot.yml|.github/ISSUE_TEMPLATE/*)
          ;;
        .github/workflows/*|.github/actions/*)
          reasons+=("executable-automation-change:$f")
          ;;
      esac
      case "$f" in
        spec/*|conformance/*|core/*|runner/*|docs/llm/*|tools/*)
          ;;
      esac
      echo DEPS_ERR_TOKEN_MISSING
      echo DEPS_ERR_TOKEN_INSUFFICIENT_PERMS
      echo "@dependabot rebase"
      gh pr merge --auto --rebase
"""

GOOD_DOC = """
allowlist .github/workflows/** .github/dependabot.yml .github/ISSUE_TEMPLATE/** .github/actions/**
workflow_run no fallback DEPENDABOT_AUTOMERGE_TOKEN Workflows: Read & Write
DEPS_ERR_TOKEN_MISSING DEPS_ERR_TOKEN_INSUFFICIENT_PERMS manual
spec/** conformance/** core/** runner/** docs/llm/** tools/**
executable automation changes are manual; semver-major workflow dependency bumps require manual review.
"""


class DependabotPolicyTests(unittest.TestCase):
    def test_current_policy_accepts_manual_executable_automation_lane(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            workflow = root / "dependabot-automerge.yml"
            doc = root / "dependencies-policy.md"
            workflow.write_text(GOOD_WORKFLOW, encoding="utf-8")
            doc.write_text(GOOD_DOC, encoding="utf-8")

            errors: list[str] = []
            errors.extend(policy.require_tokens(workflow, policy.REQUIRED_WORKFLOW_TOKENS, "workflow"))
            errors.extend(policy.forbid_tokens(workflow, policy.FORBIDDEN_WORKFLOW_TOKENS, "workflow"))
            errors.extend(policy.require_tokens(doc, policy.REQUIRED_DOC_TOKENS, "policy-doc"))

            self.assertEqual([], errors)

    def test_flags_policy_without_executable_manual_reason(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            workflow = root / "dependabot-automerge.yml"
            workflow.write_text(
                GOOD_WORKFLOW.replace('reasons+=("executable-automation-change:$f")', "true"),
                encoding="utf-8",
            )

            self.assertIn(
                "workflow: missing token: executable-automation-change:$f",
                policy.require_tokens(workflow, policy.REQUIRED_WORKFLOW_TOKENS, "workflow"),
            )


if __name__ == "__main__":
    unittest.main()
