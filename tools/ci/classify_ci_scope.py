#!/usr/bin/env python3
"""Classify whether a CI event needs explicit full-platform verification."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


SAFE_PREFIXES = (
    "adr/",
    "docs/",
    ".github/ISSUE_TEMPLATE/",
)
SAFE_FILES = {
    ".github/CODEOWNERS",
    ".github/dependabot.yml",
    ".github/pull_request_template.md",
    "CHANGELOG.md",
    "CODE_OF_CONDUCT.md",
    "CONTRIBUTING.md",
    "GOVERNANCE.md",
    "LICENSE",
    "MIGRATION.md",
    "README.md",
    "SECURITY.md",
    "TRADEMARKS.md",
}


def extract_filenames(payload: object, expected_count: int | None = None) -> list[str]:
    if not isinstance(payload, list):
        raise ValueError("CI_SCOPE_ERR_INVALID_FILES_RESPONSE")

    filenames: list[str] = []
    row_count = 0
    for page in payload:
        if not isinstance(page, list):
            raise ValueError("CI_SCOPE_ERR_INVALID_FILES_RESPONSE")
        for item in page:
            row_count += 1
            filename = item.get("filename") if isinstance(item, dict) else None
            if not isinstance(filename, str) or not filename:
                raise ValueError("CI_SCOPE_ERR_INVALID_FILENAME")
            filenames.append(filename)
            previous_filename = item.get("previous_filename")
            if previous_filename is not None:
                if not isinstance(previous_filename, str) or not previous_filename:
                    raise ValueError("CI_SCOPE_ERR_INVALID_PREVIOUS_FILENAME")
                filenames.append(previous_filename)

    if row_count == 0:
        raise ValueError("CI_SCOPE_ERR_NO_CHANGED_FILES")
    if expected_count is not None and row_count != expected_count:
        raise ValueError(
            f"CI_SCOPE_ERR_FILE_COUNT_MISMATCH: expected={expected_count} actual={row_count}"
        )
    return filenames


def requires_full_ci(filenames: list[str]) -> bool:
    return any(
        filename not in SAFE_FILES and not filename.startswith(SAFE_PREFIXES)
        for filename in filenames
    )


def classify(
    *,
    event_name: str,
    files_payload: object | None,
    expected_count: int | None = None,
) -> bool:
    if event_name != "pull_request":
        if event_name not in {"push", "workflow_dispatch"}:
            raise ValueError(f"CI_SCOPE_ERR_UNSUPPORTED_EVENT: {event_name}")
        return True

    filenames = extract_filenames(files_payload, expected_count)
    full_required = requires_full_ci(filenames)
    return full_required


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--event-name", required=True)
    parser.add_argument("--expected-count", type=int)
    parser.add_argument("--files-json")
    parser.add_argument("--github-output", required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    files_payload = None
    if args.files_json:
        files_payload = json.loads(Path(args.files_json).read_text(encoding="utf-8"))

    full_required = classify(
        event_name=args.event_name,
        files_payload=files_payload,
        expected_count=args.expected_count,
    )
    with Path(args.github_output).open("a", encoding="utf-8") as output:
        output.write(f"full_required={str(full_required).lower()}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
