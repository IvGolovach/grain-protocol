#!/usr/bin/env python3
"""Tests for the full-CI protected environment contract."""

from __future__ import annotations

import copy
import unittest
from unittest import mock

from tools.ci import check_full_ci_environment as policy


GOOD_ENVIRONMENT = {
    "name": "full-ci",
    "deployment_branch_policy": None,
    "protection_rules": [
        {
            "type": "required_reviewers",
            "prevent_self_review": False,
            "reviewers": [
                {"type": "User", "reviewer": {"login": "IvGolovach"}},
            ],
        }
    ],
}


class FullCIEnvironmentTests(unittest.TestCase):
    def validate(self, payload: object) -> list[str]:
        return policy.validate_environment(
            payload,
            expected_name="full-ci",
            expected_reviewer="IvGolovach",
        )

    def test_expected_environment_is_accepted(self) -> None:
        self.assertEqual([], self.validate(GOOD_ENVIRONMENT))

    def test_missing_required_reviewer_fails_closed(self) -> None:
        payload = copy.deepcopy(GOOD_ENVIRONMENT)
        payload["protection_rules"][0]["reviewers"] = []
        self.assertTrue(any("FULL_CI_ENV_ERR_REVIEWERS" in error for error in self.validate(payload)))

    def test_branch_restriction_is_rejected_for_fork_support(self) -> None:
        payload = copy.deepcopy(GOOD_ENVIRONMENT)
        payload["deployment_branch_policy"] = {
            "protected_branches": True,
            "custom_branch_policies": False,
        }
        self.assertTrue(
            any("FULL_CI_ENV_ERR_BRANCH_RESTRICTION" in error for error in self.validate(payload))
        )

    def test_prevent_self_review_is_rejected_for_single_maintainer_repo(self) -> None:
        payload = copy.deepcopy(GOOD_ENVIRONMENT)
        payload["protection_rules"][0]["prevent_self_review"] = True
        self.assertTrue(any("FULL_CI_ENV_ERR_SELF_REVIEW" in error for error in self.validate(payload)))

    def test_empty_owner_only_settings_are_accepted(self) -> None:
        self.assertEqual(
            [],
            policy.validate_owner_only_settings(
                secrets_payload={"total_count": 0, "secrets": []},
                variables_payload={"total_count": 0, "variables": []},
                fork_approval_payload={"approval_policy": "all_external_contributors"},
            ),
        )

    def test_environment_data_is_rejected(self) -> None:
        errors = policy.validate_owner_only_settings(
            secrets_payload={"total_count": 1, "secrets": [{"name": "UNSAFE"}]},
            variables_payload={"total_count": 1, "variables": [{"name": "UNSAFE"}]},
            fork_approval_payload={"approval_policy": "all_external_contributors"},
        )
        self.assertTrue(any("SECRETS_COUNT" in error for error in errors))
        self.assertTrue(any("VARIABLES_COUNT" in error for error in errors))

    def test_first_time_only_fork_approval_is_rejected(self) -> None:
        errors = policy.validate_owner_only_settings(
            secrets_payload={"total_count": 0},
            variables_payload={"total_count": 0},
            fork_approval_payload={"approval_policy": "first_time_contributors"},
        )
        self.assertTrue(any("FORK_APPROVAL_POLICY" in error for error in errors))

    def test_github_api_timeout_fails_with_a_clear_error(self) -> None:
        timeout = policy.subprocess.TimeoutExpired(
            cmd=["gh", "api"],
            timeout=policy.GH_API_TIMEOUT_SECONDS,
        )
        with mock.patch.object(policy.subprocess, "run", side_effect=timeout) as run:
            with self.assertRaisesRegex(RuntimeError, "gh api timed out after 30s"):
                policy.gh_json("repos/example/project/environments/full-ci")
        self.assertEqual(policy.GH_API_TIMEOUT_SECONDS, run.call_args.kwargs["timeout"])

    def test_github_api_process_start_failure_is_normalized(self) -> None:
        with mock.patch.object(
            policy.subprocess,
            "run",
            side_effect=FileNotFoundError("gh"),
        ):
            with self.assertRaisesRegex(RuntimeError, "gh api failed to start"):
                policy.gh_json("repos/example/project/environments/full-ci")

    def test_github_api_invalid_json_is_normalized(self) -> None:
        completed = policy.subprocess.CompletedProcess(
            args=["gh", "api"],
            returncode=0,
            stdout="not-json",
            stderr="",
        )
        with mock.patch.object(policy.subprocess, "run", return_value=completed):
            with self.assertRaisesRegex(RuntimeError, "gh api returned invalid JSON"):
                policy.gh_json("repos/example/project/environments/full-ci")


if __name__ == "__main__":
    unittest.main()
