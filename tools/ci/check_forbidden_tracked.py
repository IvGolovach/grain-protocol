#!/usr/bin/env python3
"""Fail if forbidden generated/noise files are tracked by git."""

from __future__ import annotations

import argparse
import fnmatch
import subprocess
import sys

FORBIDDEN_FILE_PATTERNS = (
    ".DS_Store",
    ".coverage",
    ".env",
    ".env.*",
    "*.env",
    "*.env.*",
    "*.pyc",
    "*.log",
    "*.tmp",
    "*.swp",
    "*.tar.gz",
    "*.tgz",
    "*.zip",
    "*.wasm",
    "*.pem",
    "*.key",
    "*.p12",
    "*.pfx",
    "*.sqlite",
    "*.sqlite3",
    "*.db",
    "*.dump",
    "*.ipa",
)

ALLOWED_FILE_PATTERNS = (
    ".env.example",
    ".env.*.example",
    "*.env.example",
)

FORBIDDEN_DIR_NAMES = (
    ".build",
    ".gradle",
    ".kotlin",
    "__pycache__",
    "artifacts",
    "build",
    "dist",
    "node_modules",
    "pkg",
    "target",
)

FORBIDDEN_PATH_SUFFIXES = (
    ".app",
    ".dSYM",
    ".xcarchive",
    ".xcodeproj",
    ".xcworkspace",
    ".xcresult",
    ".xcuserstate",
)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(allow_abbrev=False)
    p.add_argument("--verbose", action="store_true")
    return p.parse_args()


def tracked_files() -> list[str]:
    out = subprocess.check_output(["git", "ls-files", "-z"])
    return [p for p in out.decode("utf-8").split("\x00") if p]


def is_forbidden(path: str) -> bool:
    parts = path.split("/")
    if any(d in parts for d in FORBIDDEN_DIR_NAMES):
        return True
    if any(part.endswith(FORBIDDEN_PATH_SUFFIXES) for part in parts):
        return True
    base = parts[-1]
    if any(fnmatch.fnmatch(base, pat) for pat in ALLOWED_FILE_PATTERNS):
        return False
    return any(fnmatch.fnmatch(base, pat) for pat in FORBIDDEN_FILE_PATTERNS)


def main() -> int:
    _ = parse_args()
    offenders = [p for p in tracked_files() if is_forbidden(p)]
    if offenders:
        print("Forbidden tracked files detected:", file=sys.stderr)
        for p in offenders:
            print(f"- {p}", file=sys.stderr)
        return 1
    print("Forbidden tracked files check: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
