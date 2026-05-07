#!/usr/bin/env python3
"""Guard the v0.1 public SDK API snapshot against accidental drift."""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SNAPSHOT = ROOT / "sdk" / "api" / "public-sdk-v0.1.json"


@dataclass(frozen=True)
class PublicSdkApiResult:
    snapshot_schema: str
    checked_symbols: int
    checked_workflows: int
    checked_statuses: int


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--root", default=str(ROOT))
    parser.add_argument("--snapshot", help="Defaults to sdk/api/public-sdk-v0.1.json under --root")
    return parser.parse_args()


def load_json(path: Path) -> dict[str, object]:
    require(path.is_file(), f"PUBLIC_SDK_API_ERR_FILE_MISSING: {path}")
    data = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(data, dict), f"PUBLIC_SDK_API_ERR_JSON_OBJECT: {path}")
    return data


def swift_method_pattern(symbol: str) -> re.Pattern[str]:
    method = symbol.split(".", 1)[1].split("(", 1)[0]
    return re.compile(r"\bpublic\s+func\s+" + re.escape(method) + r"\s*\(")


def kotlin_method_pattern(symbol: str) -> re.Pattern[str]:
    method = symbol.split(".", 1)[1].split("(", 1)[0]
    return re.compile(r"\bfun\s+" + re.escape(method) + r"\s*\(")


def wasm_method_pattern(symbol: str) -> re.Pattern[str]:
    method = symbol.split(".", 1)[1].split("(", 1)[0]
    return re.compile(r"\b" + re.escape(method) + r"\s*\(")


def validate_symbols(surface: str, symbols: object, source_text: str) -> int:
    require(isinstance(symbols, list), f"PUBLIC_SDK_API_ERR_SYMBOLS_TYPE: {surface}")
    checked = 0
    for symbol in symbols:
        require(isinstance(symbol, dict), f"PUBLIC_SDK_API_ERR_SYMBOL_TYPE: {surface}")
        name = symbol.get("name")
        kind = symbol.get("kind")
        require(isinstance(name, str) and name, f"PUBLIC_SDK_API_ERR_SYMBOL_NAME: {surface}")
        require(kind in {"method", "type", "function", "constant"}, f"PUBLIC_SDK_API_ERR_SYMBOL_KIND: {surface}:{name}")
        if kind == "method":
            if surface == "swift":
                found = swift_method_pattern(name).search(source_text) is not None
            elif surface == "kotlin":
                found = kotlin_method_pattern(name).search(source_text) is not None
            else:
                found = wasm_method_pattern(name).search(source_text) is not None
        else:
            token = name.rsplit(".", 1)[-1]
            found = re.search(r"\b" + re.escape(token) + r"\b", source_text) is not None
        require(found, f"PUBLIC_SDK_API_ERR_SYMBOL_MISSING: {surface}:{name}")
        checked += 1
    return checked


def validate_workflow_contract(root: Path, expected: dict[str, object]) -> tuple[int, int]:
    schema = load_json(root / "sdk/workflows/contract/client_workflow_v1.schema.json")
    workflow_enum = (
        schema.get("properties", {})
        .get("workflow", {})
        .get("enum", [])
    )
    status_enum = (
        schema.get("properties", {})
        .get("expect", {})
        .get("properties", {})
        .get("status", {})
        .get("enum", [])
    )
    require(isinstance(workflow_enum, list), "PUBLIC_SDK_API_ERR_WORKFLOW_ENUM")
    require(isinstance(status_enum, list), "PUBLIC_SDK_API_ERR_STATUS_ENUM")

    workflows = expected.get("workflows", [])
    statuses = expected.get("statuses", [])
    require(isinstance(workflows, list), "PUBLIC_SDK_API_ERR_SNAPSHOT_WORKFLOWS")
    require(isinstance(statuses, list), "PUBLIC_SDK_API_ERR_SNAPSHOT_STATUSES")
    for workflow in workflows:
        require(workflow in workflow_enum, f"PUBLIC_SDK_API_ERR_WORKFLOW_MISSING: {workflow}")
    for status in statuses:
        require(status in status_enum, f"PUBLIC_SDK_API_ERR_STATUS_MISSING: {status}")
    return len(workflows), len(statuses)


def check_public_sdk_api(*, root: Path = ROOT, snapshot_path: Path | None = None) -> PublicSdkApiResult:
    root = root.resolve()
    snapshot_path = snapshot_path or root / "sdk/api/public-sdk-v0.1.json"
    snapshot = load_json(snapshot_path)
    schema = snapshot.get("schema")
    require(schema == "grain.public-sdk-api.v0.1", "PUBLIC_SDK_API_ERR_SCHEMA")
    surfaces = snapshot.get("surfaces")
    require(isinstance(surfaces, dict), "PUBLIC_SDK_API_ERR_SURFACES")

    sources = {
        "swift": (root / "sdk/swift/Sources/GrainClient/GrainClient.swift").read_text(encoding="utf-8"),
        "kotlin": (root / "sdk/kotlin/src/main/kotlin/dev/grain/GrainClient.kt").read_text(encoding="utf-8"),
        "wasm": (root / "sdk/wasm/src/index.d.ts").read_text(encoding="utf-8"),
    }
    checked_symbols = 0
    for surface, source_text in sources.items():
        surface_data = surfaces.get(surface)
        require(isinstance(surface_data, dict), f"PUBLIC_SDK_API_ERR_SURFACE: {surface}")
        checked_symbols += validate_symbols(surface, surface_data.get("symbols"), source_text)

    workflow_data = surfaces.get("workflow_contract")
    require(isinstance(workflow_data, dict), "PUBLIC_SDK_API_ERR_WORKFLOW_CONTRACT")
    checked_workflows, checked_statuses = validate_workflow_contract(root, workflow_data)
    return PublicSdkApiResult(
        snapshot_schema=str(schema),
        checked_symbols=checked_symbols,
        checked_workflows=checked_workflows,
        checked_statuses=checked_statuses,
    )


def main() -> int:
    args = parse_args()
    root = Path(args.root)
    result = check_public_sdk_api(
        root=root,
        snapshot_path=Path(args.snapshot) if args.snapshot else None,
    )
    print(
        "Public SDK API v0.1 check: OK "
        f"({result.checked_symbols} symbols, {result.checked_workflows} workflows, {result.checked_statuses} statuses)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
