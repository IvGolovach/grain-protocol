#!/usr/bin/env python3
"""Validate main branch-protection policy against deterministic expectations."""

from __future__ import annotations

import argparse
import json
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


def enabled(payload: dict[str, Any], key: str) -> bool | None:
    node = payload.get(key)
    if isinstance(node, dict):
        flag = node.get("enabled")
        if isinstance(flag, bool):
            return flag
    if isinstance(node, bool):
        return node
    return None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY", ""))
    parser.add_argument("--branch", default="main")
    parser.add_argument(
        "--expected-contexts",
        default="python-tooling,rust-core,ts-c01,ts-full,evidence-bundle",
        help="Comma-separated required context names in branch protection policy.",
    )
    parser.add_argument("--require-strict", action="store_true", default=True)
    parser.add_argument("--expected-approvals", type=int, default=0)
    parser.add_argument("--expected-codeowner-reviews", type=parse_bool, default=False)
    parser.add_argument("--expected-enforce-admins", type=parse_bool, default=True)
    parser.add_argument("--expected-linear-history", type=parse_bool, default=True)
    parser.add_argument("--expected-allow-force-pushes", type=parse_bool, default=False)
    parser.add_argument("--expected-allow-deletions", type=parse_bool, default=False)
    parser.add_argument("--expected-conversation-resolution", type=parse_bool, default=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.repo:
        print("branch protection drift check failed: --repo is required.", file=sys.stderr)
        return 2

    gh_token = os.environ.get("GH_TOKEN", "")
    if not gh_token:
        print(
            "branch protection drift check failed: GH_TOKEN is missing. "
            "Provide DEPENDABOT_AUTOMERGE_TOKEN (or equivalent) with branch-protection read access.",
            file=sys.stderr,
        )
        return 2

    cmd = ["gh", "api", f"repos/{args.repo}/branches/{args.branch}/protection"]
    proc = subprocess.run(cmd, text=True, capture_output=True, env=os.environ.copy())
    if proc.returncode != 0:
        print("branch protection drift check failed: unable to query branch protection.", file=sys.stderr)
        print(proc.stderr.strip(), file=sys.stderr)
        return 2

    payload = json.loads(proc.stdout)
    errors: list[str] = []

    checks = payload.get("required_status_checks") or {}
    expected = [x.strip() for x in args.expected_contexts.split(",") if x.strip()]
    expected_set = set(expected)

    actual_checks = checks.get("checks")
    if isinstance(actual_checks, list):
        actual = [item.get("context", "") for item in actual_checks if isinstance(item, dict) and item.get("context")]
    else:
        fallback_contexts = checks.get("contexts") or []
        actual = [x for x in fallback_contexts if isinstance(x, str)]
    actual_set = set(actual)

    if actual_set != expected_set:
        errors.append(f"required checks drift: expected={sorted(expected_set)} actual={sorted(actual_set)}")

    if args.require_strict and not checks.get("strict", False):
        errors.append("required_status_checks.strict must be true.")

    reviews = payload.get("required_pull_request_reviews")
    if not isinstance(reviews, dict):
        errors.append("required_pull_request_reviews must be enabled.")
    else:
        actual_approvals = reviews.get("required_approving_review_count")
        if actual_approvals != args.expected_approvals:
            errors.append(
                "required approvals drift: expected="
                f"{args.expected_approvals} actual={actual_approvals}"
            )
        actual_codeowner = reviews.get("require_code_owner_reviews")
        if actual_codeowner is not args.expected_codeowner_reviews:
            errors.append(
                "codeowner review drift: expected="
                f"{args.expected_codeowner_reviews} actual={actual_codeowner}"
            )

    checks_bool = (
        ("enforce_admins", args.expected_enforce_admins),
        ("required_linear_history", args.expected_linear_history),
        ("allow_force_pushes", args.expected_allow_force_pushes),
        ("allow_deletions", args.expected_allow_deletions),
        ("required_conversation_resolution", args.expected_conversation_resolution),
    )

    for key, expected_bool in checks_bool:
        actual_bool = enabled(payload, key)
        if actual_bool is None:
            errors.append(f"{key} missing/unsupported in API payload.")
            continue
        if actual_bool is not expected_bool:
            errors.append(f"{key} drift: expected={expected_bool} actual={actual_bool}")

    if errors:
        print("branch protection drift check failed:", file=sys.stderr)
        for err in errors:
            print(f"- {err}", file=sys.stderr)
        return 1

    print("Branch protection drift check: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
