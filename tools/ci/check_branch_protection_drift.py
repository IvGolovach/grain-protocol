#!/usr/bin/env python3
"""Validate main branch-protection required status checks against policy."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys


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
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.repo:
        print("branch protection drift check failed: --repo is required.", file=sys.stderr)
        return 2

    gh_token = os.environ.get("GH_TOKEN", "")
    allow_permission_fallback = os.environ.get("ALLOW_PERMISSION_FALLBACK", "false").lower() == "true"
    if not gh_token:
        msg = (
            "branch protection drift check failed: GH_TOKEN is missing. "
            "Provide a token with branch-protection read access."
        )
        if allow_permission_fallback:
            print(f"Branch protection drift check: SKIPPED ({msg})")
            return 0
        print(msg, file=sys.stderr)
        return 2

    cmd = [
        "gh",
        "api",
        f"repos/{args.repo}/branches/{args.branch}/protection",
    ]
    proc = subprocess.run(cmd, text=True, capture_output=True, env=os.environ.copy())
    if proc.returncode != 0:
        stderr = proc.stderr.strip()
        if allow_permission_fallback:
            print("Branch protection drift check: SKIPPED (unable to query branch protection).")
            if stderr:
                print(f"Reason: {stderr}")
            return 0
        print("branch protection drift check failed: unable to query branch protection.", file=sys.stderr)
        print(stderr, file=sys.stderr)
        return 2

    payload = json.loads(proc.stdout)
    checks = payload.get("required_status_checks") or {}
    expected = [x.strip() for x in args.expected_contexts.split(",") if x.strip()]
    expected_set = set(expected)
    actual_checks = checks.get("checks") or []
    actual = [item.get("context", "") for item in actual_checks if item.get("context")]
    actual_set = set(actual)

    errors: list[str] = []
    if actual_set != expected_set:
        errors.append(
            "required checks drift: expected="
            f"{sorted(expected_set)} actual={sorted(actual_set)}"
        )

    if args.require_strict and not checks.get("strict", False):
        errors.append("required_status_checks.strict must be true.")

    if errors:
        print("branch protection drift check failed:", file=sys.stderr)
        for err in errors:
            print(f"- {err}", file=sys.stderr)
        return 1

    print("Branch protection drift check: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
