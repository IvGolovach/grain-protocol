#!/usr/bin/env python3
"""Unit tests for publication history hygiene patterns."""

from __future__ import annotations

import unittest

import check_history_hygiene


def finding_labels(text: str) -> set[str]:
    findings: list[str] = []
    check_history_hygiene.record_findings(text, "sample", findings)
    return {finding.rsplit("matched ", maxsplit=1)[1] for finding in findings}


class HistoryHygienePatternTests(unittest.TestCase):
    def test_private_repo_slug_matches_terminal_private_slug(self) -> None:
        repo_slug = "owner/service-" + "private.git"
        labels = finding_labels("remote git@github.com:" + repo_slug)

        self.assertIn("private-repo-slug", labels)

    def test_private_repo_slug_does_not_match_longer_public_branch_slug(self) -> None:
        labels = finding_labels("IvGolovach/codex/grain-ignore-private-artifacts")

        self.assertNotIn("private-repo-slug", labels)


if __name__ == "__main__":
    unittest.main()
