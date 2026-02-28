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
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--vectors-root", required=True)
    parser.add_argument("--runner-cmd", nargs=argparse.REMAINDER, required=True)
    parser.add_argument("--commit-sha", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument(
        "--timeout-seconds",
        type=int,
        default=120,
        help="Per-vector command timeout in seconds. Set <=0 to disable timeout.",
    )
    parser.add_argument("--strict", dest="strict", action="store_true")
    parser.add_argument("--no-strict", dest="strict", action="store_false")
    parser.set_defaults(strict=True)
    return parser.parse_args()


def _load_vector_id(path: pathlib.Path) -> str:
    obj = json.loads(path.read_text(encoding="utf-8"))
    return str(obj.get("vector_id", path.stem))


def main() -> int:
    args = _parse_args()
    runner_cmd = list(args.runner_cmd)
    if runner_cmd and runner_cmd[0] == "--":
        runner_cmd = runner_cmd[1:]
    if not runner_cmd:
        raise SystemExit("--runner-cmd requires at least one command token")

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
        cmd = [*runner_cmd, str(vf)]
        timeout_seconds = args.timeout_seconds if args.timeout_seconds > 0 else None

        try:
            proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout_seconds)
        except subprocess.TimeoutExpired as exc:
            failed += 1
            failures.append(
                {
                    "vector_id": vector_id,
                    "path": str(vf),
                    "exit_code": 124,
                    "timeout": True,
                    "stdout": (exc.stdout or "").strip(),
                    "stderr": (exc.stderr or "").strip(),
                    "parsed": None,
                }
            )
            continue

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
                "timeout": False,
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
        "runner_cmd": runner_cmd,
        "timeout_seconds": args.timeout_seconds,
    }

    out_path.write_text(json.dumps(summary, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")

    if failed > 0:
        print(f"Suite failed: {failed}/{total} vectors", file=sys.stderr)
        return 1

    print(f"Suite passed: {passed}/{total} vectors")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
