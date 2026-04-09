#!/usr/bin/env python3
"""Validate the default-branch ruleset policy against deterministic expectations."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from typing import Any


def parse_bool(value: str) -> bool:
    v = value.strip().lower()
    if v == "true":
        return True
    if v == "false":
        return False
    raise argparse.ArgumentTypeError(f"expected true|false, got: {value}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY", ""))
    parser.add_argument("--branch", default="main")
    parser.add_argument(
        "--expected-contexts",
        default="python-tooling,rust-core,evidence-bundle,capid-csprng-audit",
        help="Comma-separated required context names in the default-branch ruleset.",
    )
    parser.add_argument("--require-strict", action="store_true", default=True)
    parser.add_argument("--expected-approvals", type=int, default=0)
    parser.add_argument("--expected-codeowner-reviews", type=parse_bool, default=False)
    parser.add_argument("--expected-dismiss-stale-reviews", type=parse_bool, default=True)
    parser.add_argument("--expected-last-push-approval", type=parse_bool, default=False)
    parser.add_argument("--expected-conversation-resolution", type=parse_bool, default=True)
    parser.add_argument("--expected-do-not-enforce-on-create", type=parse_bool, default=False)
    parser.add_argument("--expected-ruleset-name", default="main protection")
    parser.add_argument(
        "--expected-merge-methods",
        default="merge,squash,rebase",
        help="Comma-separated merge methods allowed by the pull_request rule.",
    )
    return parser.parse_args()


def gh_json(*args: str) -> Any:
    proc = subprocess.run(
        [
            "gh",
            "api",
            "-H",
            "Accept: application/vnd.github+json",
            "-H",
            "X-GitHub-Api-Version: 2026-03-10",
            *args,
        ],
        text=True,
        capture_output=True,
        env=os.environ.copy(),
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or proc.stdout.strip() or "gh api failed")
    import json

    return json.loads(proc.stdout)


def main() -> int:
    args = parse_args()
    if not args.repo:
        print("main ruleset drift check failed: --repo is required.", file=sys.stderr)
        return 2

    gh_token = os.environ.get("GH_TOKEN", "")
    if not gh_token:
        print(
            "main ruleset drift check failed: GH_TOKEN is missing. "
            "Provide DEPENDABOT_AUTOMERGE_TOKEN (or equivalent) with repository-ruleset read access.",
            file=sys.stderr,
        )
        return 2

    try:
        rulesets = gh_json(f"repos/{args.repo}/rulesets")
        active_rules = gh_json(f"repos/{args.repo}/rules/branches/{args.branch}")
    except RuntimeError as exc:
        print("main ruleset drift check failed: unable to query repository rulesets.", file=sys.stderr)
        print(str(exc), file=sys.stderr)
        return 2

    errors: list[str] = []

    expected_contexts = {x.strip() for x in args.expected_contexts.split(",") if x.strip()}
    expected_merge_methods = {x.strip() for x in args.expected_merge_methods.split(",") if x.strip()}

    matching_rulesets: list[dict[str, Any]] = []
    for candidate in rulesets:
        if not isinstance(candidate, dict):
            continue
        if candidate.get("name") != args.expected_ruleset_name:
            continue
        if candidate.get("target") != "branch":
            continue
        if candidate.get("enforcement") != "active":
            continue
        matching_rulesets.append(candidate)

    if len(matching_rulesets) != 1:
        errors.append(
            f"expected exactly one active branch ruleset named '{args.expected_ruleset_name}', found {len(matching_rulesets)}"
        )
    else:
        ruleset = gh_json(f"repos/{args.repo}/rulesets/{matching_rulesets[0]['id']}")
        conditions = ruleset.get("conditions") or {}
        ref_name = conditions.get("ref_name") or {}
        include = ref_name.get("include") or []
        if "~DEFAULT_BRANCH" not in include and f"refs/heads/{args.branch}" not in include:
            errors.append(
                f"ruleset include drift: expected ~DEFAULT_BRANCH or refs/heads/{args.branch}, actual={include}"
            )
        if ruleset.get("bypass_actors") not in ([], None):
            errors.append("ruleset bypass actors must be empty.")

    active_by_type = {
        rule.get("type"): rule for rule in active_rules if isinstance(rule, dict) and rule.get("type")
    }

    for required_type in ("deletion", "non_fast_forward", "pull_request", "required_status_checks"):
        if required_type not in active_by_type:
            errors.append(f"missing active rule: {required_type}")

    pull_request = active_by_type.get("pull_request") or {}
    pr_params = pull_request.get("parameters") or {}
    actual_approvals = pr_params.get("required_approving_review_count")
    if actual_approvals != args.expected_approvals:
        errors.append(f"required approvals drift: expected={args.expected_approvals} actual={actual_approvals}")
    actual_codeowner = pr_params.get("require_code_owner_review")
    if actual_codeowner is not args.expected_codeowner_reviews:
        errors.append(
            f"codeowner review drift: expected={args.expected_codeowner_reviews} actual={actual_codeowner}"
        )
    actual_dismiss_stale = pr_params.get("dismiss_stale_reviews_on_push")
    if actual_dismiss_stale is not args.expected_dismiss_stale_reviews:
        errors.append(
            "dismiss stale reviews drift: expected="
            f"{args.expected_dismiss_stale_reviews} actual={actual_dismiss_stale}"
        )
    actual_last_push_approval = pr_params.get("require_last_push_approval")
    if actual_last_push_approval is not args.expected_last_push_approval:
        errors.append(
            "last push approval drift: expected="
            f"{args.expected_last_push_approval} actual={actual_last_push_approval}"
        )
    actual_resolution = pr_params.get("required_review_thread_resolution")
    if actual_resolution is not args.expected_conversation_resolution:
        errors.append(
            f"conversation resolution drift: expected={args.expected_conversation_resolution} actual={actual_resolution}"
        )
    actual_merge_methods = set(pr_params.get("allowed_merge_methods") or [])
    if actual_merge_methods != expected_merge_methods:
        errors.append(
            f"allowed merge methods drift: expected={sorted(expected_merge_methods)} actual={sorted(actual_merge_methods)}"
        )

    checks_rule = active_by_type.get("required_status_checks") or {}
    checks = checks_rule.get("parameters") or {}
    actual_contexts = {
        item.get("context", "")
        for item in checks.get("required_status_checks") or []
        if isinstance(item, dict) and item.get("context")
    }
    if actual_contexts != expected_contexts:
        errors.append(
            f"required checks drift: expected={sorted(expected_contexts)} actual={sorted(actual_contexts)}"
        )

    if args.require_strict and not checks.get("strict_required_status_checks_policy", False):
        errors.append("required_status_checks.strict_required_status_checks_policy must be true.")
    actual_do_not_enforce_on_create = checks.get("do_not_enforce_on_create")
    if actual_do_not_enforce_on_create is not args.expected_do_not_enforce_on_create:
        errors.append(
            "do_not_enforce_on_create drift: expected="
            f"{args.expected_do_not_enforce_on_create} actual={actual_do_not_enforce_on_create}"
        )

    if errors:
        print("main ruleset drift check failed:", file=sys.stderr)
        for err in errors:
            print(f"- {err}", file=sys.stderr)
        return 1

    print("Main ruleset drift check: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
