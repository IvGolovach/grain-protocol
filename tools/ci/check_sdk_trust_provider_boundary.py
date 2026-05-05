#!/usr/bin/env python3
"""Guard generated platform trust providers from hidden lookup or fallback."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SDK_ROOTS = [
    ROOT / "sdk" / "swift" / "Sources" / "GrainClient",
    ROOT / "sdk" / "kotlin" / "src" / "main" / "kotlin" / "dev" / "grain",
    ROOT / "sdk" / "wasm" / "src",
]

SOURCE_SUFFIXES = {".swift", ".kt", ".mjs", ".js", ".ts"}
FORBIDDEN_PATTERNS = [
    "URLSession",
    "OkHttp",
    "HttpURLConnection",
    "java.net",
    "fetch(",
    "XMLHttpRequest",
    "WebSocket",
    "node:http",
    "node:https",
    "axios",
    "undici",
    "trustAll",
    "defaultTrust",
    "fallbackTrust",
    "autoDiscover",
    "wellKnown",
    "TOFU",
    "allowAnyIssuer",
    "allowAllIssuers",
]

ALLOWLIST_FILES: set[str] = set()


def should_scan(path: Path) -> bool:
    if path.suffixes[-2:] == [".d", ".ts"]:
        return False
    return path.is_file() and path.suffix in SOURCE_SUFFIXES


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
            for pattern in FORBIDDEN_PATTERNS:
                if pattern in text:
                    violations.append(f"{rel}: {pattern}")

    if violations:
        raise SystemExit(
            "SDK trust-provider boundary violations:\n- " + "\n- ".join(violations)
        )

    print("SDK trust-provider boundary guard: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
