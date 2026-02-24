#!/usr/bin/env python3
"""Verify repository line-ending/filter policy in .gitattributes."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

REQUIRED_LINES = (
    "* text=auto eol=lf",
    "*.md text eol=lf",
    "*.txt text eol=lf",
    "*.json text eol=lf",
    "*.yml text eol=lf",
    "*.yaml text eol=lf",
    "*.toml text eol=lf",
    "*.cddl text eol=lf",
    "*.py text eol=lf",
    "*.ts text eol=lf",
    "*.sh text eol=lf",
    "*.rs text eol=lf",
)

FORBIDDEN_TOKENS = (
    "filter=",
    "working-tree-encoding",
)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(allow_abbrev=False)
    p.add_argument("--path", default=".gitattributes")
    return p.parse_args()


def main() -> int:
    args = parse_args()
    p = Path(args.path)
    if not p.exists():
        print("Missing .gitattributes policy file.", file=sys.stderr)
        return 1

    text = p.read_text(encoding="utf-8")
    lines = {ln.strip() for ln in text.splitlines() if ln.strip()}

    missing = [ln for ln in REQUIRED_LINES if ln not in lines]
    forbidden = [tok for tok in FORBIDDEN_TOKENS if tok in text]

    if missing or forbidden:
        if missing:
            print("Missing required .gitattributes lines:", file=sys.stderr)
            for ln in missing:
                print(f"- {ln}", file=sys.stderr)
        if forbidden:
            print("Forbidden .gitattributes tokens found:", file=sys.stderr)
            for tok in forbidden:
                print(f"- {tok}", file=sys.stderr)
        return 1

    print("gitattributes policy check: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
