#!/usr/bin/env python3
"""Check the low-noise, manual-merge Dependabot policy."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


EXPECTED_UPDATES = {
    ("github-actions", "/"): {"minor", "patch"},
    ("cargo", "/core/rust"): {"patch"},
    ("npm", "/runner/typescript"): {"minor", "patch"},
}

REQUIRED_DOC_TOKENS = (
    "monthly version-update cadence",
    "security updates remain immediate",
    "manual merge",
    "rebase-strategy: disabled",
    "open-pull-requests-limit at or below 2",
    "no privileged automerge workflow",
)

MERGE_PRIMITIVES = (
    re.compile(r"\bgh[ \t]+pr[ \t]+merge\b", re.IGNORECASE),
    re.compile(r"\bgh[ \t]+api\b[^\n]*/pulls/[^\n]*/merge\b", re.IGNORECASE),
    re.compile(r"\bcurl\b[^\n]*api\.github\.com[^\n]*/pulls/[^\n]*/merge\b", re.IGNORECASE),
    re.compile(r"\bgithub\.request\b[^\n]*/pulls/[^\n]*/merge\b", re.IGNORECASE),
    re.compile(r"\bpulls\.merge[ \t]*\(", re.IGNORECASE),
    re.compile(r"\b(?:enablePullRequestAutoMerge|mergePullRequest)\b", re.IGNORECASE),
    re.compile(r"(?m)^[ \t]*uses:[ \t]*\S*(?:auto-?merge|automerge)\S*@", re.IGNORECASE),
)


def unquote(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
        return value[1:-1]
    return value


def scalar(block: str, key: str) -> str | None:
    match = re.search(rf"(?m)^[ \t]+(?:-[ \t]+)?{re.escape(key)}:[ \t]*(.+?)[ \t]*$", block)
    return unquote(match.group(1)) if match else None


def split_update_blocks(text: str) -> list[str]:
    starts = [match.start() for match in re.finditer(r"(?m)^  - package-ecosystem:", text)]
    return [
        text[start : starts[index + 1] if index + 1 < len(starts) else len(text)]
        for index, start in enumerate(starts)
    ]


def update_types(block: str) -> set[str]:
    match = re.search(
        r"(?m)^        update-types:\s*$\n(?P<items>(?:^          - .+\n?)+)",
        block,
    )
    if not match:
        return set()
    values: set[str] = set()
    for line in match.group("items").splitlines():
        values.add(unquote(line.split("-", 1)[1]))
    return values


def check_config(path: Path) -> list[str]:
    if not path.exists():
        return [f"config: missing file {path}"]

    text = path.read_text(encoding="utf-8")
    blocks = split_update_blocks(text)
    errors: list[str] = []
    actual_keys: set[tuple[str, str]] = set()

    for block in blocks:
        ecosystem = scalar(block, "package-ecosystem")
        directory = scalar(block, "directory")
        if ecosystem is None or directory is None:
            errors.append("config: every update entry needs package-ecosystem and directory")
            continue

        key = (ecosystem, directory)
        actual_keys.add(key)
        label = f"config:{ecosystem}:{directory}"

        if scalar(block, "interval") != "monthly":
            errors.append(f"{label}: interval must be monthly")
        if scalar(block, "rebase-strategy") != "disabled":
            errors.append(f"{label}: rebase-strategy must be disabled")

        limit = scalar(block, "open-pull-requests-limit")
        if limit is None or not limit.isdigit() or not 1 <= int(limit) <= 2:
            errors.append(f"{label}: open-pull-requests-limit must be 1 or 2")

        if "    groups:" not in block or '          - "*"' not in block:
            errors.append(f"{label}: routine update group with wildcard pattern is required")

        expected_types = EXPECTED_UPDATES.get(key)
        if expected_types is not None and update_types(block) != expected_types:
            errors.append(
                f"{label}: grouped update-types must be {sorted(expected_types)}"
            )

    if actual_keys != set(EXPECTED_UPDATES):
        errors.append(
            "config: expected update entries "
            f"{sorted(EXPECTED_UPDATES)}, actual={sorted(actual_keys)}"
        )
    return errors


def check_docs(path: Path) -> list[str]:
    if not path.exists():
        return [f"policy-doc: missing file {path}"]
    text = path.read_text(encoding="utf-8")
    return [
        f"policy-doc: missing token: {token}"
        for token in REQUIRED_DOC_TOKENS
        if token not in text
    ]


def check_no_automerge(workflows_dir: Path) -> list[str]:
    errors: list[str] = []
    automerge = workflows_dir / "dependabot-automerge.yml"
    if automerge.exists():
        errors.append(f"workflow: privileged Dependabot automerge must be absent: {automerge}")

    for workflow in sorted(workflows_dir.glob("*.y*ml")):
        text = workflow.read_text(encoding="utf-8")
        if "DEPENDABOT_AUTOMERGE_TOKEN" in text:
            errors.append(f"workflow: obsolete automerge token present: {workflow}")
        active_text = "\n".join(
            line for line in text.splitlines() if not line.lstrip().startswith("#")
        )
        if "dependabot" not in active_text.lower():
            continue
        if any(pattern.search(active_text) for pattern in MERGE_PRIMITIVES):
            errors.append(
                f"workflow: Dependabot-triggered merge behavior is forbidden: {workflow}"
            )
    return errors


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--config", default=".github/dependabot.yml")
    parser.add_argument("--policy-doc", default="docs/human/dependencies-policy.md")
    parser.add_argument("--workflows-dir", default=".github/workflows")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    errors = [
        *check_config(Path(args.config)),
        *check_docs(Path(args.policy_doc)),
        *check_no_automerge(Path(args.workflows_dir)),
    ]
    if errors:
        print("Dependabot policy check failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("Dependabot policy check: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
