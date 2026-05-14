#!/usr/bin/env python3
"""Check golden image publication is tag-only and fail-closed."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

REQUIRED_WORKFLOW_TOKENS = (
    "push:",
    '"repo-*"',
    '"repo-rc-*"',
    "GITHUB_REF_TYPE",
    "GOLDEN_ERR_TAG_REQUIRED",
    "repo-rc-*",
    "PUBLISH_TAG=stable",
)

FORBIDDEN_WORKFLOW_TOKENS = (
    "workflow_dispatch:",
)

REQUIRED_DOC_TOKENS = (
    "golden-images",
    "repo-*",
    "repo-rc-*",
    "stable",
    "manual dispatch",
    "GOLDEN_ERR_TAG_REQUIRED",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--workflow", default=".github/workflows/golden-images.yml")
    parser.add_argument("--release-doc", default="docs/human/release-process.md")
    return parser.parse_args()


def require_tokens(path: Path, tokens: tuple[str, ...], label: str) -> list[str]:
    if not path.exists():
        return [f"{label}: missing file {path}"]
    text = path.read_text(encoding="utf-8")
    return [f"{label}: missing token: {token}" for token in tokens if token not in text]


def forbid_tokens(path: Path, tokens: tuple[str, ...], label: str) -> list[str]:
    if not path.exists():
        return [f"{label}: missing file {path}"]
    text = path.read_text(encoding="utf-8")
    return [f"{label}: forbidden token present: {token}" for token in tokens if token in text]


def main() -> int:
    args = parse_args()
    workflow = Path(args.workflow)
    release_doc = Path(args.release_doc)

    errors: list[str] = []
    errors.extend(require_tokens(workflow, REQUIRED_WORKFLOW_TOKENS, "workflow"))
    errors.extend(forbid_tokens(workflow, FORBIDDEN_WORKFLOW_TOKENS, "workflow"))
    errors.extend(require_tokens(release_doc, REQUIRED_DOC_TOKENS, "release-doc"))

    if errors:
        print("Golden images policy check failed:", file=sys.stderr)
        for err in errors:
            print(f"- {err}", file=sys.stderr)
        return 1

    print("Golden images policy check: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
