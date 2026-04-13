#!/usr/bin/env python3
"""Keep maintainer front-door docs easy to find."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

CHECKS = {
    Path("README.md"): [
        "docs/human/maintainer-start-here.md",
        "docs/human/start-here.md",
    ],
    Path("CONTRIBUTING.md"): [
        "docs/human/maintainer-start-here.md",
        "docs/human/maintainer-writing.md",
        "./scripts/doctor",
    ],
    Path("docs/human/start-here.md"): [
        "Maintainer",
        "./scripts/doctor",
        "./scripts/verify",
    ],
    Path("docs/human/maintainer-start-here.md"): [
        "./scripts/doctor",
        "./scripts/verify",
        "docs/human/release-process.md",
        "docs/human/repository-settings.md",
    ],
    Path("docs/human/maintainer-writing.md"): [
        "short sentences",
        "active voice",
        "friendly",
    ],
}


def main() -> int:
    missing: list[str] = []

    for relative_path, tokens in CHECKS.items():
        path = ROOT / relative_path
        text = path.read_text(encoding="utf-8")
        for token in tokens:
            if token not in text:
                missing.append(f"{relative_path}: missing `{token}`")

    if missing:
        raise SystemExit("Maintainer docs front-door check failed:\n" + "\n".join(missing))

    print("maintainer docs front-door: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
