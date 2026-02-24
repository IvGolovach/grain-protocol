#!/usr/bin/env python3
"""Ensure CODEOWNERS covers critical governance paths."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

REQUIRED_PATTERNS = (
    "/spec/**",
    "/conformance/**",
    "/core/**",
    "/.github/CODEOWNERS",
    "/tools/**",
)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(allow_abbrev=False)
    p.add_argument("--path", default=".github/CODEOWNERS")
    return p.parse_args()


def main() -> int:
    args = parse_args()
    p = Path(args.path)
    if not p.exists():
        print("Missing CODEOWNERS file.", file=sys.stderr)
        return 1

    lines = [
        ln.strip().split()[0]
        for ln in p.read_text(encoding="utf-8").splitlines()
        if ln.strip() and not ln.strip().startswith("#")
    ]

    missing = [pattern for pattern in REQUIRED_PATTERNS if pattern not in lines]
    if missing:
        print("CODEOWNERS missing required path coverage:", file=sys.stderr)
        for m in missing:
            print(f"- {m}", file=sys.stderr)
        return 1

    print("CODEOWNERS coverage check: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
