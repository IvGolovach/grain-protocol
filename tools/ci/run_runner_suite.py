#!/usr/bin/env python3
"""Run conformance vectors through a runner command and emit deterministic summary JSON.

Example:
python3 tools/ci/run_runner_suite.py \
  --vectors-root conformance/vectors \
  --runner-cmd cargo run -q --manifest-path core/rust/Cargo.toml -p grain-runner -- run --strict --vector \
  --commit-sha "$GITHUB_SHA" \
  --out artifacts/rust-suite-summary.json
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import subprocess
import sys
from typing import Any


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--vectors-root", required=True)
    parser.add_argument("--runner-cmd", nargs="+", required=True)
    parser.add_argument("--commit-sha", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--strict", action="store_true", default=True)
    return parser.parse_args()


def _load_vector_id(path: pathlib.Path) -> str:
    obj = json.loads(path.read_text(encoding="utf-8"))
    return str(obj.get("vector_id", path.stem))


def main() -> int:
    args = _parse_args()

    vectors_root = pathlib.Path(args.vectors_root)
    out_path = pathlib.Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    files = sorted(vectors_root.rglob("*.json"))
    total = 0
    passed = 0
    failed = 0
    failures: list[dict[str, Any]] = []

    for vf in files:
        total += 1
        vector_id = _load_vector_id(vf)
        cmd = [*args.runner_cmd, str(vf)]

        proc = subprocess.run(cmd, capture_output=True, text=True)
        stdout = proc.stdout.strip()
        stderr = proc.stderr.strip()

        parsed: dict[str, Any] | None = None
        if stdout:
            try:
                parsed = json.loads(stdout)
            except Exception:
                parsed = None

        if proc.returncode == 0 and parsed and parsed.get("pass") is True:
            passed += 1
            continue

        failed += 1
        failures.append(
            {
                "vector_id": vector_id,
                "path": str(vf),
                "exit_code": proc.returncode,
                "stdout": stdout,
                "stderr": stderr,
                "parsed": parsed,
            }
        )

    summary = {
        "commit_sha": args.commit_sha,
        "strict": bool(args.strict),
        "total": total,
        "passed": passed,
        "failed": failed,
        "failures": failures,
        "runner_cmd": args.runner_cmd,
    }

    out_path.write_text(json.dumps(summary, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")

    if failed > 0:
        print(f"Suite failed: {failed}/{total} vectors", file=sys.stderr)
        return 1

    print(f"Suite passed: {passed}/{total} vectors")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
