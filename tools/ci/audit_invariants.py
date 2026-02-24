#!/usr/bin/env python3
"""Build invariant-to-vector audit report for interop certification."""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

INV_RE = re.compile(r"^\s*-\s+(INV-[A-Z0-9-]+):")
VEC_RE = re.compile(r"\b(?:POS|NEG)-[A-Z0-9-]+\b")


@dataclass
class InvariantAudit:
    invariant_id: str
    title: str
    vectors: list[str] = field(default_factory=list)
    has_pos: bool = False
    has_neg: bool = False
    policy_exception: bool = False
    notes: list[str] = field(default_factory=list)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(allow_abbrev=False)
    p.add_argument("--invariants", default="docs/llm/INVARIANTS.md")
    p.add_argument("--vectors-root", default="conformance/vectors")
    p.add_argument("--out-json", required=True)
    p.add_argument("--out-md", required=True)
    return p.parse_args()


def vector_exists(vectors_root: Path, vector_id: str) -> bool:
    return any(vectors_root.rglob(f"{vector_id}.json"))


def finalize(cur: InvariantAudit | None, all_items: list[InvariantAudit]) -> None:
    if cur is None:
        return
    cur.vectors = sorted(set(cur.vectors))
    cur.has_pos = any(v.startswith("POS-") for v in cur.vectors)
    cur.has_neg = any(v.startswith("NEG-") for v in cur.vectors)
    all_items.append(cur)


def load_invariants(path: Path) -> list[InvariantAudit]:
    lines = path.read_text(encoding="utf-8").splitlines()
    out: list[InvariantAudit] = []
    current: InvariantAudit | None = None

    for line in lines:
        m = INV_RE.match(line)
        if m:
            finalize(current, out)
            inv_id = m.group(1)
            title = line.split(":", 1)[1].strip() if ":" in line else ""
            current = InvariantAudit(invariant_id=inv_id, title=title)
            continue

        if current is None:
            continue

        low = line.lower()
        if "policy invariant" in low or "exception" in low:
            current.policy_exception = True

        if "Vectors:" in line:
            current.vectors.extend(VEC_RE.findall(line))

    finalize(current, out)
    return out


def main() -> int:
    args = parse_args()
    invariants_path = Path(args.invariants)
    vectors_root = Path(args.vectors_root)

    rows = load_invariants(invariants_path)

    missing_vector_files: list[dict[str, str]] = []
    uncovered: list[str] = []
    partial_cover: list[str] = []

    for row in rows:
        for vid in row.vectors:
            if not vector_exists(vectors_root, vid):
                missing_vector_files.append({"invariant": row.invariant_id, "vector_id": vid})

        if not row.vectors and not row.policy_exception:
            uncovered.append(row.invariant_id)
        elif row.vectors and (not row.has_pos or not row.has_neg) and not row.policy_exception:
            partial_cover.append(row.invariant_id)

    status = "PASS"
    if missing_vector_files or uncovered:
        status = "FAIL"

    summary: dict[str, Any] = {
        "status": status,
        "invariants_total": len(rows),
        "missing_vector_files": missing_vector_files,
        "uncovered_invariants": uncovered,
        "partial_coverage_invariants": partial_cover,
        "rows": [
            {
                "invariant_id": r.invariant_id,
                "title": r.title,
                "vectors": r.vectors,
                "has_pos": r.has_pos,
                "has_neg": r.has_neg,
                "policy_exception": r.policy_exception,
            }
            for r in rows
        ],
    }

    out_json = Path(args.out_json)
    out_md = Path(args.out_md)
    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_md.parent.mkdir(parents=True, exist_ok=True)

    out_json.write_text(json.dumps(summary, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")

    md_lines = [
        "# Invariants Audit",
        "",
        f"- Status: **{status}**",
        f"- Total invariants: {len(rows)}",
        f"- Missing vector files: {len(missing_vector_files)}",
        f"- Uncovered invariants: {len(uncovered)}",
        f"- Partial coverage invariants (no POS or no NEG, without explicit exception): {len(partial_cover)}",
        "",
        "## Coverage Table",
        "",
        "| Invariant | POS | NEG | Exception | Vectors |",
        "|---|---:|---:|---:|---|",
    ]

    for r in rows:
        md_lines.append(
            f"| {r.invariant_id} | {'yes' if r.has_pos else 'no'} | {'yes' if r.has_neg else 'no'} | "
            f"{'yes' if r.policy_exception else 'no'} | {', '.join(r.vectors) if r.vectors else '-'} |"
        )

    if missing_vector_files:
        md_lines.extend(["", "## Missing vector files", ""])
        for m in missing_vector_files:
            md_lines.append(f"- {m['invariant']} -> {m['vector_id']}")

    if uncovered:
        md_lines.extend(["", "## Uncovered invariants", ""])
        for inv in uncovered:
            md_lines.append(f"- {inv}")

    if partial_cover:
        md_lines.extend(["", "## Partial coverage invariants", ""])
        for inv in partial_cover:
            md_lines.append(f"- {inv}")

    out_md.write_text("\n".join(md_lines) + "\n", encoding="utf-8")

    print(f"Invariants audit: {status}")
    if status != "PASS":
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
