#!/usr/bin/env python3
"""Repo integrity checks for LLM-first docs.

Deterministic checks:
- invariant IDs are unique
- vector IDs referenced in EDGE_CASES.md exist
- vector IDs referenced in INVARIANTS.md exist (except explicit policy-only notes)
"""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

INV_PATH = ROOT / "docs" / "llm" / "INVARIANTS.md"
EDGE_PATH = ROOT / "docs" / "llm" / "EDGE_CASES.md"
VECTORS_DIR = ROOT / "conformance" / "vectors"

INV_ID_RE = re.compile(r"^\s*-\s+(INV-[A-Z0-9-]+):", re.M)
VEC_ID_RE = re.compile(r"\b(?:POS|NEG)-[A-Z0-9-]+\b")


def _vector_exists(vid: str) -> bool:
    return any(VECTORS_DIR.rglob(f"{vid}.json"))


def main() -> int:
    inv_text = INV_PATH.read_text(encoding="utf-8")
    edge_text = EDGE_PATH.read_text(encoding="utf-8")

    # 1) invariant IDs unique.
    inv_ids = INV_ID_RE.findall(inv_text)
    if len(inv_ids) != len(set(inv_ids)):
        dupes = sorted(i for i in set(inv_ids) if inv_ids.count(i) > 1)
        raise SystemExit(f"Duplicate invariant IDs: {dupes}")

    # 2) EDGE_CASES vector refs must exist.
    edge_vec_ids = sorted(set(VEC_ID_RE.findall(edge_text)))
    missing_edge = [vid for vid in edge_vec_ids if not _vector_exists(vid)]
    if missing_edge:
        raise SystemExit(f"Missing vector files for IDs referenced in EDGE_CASES.md: {missing_edge}")

    # 3) INVARIANTS vector refs must exist unless line explicitly marks policy-only.
    missing_inv = []
    for line in inv_text.splitlines():
        if "Vectors:" not in line:
            continue
        if "policy invariant" in line.lower():
            continue
        for vid in VEC_ID_RE.findall(line):
            if not _vector_exists(vid):
                missing_inv.append(vid)

    if missing_inv:
        missing_inv = sorted(set(missing_inv))
        raise SystemExit(f"Missing vector files for IDs referenced in INVARIANTS.md: {missing_inv}")

    print("LLM docs integrity: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
