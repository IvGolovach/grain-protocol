#!/usr/bin/env python3
"""Run the quickstart demo command and compare to deterministic expected output."""

from __future__ import annotations

import argparse
import json
import pathlib
import subprocess
import sys
from typing import Any

ROOT = pathlib.Path(__file__).resolve().parents[2]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument(
        "--expected",
        default=str(ROOT / "docs" / "human" / "_expected" / "quickstart-output.json"),
    )
    parser.add_argument("--runner-cmd", nargs=argparse.REMAINDER, required=True)
    return parser.parse_args()


def parse_last_json_line(stdout: str) -> dict[str, Any]:
    parsed: dict[str, Any] | None = None
    for line in stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(obj, dict):
            parsed = obj

    if parsed is None:
        raise SystemExit("Quickstart smoke failed: runner output did not contain JSON object.")

    return parsed


def main() -> int:
    args = parse_args()
    cmd = list(args.runner_cmd)
    if cmd and cmd[0] == "--":
        cmd = cmd[1:]
    if not cmd:
        raise SystemExit("Quickstart smoke failed: --runner-cmd requires command tokens.")

    proc = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True)
    if proc.returncode != 0:
        raise SystemExit(
            "Quickstart smoke failed: demo command returned non-zero.\n"
            f"stdout:\n{proc.stdout}\n"
            f"stderr:\n{proc.stderr}"
        )

    actual = parse_last_json_line(proc.stdout)
    expected_path = pathlib.Path(args.expected)
    expected = json.loads(expected_path.read_text(encoding="utf-8"))

    if actual != expected:
        raise SystemExit(
            "Quickstart smoke output mismatch.\n"
            f"Expected:\n{json.dumps(expected, indent=2, ensure_ascii=True)}\n"
            f"Actual:\n{json.dumps(actual, indent=2, ensure_ascii=True)}"
        )

    print("Quickstart smoke: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
