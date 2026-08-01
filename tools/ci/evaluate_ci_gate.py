#!/usr/bin/env python3
"""Evaluate the final CI status without treating skipped required work as success."""

from __future__ import annotations

import argparse
import sys


BASE_JOBS = (
    "scope",
    "python-tooling",
    "capid-csprng-audit",
    "rust-core",
    "ts-c01",
    "ts-full",
    "wasm-smoke",
)
FULL_JOBS = ("sdk-platform", "evidence-bundle")
MAIN_JOBS = ("fuzz-smoke", "verify-script-smoke")
APPROVAL_JOB = "full-ci-approval"
ALLOWED_JOBS = frozenset((*BASE_JOBS, *FULL_JOBS, *MAIN_JOBS, APPROVAL_JOB))
KNOWN_RESULTS = {"success", "failure", "cancelled", "skipped"}


def parse_bool(value: str, label: str) -> bool:
    normalized = value.strip().lower()
    if normalized == "true":
        return True
    if normalized == "false":
        return False
    raise ValueError(f"CI_GATE_ERR_INVALID_{label.upper()}: {value!r}")


def parse_jobs(values: list[str]) -> dict[str, str]:
    jobs: dict[str, str] = {}
    for value in values:
        name, separator, result = value.partition("=")
        if not separator or not name or result not in KNOWN_RESULTS:
            raise ValueError(f"CI_GATE_ERR_INVALID_JOB_RESULT: {value!r}")
        if name not in ALLOWED_JOBS:
            raise ValueError(f"CI_GATE_ERR_UNKNOWN_JOB: {name}")
        if name in jobs:
            raise ValueError(f"CI_GATE_ERR_DUPLICATE_JOB: {name}")
        jobs[name] = result
    return jobs


def require_result(jobs: dict[str, str], name: str, expected: str, errors: list[str]) -> None:
    actual = jobs.get(name, "missing")
    if actual != expected:
        errors.append(f"CI_GATE_ERR_JOB_RESULT: {name} expected={expected} actual={actual}")


def evaluate(
    *,
    event_name: str,
    full_required: bool,
    jobs: dict[str, str],
) -> list[str]:
    errors: list[str] = []

    for name in BASE_JOBS:
        require_result(jobs, name, "success", errors)

    if event_name == "pull_request":
        if full_required:
            require_result(jobs, APPROVAL_JOB, "success", errors)
            for name in FULL_JOBS:
                require_result(jobs, name, "success", errors)
        else:
            require_result(jobs, APPROVAL_JOB, "skipped", errors)
            for name in FULL_JOBS:
                require_result(jobs, name, "skipped", errors)

        for name in MAIN_JOBS:
            require_result(jobs, name, "skipped", errors)
        return errors

    if event_name not in {"push", "workflow_dispatch"}:
        errors.append(f"CI_GATE_ERR_UNSUPPORTED_EVENT: {event_name}")

    if not full_required:
        errors.append(
            "CI_GATE_ERR_INVALID_FULL_SCOPE: main and manual runs must execute the full graph"
        )

    require_result(jobs, APPROVAL_JOB, "skipped", errors)
    for name in FULL_JOBS + MAIN_JOBS:
        require_result(jobs, name, "success", errors)
    return errors


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--event-name", required=True)
    parser.add_argument("--full-required", required=True)
    parser.add_argument("--job", action="append", default=[])
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        full_required = parse_bool(args.full_required, "full_required")
        jobs = parse_jobs(args.job)
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 2

    errors = evaluate(
        event_name=args.event_name,
        full_required=full_required,
        jobs=jobs,
    )
    if errors:
        print("CI gate failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("CI gate: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
