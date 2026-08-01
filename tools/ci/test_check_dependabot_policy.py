#!/usr/bin/env python3
"""Tests for the low-noise Dependabot policy guard."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from tools.ci import check_dependabot_policy as policy


GOOD_CONFIG = """\
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "monthly"
    rebase-strategy: "disabled"
    open-pull-requests-limit: 2
    groups:
      routine-actions:
        patterns:
          - "*"
        update-types:
          - "minor"
          - "patch"
  - package-ecosystem: "cargo"
    directory: "/core/rust"
    schedule:
      interval: "monthly"
    rebase-strategy: "disabled"
    open-pull-requests-limit: 2
    groups:
      routine-cargo-patches:
        patterns:
          - "*"
        update-types:
          - "patch"
  - package-ecosystem: "npm"
    directory: "/runner/typescript"
    schedule:
      interval: "monthly"
    rebase-strategy: "disabled"
    open-pull-requests-limit: 2
    groups:
      routine-npm:
        patterns:
          - "*"
        update-types:
          - "minor"
          - "patch"
"""

GOOD_DOC = """\
Use a monthly version-update cadence. Dependabot security updates remain immediate.
Every dependency PR requires manual merge. Keep rebase-strategy: disabled and
open-pull-requests-limit at or below 2. There is no privileged automerge workflow.
"""


class DependabotPolicyTests(unittest.TestCase):
    def write_layout(self, root: Path, config: str = GOOD_CONFIG) -> tuple[Path, Path, Path]:
        config_path = root / ".github" / "dependabot.yml"
        workflows_dir = root / ".github" / "workflows"
        doc_path = root / "docs" / "human" / "dependencies-policy.md"
        workflows_dir.mkdir(parents=True)
        doc_path.parent.mkdir(parents=True)
        config_path.write_text(config, encoding="utf-8")
        doc_path.write_text(GOOD_DOC, encoding="utf-8")
        return config_path, doc_path, workflows_dir

    def test_current_policy_is_accepted(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            config, doc, workflows = self.write_layout(Path(td))
            self.assertEqual([], policy.check_config(config))
            self.assertEqual([], policy.check_docs(doc))
            self.assertEqual([], policy.check_no_automerge(workflows))

    def test_weekly_schedule_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            config, _, _ = self.write_layout(
                Path(td), GOOD_CONFIG.replace('interval: "monthly"', 'interval: "weekly"', 1)
            )
            self.assertTrue(any("interval must be monthly" in error for error in policy.check_config(config)))

    def test_excessive_open_pr_limit_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            config, _, _ = self.write_layout(
                Path(td), GOOD_CONFIG.replace("open-pull-requests-limit: 2", "open-pull-requests-limit: 5", 1)
            )
            self.assertTrue(any("must be 1 or 2" in error for error in policy.check_config(config)))

    def test_lower_open_pr_limit_is_accepted(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            config, _, _ = self.write_layout(
                Path(td),
                GOOD_CONFIG.replace("open-pull-requests-limit: 2", "open-pull-requests-limit: 1"),
            )
            self.assertEqual([], policy.check_config(config))

    def test_missing_group_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            config, _, _ = self.write_layout(Path(td), GOOD_CONFIG.replace("    groups:", "    no-groups:", 1))
            self.assertTrue(any("routine update group" in error for error in policy.check_config(config)))

    def test_privileged_automerge_workflow_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            _, _, workflows = self.write_layout(Path(td))
            (workflows / "dependabot-automerge.yml").write_text("name: unsafe\n", encoding="utf-8")
            self.assertTrue(policy.check_no_automerge(workflows))

    def test_all_automerge_violations_are_reported_together(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            _, _, workflows = self.write_layout(Path(td))
            (workflows / "dependabot-automerge.yml").write_text("name: unsafe\n", encoding="utf-8")
            (workflows / "renamed.yml").write_text(
                "if: github.actor == 'dependabot[bot]'\n"
                "run: gh pr merge --squash $PR\n",
                encoding="utf-8",
            )
            errors = policy.check_no_automerge(workflows)
            self.assertEqual(2, len(errors))

    def test_renamed_dependabot_merge_workflows_are_rejected(self) -> None:
        cases = {
            "cli.yml": "run: gh pr merge --squash $PR\n",
            "rest.yml": "run: gh api -X PUT repos/acme/repo/pulls/${PR}/merge\n",
            "curl.yml": "run: curl -X PUT https://api.github.com/repos/acme/repo/pulls/${PR}/merge\n",
            "request.yml": "script: github.request('PUT /repos/acme/repo/pulls/1/merge')\n",
            "octokit.yml": "script: github.rest.pulls.merge({pull_number: 1})\n",
            "graphql.yml": "run: gh api graphql -f query='mutation { enablePullRequestAutoMerge }'\n",
            "action.yml": "uses: pascalgn/automerge-action@0000000000000000000000000000000000000000\n",
        }
        for filename, merge_step in cases.items():
            with self.subTest(filename=filename), tempfile.TemporaryDirectory() as td:
                _, _, workflows = self.write_layout(Path(td))
                (workflows / filename).write_text(
                    "if: github.actor == 'dependabot[bot]'\n" + merge_step,
                    encoding="utf-8",
                )
                self.assertTrue(policy.check_no_automerge(workflows))

    def test_dependabot_workflow_without_merge_behavior_is_accepted(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            _, _, workflows = self.write_layout(Path(td))
            (workflows / "dependency-metadata.yml").write_text(
                "permissions:\n  pull-requests: write\n"
                "if: github.actor == 'dependabot[bot]'\n"
                "run: gh pr edit --add-label dependencies $PR\n",
                encoding="utf-8",
            )
            self.assertEqual([], policy.check_no_automerge(workflows))

    def test_comment_only_merge_example_is_accepted(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            _, _, workflows = self.write_layout(Path(td))
            (workflows / "dependency-metadata.yml").write_text(
                "if: github.actor == 'dependabot[bot]'\n"
                "# Never run: gh pr merge $PR\n"
                "run: gh pr edit --add-label dependencies $PR\n",
                encoding="utf-8",
            )
            self.assertEqual([], policy.check_no_automerge(workflows))


if __name__ == "__main__":
    unittest.main()
