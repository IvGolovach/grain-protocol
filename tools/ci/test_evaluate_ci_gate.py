#!/usr/bin/env python3
"""Tests for the fail-closed final CI gate."""

from __future__ import annotations

import unittest

from tools.ci import evaluate_ci_gate as gate


def job_results(*, full: bool, main: bool = False, approved: bool = False) -> dict[str, str]:
    jobs = {name: "success" for name in gate.BASE_JOBS}
    jobs.update({name: "success" if full else "skipped" for name in gate.FULL_JOBS})
    jobs.update({name: "success" if main else "skipped" for name in gate.MAIN_JOBS})
    jobs[gate.APPROVAL_JOB] = "success" if approved else "skipped"
    return jobs


class EvaluateCIGateTests(unittest.TestCase):
    def test_docs_only_pr_passes_without_full_jobs(self) -> None:
        errors = gate.evaluate(
            event_name="pull_request",
            full_required=False,
            jobs=job_results(full=False),
        )
        self.assertEqual([], errors)

    def test_code_pr_fails_closed_without_environment_approval(self) -> None:
        errors = gate.evaluate(
            event_name="pull_request",
            full_required=True,
            jobs=job_results(full=False),
        )
        self.assertIn(
            "CI_GATE_ERR_JOB_RESULT: full-ci-approval expected=success actual=skipped",
            errors,
        )

    def test_approved_full_pr_requires_every_full_job(self) -> None:
        jobs = job_results(full=True, approved=True)
        jobs["sdk-platform"] = "failure"
        errors = gate.evaluate(
            event_name="pull_request",
            full_required=True,
            jobs=jobs,
        )
        self.assertIn(
            "CI_GATE_ERR_JOB_RESULT: sdk-platform expected=success actual=failure",
            errors,
        )

    def test_approved_full_pr_passes_with_main_only_jobs_skipped(self) -> None:
        errors = gate.evaluate(
            event_name="pull_request",
            full_required=True,
            jobs=job_results(full=True, approved=True),
        )
        self.assertEqual([], errors)

    def test_main_requires_full_and_smoke_jobs(self) -> None:
        jobs = job_results(full=True, main=True)
        jobs["verify-script-smoke"] = "skipped"
        errors = gate.evaluate(
            event_name="push",
            full_required=True,
            jobs=jobs,
        )
        self.assertIn(
            "CI_GATE_ERR_JOB_RESULT: verify-script-smoke expected=success actual=skipped",
            errors,
        )

    def test_missing_base_job_fails_closed(self) -> None:
        jobs = job_results(full=False)
        del jobs["rust-core"]
        errors = gate.evaluate(
            event_name="pull_request",
            full_required=False,
            jobs=jobs,
        )
        self.assertIn(
            "CI_GATE_ERR_JOB_RESULT: rust-core expected=success actual=missing",
            errors,
        )

    def test_job_parser_rejects_unknown_results(self) -> None:
        with self.assertRaisesRegex(ValueError, "CI_GATE_ERR_INVALID_JOB_RESULT"):
            gate.parse_jobs(["rust-core=neutral"])

    def test_job_parser_rejects_unknown_jobs(self) -> None:
        with self.assertRaisesRegex(ValueError, "CI_GATE_ERR_UNKNOWN_JOB"):
            gate.parse_jobs(["future-unreviewed-job=success"])


if __name__ == "__main__":
    unittest.main()
