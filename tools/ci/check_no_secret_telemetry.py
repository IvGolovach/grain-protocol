#!/usr/bin/env python3
"""Guard diagnostic telemetry schemas and examples from portable secrets."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
SCAN_ROOTS = (
    Path("sdk/workflows"),
    Path("sdk/generated"),
    Path("sdk/swift"),
    Path("sdk/kotlin"),
    Path("sdk/wasm"),
    Path("examples"),
    Path("docs/human/sdk"),
    Path("docs/llm"),
)
SCAN_SUFFIXES = {".json", ".jsonl", ".md", ".swift", ".kt", ".mjs", ".js", ".ts"}
SECRET_FIELD_RE = re.compile(
    r"(snapshotB64|snapshot_b64|identityBundle|identity_bundle|pairingEnvelope|"
    r"pairing_envelope|syncBundle|sync_bundle|coseB64|cose_b64|trustPubB64|"
    r"trust_pub_b64|trustMaterial|trust_material|privateKey|private_key)",
    re.IGNORECASE,
)
SURFACE_RE = re.compile(r"(telemetry|diagnostic|log)", re.IGNORECASE)
SAFE_ENUM_VALUES = {"sync_bundle"}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def walk_json_keys(value: Any, path: Path) -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            require(
                SECRET_FIELD_RE.search(str(key)) is None,
                f"NO_SECRET_TELEMETRY_ERR_SECRET_FIELD: {path}: {key}",
            )
            walk_json_keys(child, path)
    elif isinstance(value, list):
        for child in value:
            walk_json_keys(child, path)
    elif isinstance(value, str):
        if value in SAFE_ENUM_VALUES:
            return
        require(
            SECRET_FIELD_RE.search(value) is None,
            f"NO_SECRET_TELEMETRY_ERR_SECRET_FIELD: {path}: {value}",
        )


def validate_telemetry_object(value: Any, path: Path) -> None:
    walk_json_keys(value, path)


def should_scan(path: Path) -> bool:
    if path.name.endswith(".d.ts"):
        return False
    rel = str(path.relative_to(ROOT)) if path.is_absolute() and ROOT in path.parents else str(path)
    return path.is_file() and path.suffix in SCAN_SUFFIXES and SURFACE_RE.search(rel) is not None


def scan_file(path: Path, root: Path) -> list[str]:
    rel = str(path.relative_to(root))
    text = path.read_text(encoding="utf-8")
    if path.suffix in {".json", ".jsonl"}:
        try:
            value = json.loads(text)
        except json.JSONDecodeError:
            value = text
        try:
            validate_telemetry_object(value, Path(rel))
        except SystemExit as exc:
            return [str(exc)]
        return []
    violations: list[str] = []
    for line_no, line in enumerate(text.splitlines(), 1):
        match = SECRET_FIELD_RE.search(line)
        if match is not None and ("telemetry" in line.lower() or "diagnostic" in line.lower() or "log" in line.lower()):
            violations.append(f"NO_SECRET_TELEMETRY_ERR_SECRET_FIELD: {rel}:{line_no}: {match.group(0)}")
    return violations


def scan_root(root: Path = ROOT) -> None:
    violations: list[str] = []
    for rel_root in SCAN_ROOTS:
        scan_root_path = root / rel_root
        if not scan_root_path.exists():
            continue
        for path in sorted(scan_root_path.rglob("*")):
            if should_scan(path):
                violations.extend(scan_file(path, root))
    if violations:
        raise SystemExit("No-secret telemetry guard violations:\n- " + "\n- ".join(violations))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--root", default=str(ROOT))
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    scan_root(Path(args.root).resolve())
    print("No-secret telemetry guard: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
