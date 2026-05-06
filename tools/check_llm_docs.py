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
SDK_INV_PATH = ROOT / "docs" / "llm" / "SDK_INVARIANTS.md"
SDK_EDGE_PATH = ROOT / "docs" / "llm" / "SDK_EDGE_CASES.md"
SDK_CONF_PATH = ROOT / "docs" / "llm" / "SDK_CONFORMANCE.md"
VECTORS_DIR = ROOT / "conformance" / "vectors"

INV_ID_RE = re.compile(r"^\s*-\s+(INV-[A-Z0-9-]+):", re.M)
VEC_ID_RE = re.compile(r"\b(?:POS|NEG)-[A-Z0-9-]+\b")
SDK_INV_ID_RE = re.compile(r"^\s*-\s+(SDK-INV-\d{4}|SDK-AI-\d{3}):", re.M)
SDK_NEG_ID_RE = re.compile(r"^\s*-\s+(SDK-NEG-\d{4}[a-z]?|SDK-NEG-AI-\d{4}):", re.M)
SDK_RANGE_RE = re.compile(r"(SDK-(?:INV|AI)-\d{3,4}) through (SDK-(?:INV|AI)-\d{3,4})")


def _vector_exists(vid: str) -> bool:
    return any(VECTORS_DIR.rglob(f"{vid}.json"))


def _require_unique(ids: list[str], label: str) -> None:
    if len(ids) == len(set(ids)):
        return
    dupes = sorted(i for i in set(ids) if ids.count(i) > 1)
    raise SystemExit(f"Duplicate {label}: {dupes}")


def _id_number(identifier: str) -> int:
    return int(identifier.rsplit("-", 1)[1])


def _assert_sdk_blocks_have_fields(text: str) -> None:
    matches = list(SDK_INV_ID_RE.finditer(text))
    missing: list[str] = []

    for index, match in enumerate(matches):
        block_end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        block = text[match.end() : block_end]
        identifier = match.group(1)
        if "Tests:" not in block:
            missing.append(f"{identifier} missing Tests")
        if "Modules:" not in block:
            missing.append(f"{identifier} missing Modules")

    if missing:
        raise SystemExit("SDK invariant block check failed: " + ", ".join(missing))


def main() -> int:
    inv_text = INV_PATH.read_text(encoding="utf-8")
    edge_text = EDGE_PATH.read_text(encoding="utf-8")
    sdk_inv_text = SDK_INV_PATH.read_text(encoding="utf-8")
    sdk_edge_text = SDK_EDGE_PATH.read_text(encoding="utf-8")
    sdk_conf_text = SDK_CONF_PATH.read_text(encoding="utf-8")

    # 1) invariant IDs unique.
    inv_ids = INV_ID_RE.findall(inv_text)
    _require_unique(inv_ids, "invariant IDs")

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

    # 4) SDK docs IDs and summary ranges must stay in sync.
    sdk_inv_ids = SDK_INV_ID_RE.findall(sdk_inv_text)
    sdk_neg_ids = SDK_NEG_ID_RE.findall(sdk_edge_text)
    _require_unique(sdk_inv_ids, "SDK invariant IDs")
    _require_unique(sdk_neg_ids, "SDK negative-case IDs")
    _assert_sdk_blocks_have_fields(sdk_inv_text)

    max_by_prefix: dict[str, int] = {}
    for identifier in sdk_inv_ids:
        prefix = identifier.rsplit("-", 1)[0]
        max_by_prefix[prefix] = max(max_by_prefix.get(prefix, -1), _id_number(identifier))

    for start, end in SDK_RANGE_RE.findall(sdk_conf_text):
        prefix = end.rsplit("-", 1)[0]
        expected = max_by_prefix.get(prefix)
        if expected is None:
            raise SystemExit(f"SDK range references unknown prefix: {start} through {end}")
        if _id_number(end) != expected:
            raise SystemExit(
                f"SDK range mismatch in SDK_CONFORMANCE.md: {end} but max {prefix}-{expected:0{len(end.rsplit('-', 1)[1])}d}"
            )

    print("LLM docs integrity: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
