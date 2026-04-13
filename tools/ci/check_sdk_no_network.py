#!/usr/bin/env python3
"""Fail if SDK core or AI sidecar introduce outbound network usage."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SDK_ROOTS = [
    ROOT / "core" / "ts" / "grain-sdk" / "src",
    ROOT / "core" / "ts" / "grain-sdk-ai" / "src",
]

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
    for root in SDK_ROOTS:
        if not root.exists():
            continue
        for path in sorted(root.rglob("*")):
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

    print("SDK no-network guard: OK (core + ai sidecar)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
