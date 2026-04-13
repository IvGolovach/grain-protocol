#!/usr/bin/env python3
"""Fail when tracked text files contain CRLF bytes."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

BINARY_EXTS = {
    ".png",
    ".jpg",
    ".jpeg",
    ".gif",
    ".pdf",
    ".zip",
    ".gz",
    ".tgz",
    ".tar",
}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(allow_abbrev=False)
    p.add_argument("--root", default=".")
    return p.parse_args()


def tracked_files(root: Path) -> list[Path]:
    out = subprocess.check_output(["git", "ls-files", "-z"], cwd=root)
    return [root / p for p in out.decode("utf-8").split("\x00") if p]


def is_binary(path: Path, data: bytes) -> bool:
    if path.suffix.lower() in BINARY_EXTS:
        return True
    return b"\x00" in data[:8192]


def main() -> int:
    args = parse_args()
    root = Path(args.root).resolve()
    offenders: list[str] = []

    for p in tracked_files(root):
        if not p.exists():
            # `./scripts/verify` is allowed on a dirty tree, including tracked deletes
            # that have not been staged yet. Missing paths are checked by git, not by
            # the CRLF scanner.
            continue
        data = p.read_bytes()
        if is_binary(p, data):
            continue
        if b"\r\n" in data:
            offenders.append(str(p.relative_to(root)))

    if offenders:
        print("CRLF detected in tracked text files:", file=sys.stderr)
        for rel in offenders:
            print(f"- {rel}", file=sys.stderr)
        return 1

    print("CRLF check: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
