#!/usr/bin/env python3
"""Exit successfully when a regex matches any text file under the given paths."""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path


SKIP_DIRS = {".build", ".gradle", ".git", "build", "dist", "node_modules"}


def iter_files(paths: list[str]):
    for raw_path in paths:
        path = Path(raw_path)
        if path.is_file():
            yield path
            continue
        if not path.is_dir():
            raise FileNotFoundError(raw_path)

        for dirpath, dirnames, filenames in os.walk(path):
            dirnames[:] = [dirname for dirname in dirnames if dirname not in SKIP_DIRS]
            for filename in filenames:
                yield Path(dirpath) / filename


def main() -> int:
    try:
        parser = argparse.ArgumentParser(description=__doc__)
        parser.add_argument("--ignore-case", action="store_true")
        parser.add_argument("pattern")
        parser.add_argument("paths", nargs="+")
        args = parser.parse_args()

        flags = re.IGNORECASE if args.ignore_case else 0
        pattern = re.compile(args.pattern, flags)
        files = list(iter_files(args.paths))

        for path in files:
            try:
                text = path.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            if pattern.search(text):
                return 0
        return 1
    except FileNotFoundError as exc:
        missing_path = exc.filename or exc.args[0]
        print(f"find_regex_match: path not found: {missing_path}", file=sys.stderr)
        return 2
    except Exception as exc:
        print(f"find_regex_match: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 3


if __name__ == "__main__":
    sys.exit(main())
