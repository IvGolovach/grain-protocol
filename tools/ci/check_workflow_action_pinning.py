#!/usr/bin/env python3
"""Fail if GitHub workflow actions are not pinned to full commit SHA."""

from __future__ import annotations

import re
import sys
import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHA_RE = re.compile(r"^[0-9a-f]{40}$")
USES_RE = re.compile(r"^\s*(?:-\s*)?uses:\s*([^\s#]+)")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--root", default=str(ROOT))
    return parser.parse_args(argv)


def scan_files(root: Path) -> list[Path]:
    github = root / ".github"
    candidates: list[Path] = []
    candidates.extend(sorted((github / "workflows").glob("*.yml")))
    candidates.extend(sorted((github / "workflows").glob("*.yaml")))
    candidates.extend(sorted((github / "actions").rglob("action.yml")))
    candidates.extend(sorted((github / "actions").rglob("action.yaml")))
    return candidates


def find_violations(root: Path) -> list[str]:
    violations: list[str] = []

    for path in scan_files(root):
        for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            m = USES_RE.match(line)
            if not m:
                continue
            ref = m.group(1).strip().strip("\"'")
            if ref.startswith("./"):
                continue
            if ref.startswith("docker://"):
                continue
            if "@" not in ref:
                violations.append(f"{path.relative_to(root)}:{lineno} action ref missing @sha: {ref}")
                continue
            _, pin = ref.rsplit("@", 1)
            if not SHA_RE.fullmatch(pin):
                violations.append(f"{path.relative_to(root)}:{lineno} action not SHA-pinned: {ref}")

    return violations


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    root = Path(args.root).resolve()
    violations = find_violations(root)

    if violations:
        print("workflow action pinning check failed:", file=sys.stderr)
        for v in violations:
            print(f"- {v}", file=sys.stderr)
        return 1

    print("workflow action pinning check: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
