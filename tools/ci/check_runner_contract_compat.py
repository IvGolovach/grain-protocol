#!/usr/bin/env python3
"""Guard runner_v1 contract compatibility.

Deterministic checks:
- all vector ops are in runner_v1.ops.json
- each declared op has at least one vector
- SPEC still documents the frozen CLI and op names
- output schema keeps required top-level keys
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VECTORS_ROOT = ROOT / "conformance" / "vectors"
SPEC_PATH = ROOT / "conformance" / "SPEC.md"
OPS_PATH = ROOT / "conformance" / "contract" / "runner_v1.ops.json"
SCHEMA_PATH = ROOT / "conformance" / "contract" / "runner_v1.output.schema.json"


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    spec_text = SPEC_PATH.read_text(encoding="utf-8")
    ops_doc = load_json(OPS_PATH)
    schema = load_json(SCHEMA_PATH)

    expected_cli = str(ops_doc.get("cli", "")).strip()
    ops = list(ops_doc.get("operations", []))
    if not expected_cli:
        raise SystemExit("runner_v1.ops.json missing `cli`")
    if not ops:
        raise SystemExit("runner_v1.ops.json missing `operations`")

    if expected_cli not in spec_text:
        raise SystemExit(f"SPEC.md no longer contains frozen runner CLI: {expected_cli}")

    vectors_by_op: dict[str, int] = {}
    unknown_vectors: list[str] = []
    for path in sorted(VECTORS_ROOT.rglob("*.json")):
        vector = load_json(path)
        op = str(vector.get("op", ""))
        vector_id = str(vector.get("vector_id", path.stem))
        vectors_by_op[op] = vectors_by_op.get(op, 0) + 1
        if op not in ops:
            unknown_vectors.append(f"{vector_id}:{op}")

    if unknown_vectors:
        raise SystemExit(f"Vectors use ops outside runner_v1 contract: {unknown_vectors}")

    missing_ops = [op for op in ops if vectors_by_op.get(op, 0) == 0]
    if missing_ops:
        raise SystemExit(f"runner_v1 ops without vectors: {missing_ops}")

    for op in ops:
        marker = f"`{op}`"
        if marker not in spec_text:
            raise SystemExit(f"SPEC.md no longer documents runner_v1 op: {op}")

    required = set(schema.get("required", []))
    for field in ("vector_id", "pass", "diag", "out"):
        if field not in required:
            raise SystemExit(f"runner_v1 output schema dropped required field: {field}")

    props = schema.get("properties", {})
    for field in ("vector_id", "pass", "diag", "out"):
        if field not in props:
            raise SystemExit(f"runner_v1 output schema missing property: {field}")

    print("runner_v1 contract compatibility: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
