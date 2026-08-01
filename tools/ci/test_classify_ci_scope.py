#!/usr/bin/env python3
"""Tests for event-scoped full CI approval."""

from __future__ import annotations

import unittest

from tools.ci import classify_ci_scope as scope


class ClassifyCIScopeTests(unittest.TestCase):
    def test_docs_only_pr_does_not_require_full_ci(self) -> None:
        full_required = scope.classify(
            event_name="pull_request",
            files_payload=[[{"filename": "docs/human/repository-settings.md"}]],
            expected_count=1,
        )
        self.assertFalse(full_required)

    def test_unknown_or_executable_path_requires_full_ci(self) -> None:
        self.assertTrue(scope.requires_full_ci([".github/workflows/ci.yml"]))
        self.assertTrue(scope.requires_full_ci(["new-root-file.txt"]))

    def test_rename_from_executable_path_requires_full_ci(self) -> None:
        filenames = scope.extract_filenames(
            [[{"filename": "docs/old-ci.yml", "previous_filename": ".github/workflows/ci.yml"}]]
        )
        self.assertTrue(scope.requires_full_ci(filenames))

    def test_code_pull_request_requires_full_ci(self) -> None:
        payload = [[{"filename": "core/rust/Cargo.toml"}]]
        self.assertTrue(
            scope.classify(
                event_name="pull_request",
                files_payload=payload,
                expected_count=1,
            )
        )

    def test_empty_file_response_fails_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, "CI_SCOPE_ERR_NO_CHANGED_FILES"):
            scope.extract_filenames([])

    def test_truncated_file_response_fails_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, "CI_SCOPE_ERR_FILE_COUNT_MISMATCH"):
            scope.extract_filenames([[{"filename": "docs/one.md"}]], expected_count=3001)

    def test_main_and_manual_runs_are_always_full(self) -> None:
        for event_name in ("push", "workflow_dispatch"):
            self.assertTrue(
                scope.classify(
                    event_name=event_name,
                    files_payload=None,
                    expected_count=None,
                )
            )


if __name__ == "__main__":
    unittest.main()
