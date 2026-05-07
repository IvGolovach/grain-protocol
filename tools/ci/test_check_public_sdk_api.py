#!/usr/bin/env python3
"""Focused tests for public SDK API snapshot validation."""

from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "tools" / "ci" / "check_public_sdk_api.py"


def load_module():
    spec = importlib.util.spec_from_file_location("check_public_sdk_api", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise AssertionError("Could not load check_public_sdk_api.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def write_fixture(root: Path, snapshot: dict[str, object]) -> None:
    (root / "sdk/api").mkdir(parents=True)
    (root / "sdk/api/public-sdk-v0.1.json").write_text(json.dumps(snapshot) + "\n", encoding="utf-8")
    (root / "sdk/swift/Sources/GrainClient").mkdir(parents=True)
    (root / "sdk/swift/Sources/GrainClient/GrainClient.swift").write_text(
        "public final class GrainClient {\n"
        "    public func scanPreview(qrString: String, trustPubB64: String? = nil) -> GrainScanPreview {}\n"
        "}\n",
        encoding="utf-8",
    )
    (root / "sdk/kotlin/src/main/kotlin/dev/grain").mkdir(parents=True)
    (root / "sdk/kotlin/src/main/kotlin/dev/grain/GrainClient.kt").write_text(
        "class GrainClient {\n"
        "    fun scanPreview(qrString: String, trustPubB64: String? = null): GrainScanPreview = TODO()\n"
        "}\n",
        encoding="utf-8",
    )
    (root / "sdk/wasm/src").mkdir(parents=True)
    (root / "sdk/wasm/src/index.d.ts").write_text(
        "export class GrainClient {\n"
        "  scanPreview(input: GrainScanPreviewInput): GrainScanPreview;\n"
        "}\n",
        encoding="utf-8",
    )
    (root / "sdk/workflows/contract").mkdir(parents=True)
    (root / "sdk/workflows/contract/client_workflow_v1.schema.json").write_text(
        json.dumps({"properties": {"workflow": {"enum": ["scan_preview"]}, "expect": {"properties": {"status": {"enum": ["Verified"]}}}}})
        + "\n",
        encoding="utf-8",
    )
    (root / "sdk/device").mkdir(parents=True)
    (root / "sdk/device/device_adapter_v1.schema.json").write_text(
        json.dumps(
            {
                "properties": {"schema": {"const": "grain.device-adapter.v1"}},
                "$defs": {
                    "ScanInput": {},
                    "DeviceCapabilities": {},
                    "SecureLocalStore": {},
                    "ExportSink": {},
                    "DiagnosticSink": {},
                    "TrustProvider": {},
                },
            }
        )
        + "\n",
        encoding="utf-8",
    )


class PublicSdkApiTests(unittest.TestCase):
    def test_snapshot_symbols_pass_when_public_surface_is_present(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_fixture(
                root,
                {
                    "schema": "grain.public-sdk-api.v0.1",
                    "surfaces": {
                        "swift": {"symbols": [{"kind": "method", "name": "GrainClient.scanPreview(qrString:trustPubB64:)"}]},
                        "kotlin": {"symbols": [{"kind": "method", "name": "GrainClient.scanPreview(qrString,trustPubB64)"}]},
                        "wasm": {"symbols": [{"kind": "method", "name": "GrainClient.scanPreview(input)"}]},
                        "workflow_contract": {
                            "workflows": ["scan_preview"],
                            "statuses": ["Verified"],
                        },
                        "device_adapter_contract": {
                            "schema": "grain.device-adapter.v1",
                            "path": "sdk/device/device_adapter_v1.schema.json",
                            "edges": [
                                "ScanInput",
                                "DeviceCapabilities",
                                "SecureLocalStore",
                                "ExportSink",
                                "DiagnosticSink",
                                "TrustProvider",
                            ],
                        },
                    },
                },
            )

            result = module.check_public_sdk_api(root=root)

            self.assertEqual(result.snapshot_schema, "grain.public-sdk-api.v0.1")
            self.assertEqual(result.checked_symbols, 3)
            self.assertEqual(result.checked_device_edges, 6)

    def test_missing_stable_symbol_fails_api_freeze(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_fixture(
                root,
                {
                    "schema": "grain.public-sdk-api.v0.1",
                    "surfaces": {
                        "swift": {"symbols": [{"kind": "method", "name": "GrainClient.scanAccept(qrString:trustPubB64:)"}]},
                        "kotlin": {"symbols": []},
                        "wasm": {"symbols": []},
                        "workflow_contract": {"workflows": [], "statuses": []},
                        "device_adapter_contract": {
                            "schema": "grain.device-adapter.v1",
                            "path": "sdk/device/device_adapter_v1.schema.json",
                            "edges": [
                                "ScanInput",
                                "DeviceCapabilities",
                                "SecureLocalStore",
                                "ExportSink",
                                "DiagnosticSink",
                                "TrustProvider",
                            ],
                        },
                    },
                },
            )

            with self.assertRaisesRegex(SystemExit, "PUBLIC_SDK_API_ERR_SYMBOL_MISSING"):
                module.check_public_sdk_api(root=root)

    def test_missing_device_adapter_reference_fails_api_freeze(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_fixture(
                root,
                {
                    "schema": "grain.public-sdk-api.v0.1",
                    "surfaces": {
                        "swift": {"symbols": [{"kind": "method", "name": "GrainClient.scanPreview(qrString:trustPubB64:)"}]},
                        "kotlin": {"symbols": []},
                        "wasm": {"symbols": []},
                        "workflow_contract": {"workflows": [], "statuses": []},
                    },
                },
            )

            with self.assertRaisesRegex(SystemExit, "PUBLIC_SDK_API_ERR_DEVICE_ADAPTER_CONTRACT"):
                module.check_public_sdk_api(root=root)


if __name__ == "__main__":
    unittest.main()
