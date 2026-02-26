#!/usr/bin/env python3
"""Fail if SDK core introduces outbound network usage."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SDK_SRC = ROOT / "core" / "ts" / "grain-sdk" / "src"

FORBIDDEN = [
    "fetch(",
    "axios",
    "undici",
    "node:http",
    "node:https",
    "http://",
    "https://",
]

ALLOWLIST_FILES = {
    # No allowlist entries for now; keep explicit for future audited exceptions.
}


def should_scan(path: Path) -> bool:
    return path.is_file() and path.suffix in {".ts", ".js"}


def main() -> int:
    violations: list[str] = []
    for path in sorted(SDK_SRC.rglob("*")):
        if not should_scan(path):
            continue
        rel = str(path.relative_to(ROOT))
        if rel in ALLOWLIST_FILES:
            continue
        text = path.read_text(encoding="utf-8")
        for pattern in FORBIDDEN:
            if pattern in text:
                violations.append(f"{rel}: {pattern}")

    if violations:
        raise SystemExit("SDK no-network guard violations:\n- " + "\n- ".join(violations))

    print("SDK no-network guard: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
