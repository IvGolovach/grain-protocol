#!/usr/bin/env python3
"""Keep maintainer front-door docs easy to find."""

from __future__ import annotations

from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parents[2]

RULES = {
    Path("README.md"): {
        "all_of": [
            "docs/human/maintainer-start-here.md",
            "docs/human/start-here.md",
            "./scripts/bootstrap",
        ],
    },
    Path("CONTRIBUTING.md"): {
        "all_of": [
            "docs/human/maintainer-start-here.md",
            "docs/human/maintainer-writing.md",
            "./scripts/doctor",
            "./scripts/bootstrap",
        ],
    },
    Path("docs/human/start-here.md"): {
        "all_of": [
            "./scripts/doctor",
            "./scripts/verify",
            "./scripts/bootstrap",
        ],
        "any_of": [
            ["Maintainer path", "maintainer-start-here.md"],
            ["maintain the repo", "maintainer-start-here.md"],
        ],
    },
    Path("docs/human/maintainer-start-here.md"): {
        "all_of": [
            "./scripts/doctor",
            "./scripts/verify",
            "./scripts/bootstrap",
            "docs/human/release-process.md",
            "docs/human/repository-settings.md",
        ],
    },
    Path("docs/human/maintainer-writing.md"): {
        "any_of": [
            ["short sentences", "short sentence"],
            ["active voice"],
            ["friendly", "warm"],
        ],
    },
}


def missing_all_of(text: str, tokens: Iterable[str]) -> list[str]:
    return [token for token in tokens if token not in text]


def missing_any_of(text: str, groups: Iterable[Iterable[str]]) -> list[str]:
    missing: list[str] = []
    for group in groups:
        options = list(group)
        if not any(option in text for option in options):
            missing.append(" or ".join(f"`{option}`" for option in options))
    return missing


def main() -> int:
    missing: list[str] = []

    for relative_path, rule in RULES.items():
        path = ROOT / relative_path
        text = path.read_text(encoding="utf-8")

        for token in missing_all_of(text, rule.get("all_of", [])):
            missing.append(f"{relative_path}: missing `{token}`")

        for options in missing_any_of(text, rule.get("any_of", [])):
            missing.append(f"{relative_path}: missing one of {options}")

    if missing:
        raise SystemExit("Maintainer docs front-door check failed:\n" + "\n".join(missing))

    print("maintainer docs front-door: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
