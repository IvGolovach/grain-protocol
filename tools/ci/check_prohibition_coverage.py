#!/usr/bin/env python3
"""Ensure prohibition-zone rules are mapped to conformance vectors."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROHIBITIONS = ROOT / "docs" / "llm" / "PROHIBITION_ZONE.md"
VECTORS_DIR = ROOT / "conformance" / "vectors"

RULE_RE = re.compile(r"^\s*-\s+(PZ-[A-Z0-9-]+):\s*", re.M)
VEC_RE = re.compile(r"\b(?:POS|NEG)-[A-Z0-9-]+\b")


def vector_exists(vid: str) -> bool:
    return any(VECTORS_DIR.rglob(f"{vid}.json"))


def main() -> int:
    text = PROHIBITIONS.read_text(encoding="utf-8")
    rules = RULE_RE.findall(text)
    if not rules:
        raise SystemExit("No prohibition rules found in PROHIBITION_ZONE.md")

    missing_mapping: list[str] = []
    missing_vectors: list[str] = []
    for line in text.splitlines():
        if "Vectors:" not in line:
            continue
        rule_match = RULE_RE.search(line)
        rule_id = rule_match.group(1) if rule_match else ""
        vids = VEC_RE.findall(line)
        if not vids:
            if rule_id:
                missing_mapping.append(rule_id)
            continue
        for vid in vids:
            if not vector_exists(vid):
                missing_vectors.append(vid)

    if missing_mapping:
        raise SystemExit(f"Prohibition rules without vector mapping: {sorted(set(missing_mapping))}")
    if missing_vectors:
        raise SystemExit(f"Missing vector IDs in prohibition mapping: {sorted(set(missing_vectors))}")

    print("prohibition-zone coverage: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
