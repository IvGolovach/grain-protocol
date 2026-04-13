#!/usr/bin/env python3
"""Require an exact Node pin and keep evidence-producing runtimes in sync."""

from __future__ import annotations

import re
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
NVMRC = ROOT / ".nvmrc"
DOCKERFILE = ROOT / "docker" / "grain-certify.Dockerfile"
MISE_TOML = ROOT / "mise.toml"
SEMVER_RE = re.compile(r"^\d+\.\d+\.\d+$")
DOCKER_ARG_RE = re.compile(r"^ARG NODE_VERSION=(\S+)$", re.MULTILINE)


def main() -> int:
    errors: list[str] = []

    nvmrc_value = NVMRC.read_text(encoding="utf-8").strip()
    if not SEMVER_RE.fullmatch(nvmrc_value):
        errors.append(f".nvmrc must pin an exact Node patch version, got: {nvmrc_value!r}")

    docker_text = DOCKERFILE.read_text(encoding="utf-8")
    docker_match = DOCKER_ARG_RE.search(docker_text)
    docker_value: str | None = None
    if not docker_match:
        errors.append("docker/grain-certify.Dockerfile missing ARG NODE_VERSION=<x.y.z>")
    else:
        docker_value = docker_match.group(1)
        if not SEMVER_RE.fullmatch(docker_value):
            errors.append(
                "docker/grain-certify.Dockerfile must pin an exact Node patch version, "
                f"got: {docker_value!r}"
            )

    if docker_value is not None and docker_value != nvmrc_value:
        errors.append(
            "Node runtime pin drift: "
            f".nvmrc={nvmrc_value!r} docker/grain-certify.Dockerfile={docker_value!r}"
        )

    if not MISE_TOML.exists():
        errors.append("mise.toml is missing")
    else:
        mise_data = tomllib.loads(MISE_TOML.read_text(encoding="utf-8"))
        mise_node = str(mise_data.get("tools", {}).get("node", "")).strip()
        if not SEMVER_RE.fullmatch(mise_node):
            errors.append(f"mise.toml [tools].node must pin an exact Node patch version, got: {mise_node!r}")
        elif mise_node != nvmrc_value:
            errors.append(f"Node runtime pin drift: .nvmrc={nvmrc_value!r} mise.toml={mise_node!r}")

    if errors:
        print("node runtime pin check failed:", file=sys.stderr)
        for err in errors:
            print(f"- {err}", file=sys.stderr)
        return 1

    print(f"node runtime pin check: OK ({nvmrc_value})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
