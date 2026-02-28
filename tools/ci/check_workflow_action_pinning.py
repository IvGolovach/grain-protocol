#!/usr/bin/env python3
"""Fail if GitHub workflow actions are not pinned to full commit SHA."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS = ROOT / ".github" / "workflows"
SHA_RE = re.compile(r"^[0-9a-f]{40}$")
USES_RE = re.compile(r"^\s*uses:\s*([^\s#]+)")


def main() -> int:
    violations: list[str] = []

    for wf in sorted(WORKFLOWS.glob("*.yml")):
        for lineno, line in enumerate(wf.read_text(encoding="utf-8").splitlines(), start=1):
            m = USES_RE.match(line)
            if not m:
                continue
            ref = m.group(1).strip()
            if ref.startswith("./"):
                continue
            if ref.startswith("docker://"):
                continue
            if "@" not in ref:
                violations.append(f"{wf.relative_to(ROOT)}:{lineno} action ref missing @sha: {ref}")
                continue
            _, pin = ref.rsplit("@", 1)
            if not SHA_RE.fullmatch(pin):
                violations.append(f"{wf.relative_to(ROOT)}:{lineno} action not SHA-pinned: {ref}")

    if violations:
        print("workflow action pinning check failed:", file=sys.stderr)
        for v in violations:
            print(f"- {v}", file=sys.stderr)
        return 1

    print("workflow action pinning check: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
