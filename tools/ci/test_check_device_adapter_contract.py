#!/usr/bin/env python3
"""Focused tests for the device adapter contract guard."""

from __future__ import annotations

import copy
import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "tools" / "ci" / "check_device_adapter_contract.py"

EDGE_NAMES = [
    "ScanInput",
    "DeviceCapabilities",
    "SecureLocalStore",
    "ExportSink",
    "DiagnosticSink",
    "TrustProvider",
]

CAPABILITY_NAMES = [
    "cameraScan",
    "manualPaste",
    "secureLocalPersistence",
    "safeExport",
    "safeDiagnostics",
    "localTrustAnchors",
]


def load_module():
    spec = importlib.util.spec_from_file_location("check_device_adapter_contract", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise AssertionError("Could not load check_device_adapter_contract.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def valid_schema() -> dict[str, object]:
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://grain.dev/sdk/device/device_adapter_v1.schema.json",
        "title": "Grain Device Adapter Contract v1",
        "type": "object",
        "required": ["schema", "adapter", "capabilities", "edges", "prohibitions"],
        "properties": {
            "schema": {"const": "grain.device-adapter.v1"},
            "adapter": {
                "type": "object",
                "required": ["name", "platform", "version"],
                "additionalProperties": False,
                "properties": {
                    "name": {"type": "string"},
                    "platform": {"type": "string"},
                    "version": {"type": "string"},
                },
            },
            "capabilities": {"$ref": "#/$defs/DeviceCapabilities"},
            "edges": {
                "type": "object",
                "required": EDGE_NAMES,
                "additionalProperties": False,
                "properties": {name: {"$ref": f"#/$defs/{name}"} for name in EDGE_NAMES},
            },
            "prohibitions": {
                "type": "array",
                "minItems": 4,
                "items": {
                    "enum": [
                        "no_network_trust_discovery",
                        "no_secret_export_fields",
                        "no_platform_store_or_account_assumptions",
                        "no_publication_credentials",
                    ]
                },
            },
        },
        "$defs": {
            "ScanInput": {
                "type": "object",
                "additionalProperties": False,
                "required": ["kind", "payload"],
                "properties": {
                    "kind": {"enum": ["cameraQr", "manualPaste", "handoffPayload"]},
                    "payload": {"type": "string"},
                },
            },
            "DeviceCapabilities": {
                "type": "object",
                "additionalProperties": False,
                "required": CAPABILITY_NAMES,
                "properties": {name: {"type": "boolean"} for name in CAPABILITY_NAMES},
            },
            "SecureLocalStore": {
                "type": "object",
                "additionalProperties": False,
                "required": ["namespace", "persistence"],
                "properties": {
                    "namespace": {"type": "string"},
                    "persistence": {"enum": ["localEncryptedFile", "localKeychain", "localKeystore", "localIndexedDb"]},
                },
            },
            "ExportSink": {
                "type": "object",
                "additionalProperties": False,
                "required": ["format", "safeFieldNames"],
                "properties": {
                    "format": {"enum": ["json", "text"]},
                    "safeFieldNames": {
                        "type": "array",
                        "items": {"enum": ["acceptedScanCount", "diagnosticEventCount", "capabilitySummary"]},
                    },
                },
            },
            "DiagnosticSink": {
                "type": "object",
                "additionalProperties": False,
                "required": ["eventSchema", "redaction"],
                "properties": {
                    "eventSchema": {"const": "safe_diagnostic_event_v1"},
                    "redaction": {"const": "required"},
                },
            },
            "TrustProvider": {
                "type": "object",
                "additionalProperties": False,
                "required": ["mode", "anchorSource"],
                "properties": {
                    "mode": {"enum": ["staticBundle", "injectedAnchor"]},
                    "anchorSource": {"enum": ["bundledFixture", "developerProvided"]},
                },
            },
        },
    }


def write_contract(root: Path, schema: dict[str, object]) -> None:
    (root / "sdk/device").mkdir(parents=True)
    (root / "sdk/device/device_adapter_v1.schema.json").write_text(json.dumps(schema) + "\n", encoding="utf-8")
    (root / "sdk/device/README.md").write_text(
        "# Grain Device Adapter Contract\n\n"
        "Edges: ScanInput, DeviceCapabilities, SecureLocalStore, ExportSink, DiagnosticSink, TrustProvider.\n\n"
        "No accounts, network trust discovery, platform-store packaging, publication credentials, or secret exports.\n",
        encoding="utf-8",
    )


class DeviceAdapterContractTests(unittest.TestCase):
    def test_valid_device_adapter_contract_passes(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_contract(root, valid_schema())

            result = module.check_device_adapter_contract(root=root)

            self.assertEqual(result.schema, "grain.device-adapter.v1")
            self.assertEqual(result.checked_edges, len(EDGE_NAMES))
            self.assertEqual(result.checked_capabilities, len(CAPABILITY_NAMES))

    def test_missing_capability_is_rejected(self) -> None:
        module = load_module()
        schema = valid_schema()
        device_capabilities = schema["$defs"]["DeviceCapabilities"]
        assert isinstance(device_capabilities, dict)
        device_capabilities["required"] = [name for name in CAPABILITY_NAMES if name != "safeDiagnostics"]
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_contract(root, schema)

            with self.assertRaisesRegex(SystemExit, "DEVICE_ADAPTER_CONTRACT_ERR_CAPABILITY_MISSING"):
                module.check_device_adapter_contract(root=root)

    def test_hidden_network_trust_is_rejected(self) -> None:
        module = load_module()
        schema = valid_schema()
        trust_provider = copy.deepcopy(schema["$defs"]["TrustProvider"])
        assert isinstance(trust_provider, dict)
        properties = trust_provider["properties"]
        assert isinstance(properties, dict)
        properties["networkTrustDiscoveryUrl"] = {"type": "string"}
        schema["$defs"]["TrustProvider"] = trust_provider
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_contract(root, schema)

            with self.assertRaisesRegex(SystemExit, "DEVICE_ADAPTER_CONTRACT_ERR_TRUST_NETWORK"):
                module.check_device_adapter_contract(root=root)

    def test_secret_export_field_is_rejected(self) -> None:
        module = load_module()
        schema = valid_schema()
        export_sink = copy.deepcopy(schema["$defs"]["ExportSink"])
        assert isinstance(export_sink, dict)
        properties = export_sink["properties"]
        assert isinstance(properties, dict)
        properties["snapshotB64"] = {"type": "string"}
        schema["$defs"]["ExportSink"] = export_sink
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_contract(root, schema)

            with self.assertRaisesRegex(SystemExit, "DEVICE_ADAPTER_CONTRACT_ERR_EXPORT_SECRET"):
                module.check_device_adapter_contract(root=root)

    def test_platform_store_account_assumption_is_rejected(self) -> None:
        module = load_module()
        schema = valid_schema()
        adapter = copy.deepcopy(schema["properties"]["adapter"])
        assert isinstance(adapter, dict)
        properties = adapter["properties"]
        assert isinstance(properties, dict)
        properties["requiresAppleDeveloperAccount"] = {"const": True}
        schema["properties"]["adapter"] = adapter
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_contract(root, schema)

            with self.assertRaisesRegex(SystemExit, "DEVICE_ADAPTER_CONTRACT_ERR_PLATFORM_ACCOUNT"):
                module.check_device_adapter_contract(root=root)


if __name__ == "__main__":
    unittest.main()
