#!/usr/bin/env python3
"""Protect the SDK core/AI sidecar boundary from scope creep."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SDK_SRC = ROOT / "core" / "ts" / "grain-sdk" / "src"
AI_SRC = ROOT / "core" / "ts" / "grain-sdk-ai" / "src"
SDK_INDEX = SDK_SRC / "index.ts"

IMPORT_RE = re.compile(r"""from\s+["']([^"']+)["']""")
SDK_EXPORT_BLOCKLIST = [
    "AcceptedToken",
    "AICandidateEnvelopeV1",
    "AIExplainChunk",
    "AIInput",
    "AcceptOptions",
    "ApplyOptions",
    "./ai/",
]
ALLOWED_SDK_SIDE_CAR_IMPORTS = {"grain-sdk-ts/ai-host", "grain-sdk-ts/errors"}


def should_scan(path: Path) -> bool:
    return path.is_file() and path.suffix == ".ts"


def main() -> int:
    violations: list[str] = []

    if (SDK_SRC / "ai").exists():
        violations.append("core/ts/grain-sdk/src/ai should not exist; AI must live in core/ts/grain-sdk-ai")

    for path in sorted(SDK_SRC.rglob("*.ts")):
        text = path.read_text(encoding="utf-8")
        rel = path.relative_to(ROOT)
        if "grain-sdk-ai" in text or 'from "./ai/' in text or 'from "../ai/' in text:
            violations.append(f"{rel}: SDK core must not import AI sidecar modules")

    if SDK_INDEX.exists():
        index_text = SDK_INDEX.read_text(encoding="utf-8")
        for token in SDK_EXPORT_BLOCKLIST:
            if token in index_text:
                violations.append(f"{SDK_INDEX.relative_to(ROOT)}: remove AI export surface token {token!r}")

    for path in sorted(AI_SRC.rglob("*.ts")):
        if not should_scan(path):
            continue
        rel = path.relative_to(ROOT)
        text = path.read_text(encoding="utf-8")
        for target in IMPORT_RE.findall(text):
            if target.startswith("grain-sdk-ts") and target not in ALLOWED_SDK_SIDE_CAR_IMPORTS:
                violations.append(f"{rel}: AI sidecar import {target!r} exceeds allowed SDK bridge surface")
            if "core/ts/grain-sdk/src" in target or "/grain-sdk/src/" in target:
                violations.append(f"{rel}: AI sidecar must not reach into SDK source paths ({target!r})")

    if violations:
        raise SystemExit("SDK AI boundary guard violations:\n- " + "\n- ".join(violations))

    print("SDK AI boundary guard: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
