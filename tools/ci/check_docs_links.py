#!/usr/bin/env python3
"""Check markdown internal links used in docs and README."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

MD_FILES = [
    ROOT / "README.md",
    *sorted((ROOT / "docs" / "human").rglob("*.md")),
    *sorted((ROOT / "docs" / "llm").rglob("*.md")),
]

LINK_RE = re.compile(r"\[[^\]]+\]\(([^)]+)\)")
SCHEME_RE = re.compile(r"^[a-zA-Z][a-zA-Z0-9+.-]*:")


def _normalize_target(raw: str) -> str:
    target = raw.strip()
    if " " in target and not target.startswith("<"):
        target = target.split(" ", 1)[0]
    if target.startswith("<") and target.endswith(">"):
        target = target[1:-1]
    return target


def main() -> int:
    missing: list[str] = []

    for md in MD_FILES:
        text = md.read_text(encoding="utf-8")
        for match in LINK_RE.finditer(text):
            target = _normalize_target(match.group(1))
            if not target or target.startswith("#"):
                continue
            if SCHEME_RE.match(target):
                continue

            path_only = target.split("#", 1)[0]
            if not path_only:
                continue

            resolved = (md.parent / path_only).resolve()
            if not resolved.exists():
                missing.append(f"{md.relative_to(ROOT)} -> {target}")

    if missing:
        msg = "\n".join(missing)
        raise SystemExit(f"Broken markdown links:\n{msg}")

    print(f"Docs link check: OK ({len(MD_FILES)} markdown files)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
