#!/usr/bin/env python3
"""Guard the Grain device adapter contract from unsafe platform assumptions."""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = ROOT / "sdk" / "device" / "device_adapter_v1.schema.json"
README_PATH = ROOT / "sdk" / "device" / "README.md"

CONTRACT_SCHEMA = "grain.device-adapter.v1"
REQUIRED_EDGES = (
    "ScanInput",
    "DeviceCapabilities",
    "SecureLocalStore",
    "ExportSink",
    "DiagnosticSink",
    "TrustProvider",
)
REQUIRED_CAPABILITIES = (
    "cameraScan",
    "manualPaste",
    "secureLocalPersistence",
    "safeExport",
    "safeDiagnostics",
    "localTrustAnchors",
)
REQUIRED_PROHIBITIONS = (
    "no_network_trust_discovery",
    "no_secret_export_fields",
    "no_platform_store_or_account_assumptions",
    "no_publication_credentials",
)

VALUE_KEYS = {"const", "enum", "default", "examples"}
TRUST_NETWORK_RE = re.compile(
    r"(network|url|uri|http|https|endpoint|remote|discover|wellknown|well-known|fetch|socket|tofu|trustonfirstuse)",
    re.IGNORECASE,
)
EXPORT_SECRET_RE = re.compile(
    r"(secret|privatekey|private_key|seed|token|credential|snapshot|identitybundle|syncbundle|trustpubb64|mnemonic)",
    re.IGNORECASE,
)
PLATFORM_ACCOUNT_RE = re.compile(
    r"(account|appstore|app_store|testflight|playconsole|play_console|playstore|play_store|publication|developerprogram|developer_program|mavencentral|maven_central|npmpublish|npm_publish|registrycredential|registry_credential)",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class DeviceAdapterContractResult:
    schema: str
    checked_edges: int
    checked_capabilities: int
    checked_prohibitions: int


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--root", default=str(ROOT))
    parser.add_argument("--contract", help="Defaults to sdk/device/device_adapter_v1.schema.json under --root")
    parser.add_argument("--readme", help="Defaults to sdk/device/README.md under --root")
    return parser.parse_args()


def load_json(path: Path) -> dict[str, object]:
    require(path.is_file(), f"DEVICE_ADAPTER_CONTRACT_ERR_FILE_MISSING: {path}")
    data = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(data, dict), f"DEVICE_ADAPTER_CONTRACT_ERR_JSON_OBJECT: {path}")
    return data


def as_dict(value: object, message: str) -> dict[str, object]:
    require(isinstance(value, dict), message)
    return value


def as_list(value: object, message: str) -> list[object]:
    require(isinstance(value, list), message)
    return value


def strings_in(value: object) -> Iterable[str]:
    if isinstance(value, str):
        yield value
    elif isinstance(value, list):
        for item in value:
            yield from strings_in(item)
    elif isinstance(value, dict):
        for item in value.values():
            yield from strings_in(item)


def schema_tokens(node: object, *, path: str = "") -> Iterable[tuple[str, str]]:
    if isinstance(node, dict):
        for key, value in node.items():
            next_path = f"{path}/{key}"
            yield next_path, key
            if key in VALUE_KEYS and not path.startswith("/properties/prohibitions"):
                for item in strings_in(value):
                    yield next_path, item
            yield from schema_tokens(value, path=next_path)
    elif isinstance(node, list):
        for index, item in enumerate(node):
            yield from schema_tokens(item, path=f"{path}/{index}")


def forbidden_hits(node: object, pattern: re.Pattern[str]) -> list[str]:
    hits: list[str] = []
    for path, token in schema_tokens(node):
        normalized = re.sub(r"[^A-Za-z0-9_]+", "", token)
        if pattern.search(normalized):
            hits.append(f"{path}: {token}")
    return hits


def validate_edges(schema: dict[str, object]) -> dict[str, object]:
    properties = as_dict(schema.get("properties"), "DEVICE_ADAPTER_CONTRACT_ERR_PROPERTIES")
    schema_property = as_dict(properties.get("schema"), "DEVICE_ADAPTER_CONTRACT_ERR_SCHEMA_FIELD")
    require(schema_property.get("const") == CONTRACT_SCHEMA, "DEVICE_ADAPTER_CONTRACT_ERR_SCHEMA")

    defs = as_dict(schema.get("$defs"), "DEVICE_ADAPTER_CONTRACT_ERR_DEFS")
    edges = as_dict(properties.get("edges"), "DEVICE_ADAPTER_CONTRACT_ERR_EDGES")
    edge_properties = as_dict(edges.get("properties"), "DEVICE_ADAPTER_CONTRACT_ERR_EDGE_PROPERTIES")
    edge_required = as_list(edges.get("required"), "DEVICE_ADAPTER_CONTRACT_ERR_EDGE_REQUIRED")
    for edge in REQUIRED_EDGES:
        require(edge in defs and isinstance(defs[edge], dict), f"DEVICE_ADAPTER_CONTRACT_ERR_EDGE_MISSING: {edge}")
        require(edge in edge_properties, f"DEVICE_ADAPTER_CONTRACT_ERR_EDGE_PROPERTY_MISSING: {edge}")
        require(edge in edge_required, f"DEVICE_ADAPTER_CONTRACT_ERR_EDGE_REQUIRED_MISSING: {edge}")
    return defs


def validate_capabilities(defs: dict[str, object]) -> None:
    capabilities = as_dict(defs.get("DeviceCapabilities"), "DEVICE_ADAPTER_CONTRACT_ERR_CAPABILITIES")
    capability_properties = as_dict(
        capabilities.get("properties"),
        "DEVICE_ADAPTER_CONTRACT_ERR_CAPABILITY_PROPERTIES",
    )
    capability_required = as_list(
        capabilities.get("required"),
        "DEVICE_ADAPTER_CONTRACT_ERR_CAPABILITY_REQUIRED",
    )
    for capability in REQUIRED_CAPABILITIES:
        require(
            capability in capability_properties and capability in capability_required,
            f"DEVICE_ADAPTER_CONTRACT_ERR_CAPABILITY_MISSING: {capability}",
        )


def validate_prohibitions(schema: dict[str, object]) -> None:
    properties = as_dict(schema.get("properties"), "DEVICE_ADAPTER_CONTRACT_ERR_PROPERTIES")
    prohibitions = as_dict(properties.get("prohibitions"), "DEVICE_ADAPTER_CONTRACT_ERR_PROHIBITIONS")
    items = as_dict(prohibitions.get("items"), "DEVICE_ADAPTER_CONTRACT_ERR_PROHIBITION_ITEMS")
    values = as_list(items.get("enum"), "DEVICE_ADAPTER_CONTRACT_ERR_PROHIBITION_ENUM")
    for prohibition in REQUIRED_PROHIBITIONS:
        require(prohibition in values, f"DEVICE_ADAPTER_CONTRACT_ERR_PROHIBITION_MISSING: {prohibition}")


def validate_forbidden_contract_terms(schema: dict[str, object], defs: dict[str, object]) -> None:
    trust_hits = forbidden_hits(defs["TrustProvider"], TRUST_NETWORK_RE)
    require(
        not trust_hits,
        "DEVICE_ADAPTER_CONTRACT_ERR_TRUST_NETWORK: " + "; ".join(trust_hits),
    )
    export_hits = forbidden_hits(defs["ExportSink"], EXPORT_SECRET_RE)
    require(
        not export_hits,
        "DEVICE_ADAPTER_CONTRACT_ERR_EXPORT_SECRET: " + "; ".join(export_hits),
    )
    platform_hits = forbidden_hits(schema, PLATFORM_ACCOUNT_RE)
    require(
        not platform_hits,
        "DEVICE_ADAPTER_CONTRACT_ERR_PLATFORM_ACCOUNT: " + "; ".join(platform_hits),
    )


def validate_readme(path: Path) -> None:
    require(path.is_file(), f"DEVICE_ADAPTER_CONTRACT_ERR_README_MISSING: {path}")
    text = path.read_text(encoding="utf-8")
    lower = text.lower()
    for edge in REQUIRED_EDGES:
        require(edge in text, f"DEVICE_ADAPTER_CONTRACT_ERR_README_EDGE_MISSING: {edge}")
    for phrase in (
        "no accounts",
        "network trust discovery",
        "platform-store",
        "publication credentials",
        "secret exports",
    ):
        require(phrase in lower, f"DEVICE_ADAPTER_CONTRACT_ERR_README_PROHIBITION_MISSING: {phrase}")


def check_device_adapter_contract(
    *,
    root: Path = ROOT,
    contract_path: Path | None = None,
    readme_path: Path | None = None,
) -> DeviceAdapterContractResult:
    root = root.resolve()
    contract_path = contract_path or root / "sdk/device/device_adapter_v1.schema.json"
    readme_path = readme_path or root / "sdk/device/README.md"
    schema = load_json(contract_path)
    defs = validate_edges(schema)
    validate_capabilities(defs)
    validate_prohibitions(schema)
    validate_forbidden_contract_terms(schema, defs)
    validate_readme(readme_path)
    return DeviceAdapterContractResult(
        schema=CONTRACT_SCHEMA,
        checked_edges=len(REQUIRED_EDGES),
        checked_capabilities=len(REQUIRED_CAPABILITIES),
        checked_prohibitions=len(REQUIRED_PROHIBITIONS),
    )


def main() -> int:
    args = parse_args()
    result = check_device_adapter_contract(
        root=Path(args.root),
        contract_path=Path(args.contract) if args.contract else None,
        readme_path=Path(args.readme) if args.readme else None,
    )
    print(
        "Device adapter contract check: OK "
        f"({result.checked_edges} edges, {result.checked_capabilities} capabilities, "
        f"{result.checked_prohibitions} prohibitions)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
