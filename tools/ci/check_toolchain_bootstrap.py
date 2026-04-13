#!/usr/bin/env python3
"""Keep the blessed local bootstrap path aligned with repo pins."""

from __future__ import annotations

import re
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MISE_TOML = ROOT / "mise.toml"
RUST_TOOLCHAIN = ROOT / "core" / "rust" / "rust-toolchain.toml"
BOOTSTRAP_SCRIPT = ROOT / "scripts" / "bootstrap"
GITHUB_YAML_FILES = sorted((ROOT / ".github").rglob("*.yml"))

PYTHON_VERSION_RE = re.compile(r"python-version:\s*[\"']?([^\"'\n]+)[\"']?")
REQUIRED_TASKS = {"bootstrap", "doctor", "verify", "certify"}


def main() -> int:
    errors: list[str] = []

    if not MISE_TOML.exists():
        errors.append("mise.toml is missing")
        print_errors(errors)
        return 1

    mise_data = tomllib.loads(MISE_TOML.read_text(encoding="utf-8"))
    tools = mise_data.get("tools", {})
    tasks = mise_data.get("tasks", {})

    rust_channel = tomllib.loads(RUST_TOOLCHAIN.read_text(encoding="utf-8")).get("toolchain", {}).get("channel")
    mise_rust = str(tools.get("rust", "")).strip()
    if not rust_channel or mise_rust != rust_channel:
        errors.append(f"Rust pin drift: rust-toolchain.toml={rust_channel!r} mise.toml={mise_rust!r}")

    mise_python = str(tools.get("python", "")).strip()
    if mise_python != "3.11":
        errors.append(f"mise.toml [tools].python must be '3.11', got: {mise_python!r}")

    python_versions = sorted(
        {
            version
            for path in GITHUB_YAML_FILES
            for version in PYTHON_VERSION_RE.findall(path.read_text(encoding="utf-8"))
        }
    )
    if python_versions != ["3.11"]:
        errors.append(
            "GitHub Python setup must stay on 3.11 across workflows/actions, "
            f"got: {python_versions!r}"
        )

    missing_tasks = sorted(task for task in REQUIRED_TASKS if task not in tasks)
    if missing_tasks:
        errors.append(f"mise.toml missing required tasks: {', '.join(missing_tasks)}")

    if not BOOTSTRAP_SCRIPT.exists():
        errors.append("scripts/bootstrap is missing")

    if errors:
        print_errors(errors)
        return 1

    print("toolchain bootstrap check: OK")
    return 0


def print_errors(errors: list[str]) -> None:
    print("toolchain bootstrap check failed:", file=sys.stderr)
    for error in errors:
        print(f"- {error}", file=sys.stderr)


if __name__ == "__main__":
    raise SystemExit(main())
