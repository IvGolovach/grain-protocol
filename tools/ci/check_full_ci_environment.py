#!/usr/bin/env python3
"""Validate GitHub settings that authorize full PR CI."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from typing import Any


GH_API_TIMEOUT_SECONDS = 30


def validate_environment(
    payload: object,
    *,
    expected_name: str,
    expected_reviewer: str,
) -> list[str]:
    if not isinstance(payload, dict):
        return ["FULL_CI_ENV_ERR_INVALID_RESPONSE"]

    errors: list[str] = []
    if payload.get("name") != expected_name:
        errors.append(
            f"FULL_CI_ENV_ERR_NAME: expected={expected_name} actual={payload.get('name')}"
        )
    if payload.get("deployment_branch_policy") is not None:
        errors.append("FULL_CI_ENV_ERR_BRANCH_RESTRICTION: environment must support fork PRs")

    rules = payload.get("protection_rules")
    if not isinstance(rules, list):
        return [*errors, "FULL_CI_ENV_ERR_PROTECTION_RULES"]

    reviewer_rules = [rule for rule in rules if isinstance(rule, dict) and rule.get("type") == "required_reviewers"]
    if len(reviewer_rules) != 1:
        errors.append(
            f"FULL_CI_ENV_ERR_REVIEWER_RULE_COUNT: expected=1 actual={len(reviewer_rules)}"
        )
        return errors

    unexpected = [
        str(rule.get("type"))
        for rule in rules
        if isinstance(rule, dict) and rule.get("type") != "required_reviewers"
    ]
    if unexpected:
        errors.append(f"FULL_CI_ENV_ERR_UNEXPECTED_RULES: {sorted(unexpected)}")

    rule = reviewer_rules[0]
    if rule.get("prevent_self_review") is not False:
        errors.append("FULL_CI_ENV_ERR_SELF_REVIEW: single-maintainer self-review must remain allowed")

    reviewers = rule.get("reviewers")
    actual_reviewers: set[tuple[str, str]] = set()
    if isinstance(reviewers, list):
        for item in reviewers:
            if not isinstance(item, dict):
                continue
            reviewer = item.get("reviewer")
            if isinstance(reviewer, dict):
                actual_reviewers.add((str(item.get("type")), str(reviewer.get("login"))))
    expected_reviewers = {("User", expected_reviewer)}
    if actual_reviewers != expected_reviewers:
        errors.append(
            "FULL_CI_ENV_ERR_REVIEWERS: "
            f"expected={sorted(expected_reviewers)} actual={sorted(actual_reviewers)}"
        )
    return errors


def validate_owner_only_settings(
    *,
    secrets_payload: object,
    variables_payload: object,
    fork_approval_payload: object,
) -> list[str]:
    errors: list[str] = []
    for label, payload in (
        ("SECRETS", secrets_payload),
        ("VARIABLES", variables_payload),
    ):
        if not isinstance(payload, dict) or not isinstance(payload.get("total_count"), int):
            errors.append(f"FULL_CI_ENV_ERR_{label}_RESPONSE")
            continue
        if payload["total_count"] != 0:
            errors.append(
                f"FULL_CI_ENV_ERR_{label}_COUNT: expected=0 actual={payload['total_count']}"
            )

    expected_policy = "all_external_contributors"
    if not isinstance(fork_approval_payload, dict):
        errors.append("FULL_CI_ENV_ERR_FORK_APPROVAL_RESPONSE")
    elif fork_approval_payload.get("approval_policy") != expected_policy:
        errors.append(
            "FULL_CI_ENV_ERR_FORK_APPROVAL_POLICY: "
            f"expected={expected_policy} actual={fork_approval_payload.get('approval_policy')}"
        )
    return errors


def gh_json(endpoint: str) -> Any:
    try:
        proc = subprocess.run(
            [
                "gh",
                "api",
                "-H",
                "Accept: application/vnd.github+json",
                "-H",
                "X-GitHub-Api-Version: 2026-03-10",
                endpoint,
            ],
            text=True,
            capture_output=True,
            env=os.environ.copy(),
            timeout=GH_API_TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError(
            f"gh api timed out after {GH_API_TIMEOUT_SECONDS}s for {endpoint}"
        ) from exc
    except OSError as exc:
        raise RuntimeError(f"gh api failed to start for {endpoint}: {exc}") from exc
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or proc.stdout.strip() or "gh api failed")
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"gh api returned invalid JSON for {endpoint}: {exc}") from exc


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY", ""))
    parser.add_argument("--environment", default="full-ci")
    parser.add_argument("--expected-reviewer")
    parser.add_argument(
        "--check-owner-only-settings",
        action="store_true",
        help="Also verify environment data counts and external-fork approval policy.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.repo or "/" not in args.repo:
        print("FULL_CI_ENV_ERR_REPO: --repo owner/name is required", file=sys.stderr)
        return 2
    if not os.environ.get("GH_TOKEN"):
        print("FULL_CI_ENV_ERR_TOKEN: GH_TOKEN is required", file=sys.stderr)
        return 2

    expected_reviewer = args.expected_reviewer or args.repo.split("/", 1)[0]
    try:
        payload = gh_json(f"repos/{args.repo}/environments/{args.environment}")
    except RuntimeError as exc:
        print(f"FULL_CI_ENV_ERR_QUERY: {exc}", file=sys.stderr)
        return 2

    errors = validate_environment(
        payload,
        expected_name=args.environment,
        expected_reviewer=expected_reviewer,
    )
    if args.check_owner_only_settings:
        try:
            secrets_payload = gh_json(
                f"repos/{args.repo}/environments/{args.environment}/secrets"
            )
            variables_payload = gh_json(
                f"repos/{args.repo}/environments/{args.environment}/variables"
            )
            fork_approval_payload = gh_json(
                f"repos/{args.repo}/actions/permissions/fork-pr-contributor-approval"
            )
        except RuntimeError as exc:
            print(f"FULL_CI_ENV_ERR_OWNER_QUERY: {exc}", file=sys.stderr)
            return 2
        errors.extend(
            validate_owner_only_settings(
                secrets_payload=secrets_payload,
                variables_payload=variables_payload,
                fork_approval_payload=fork_approval_payload,
            )
        )
    if errors:
        print("Full CI environment check failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("Full CI environment check: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
