#!/usr/bin/env python3
"""Focused tests for external source SDK handoff validation."""

from __future__ import annotations

import importlib.util
import io
import json
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "tools" / "ci" / "check_external_sdk_handoff.py"
COMMIT = "0123456789abcdef0123456789abcdef01234567"


def load_module():
    spec = importlib.util.spec_from_file_location("check_external_sdk_handoff", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise AssertionError("Could not load check_external_sdk_handoff.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def write_archive(path: Path, entries: dict[str, str]) -> None:
    with tarfile.open(path, "w:gz") as archive:
        for name, text in entries.items():
            if name.endswith("/"):
                info = tarfile.TarInfo(name.rstrip("/"))
                info.type = tarfile.DIRTYPE
                info.mode = 0o755
                archive.addfile(info)
                continue
            payload = text.encode("utf-8")
            info = tarfile.TarInfo(name)
            info.size = len(payload)
            info.mode = 0o644
            archive.addfile(info, io.BytesIO(payload))


def write_minimal_release(out_dir: Path) -> None:
    artifacts = [
        (
            "grain-swift-client",
            "swift-client",
            {"sdk/swift/Package.swift": "// swift package\n", "sdk/swift/Sources/GrainClient/GrainClient.swift": "// api\n"},
        ),
        (
            "grain-kotlin-client",
            "kotlin-client",
            {
                "sdk/kotlin/build.gradle.kts": "plugins {}\n",
                "sdk/kotlin/src/main/kotlin/dev/grain/GrainClient.kt": "package dev.grain\n",
            },
        ),
        (
            "grain-wasm-client",
            "wasm-client",
            {
                "sdk/wasm/package.json": '{"name":"@grain/client-wasm"}\n',
                "sdk/wasm/src/index.mjs": "export {}\n",
                "core/rust/grain-client-wasm/Cargo.toml": "[package]\nname='grain-client-wasm'\n",
            },
        ),
        (
            "grain-generated-bindings",
            "generated-bindings",
            {
                "generated-bindings/swift/GrainClientCore.swift": "// generated\n",
                "generated-bindings/kotlin/GrainClientCore.kt": "package dev.grain.generated\n",
            },
        ),
        (
            "grain-sdk-workflow-contract",
            "workflow-contract",
            {
                "sdk/workflows/contract/client_workflow_v1.md": "# contract\n",
                "sdk/trust/trust_anchor_bundle_v1.schema.json": "{}\n",
                "sdk/generated/README.md": "# generated\n",
                "docs/human/sdk/version-matrix.md": "# matrix\n",
                "docs/llm/SDK_GENERATED_VERIFICATION.md": "# verification\n",
            },
        ),
    ]

    manifest_artifacts = []
    for prefix, kind, entries in artifacts:
        file_name = f"{prefix}-{COMMIT}.tar.gz"
        write_archive(out_dir / file_name, entries)
        manifest_artifacts.append({"file": file_name, "kind": kind})

    (out_dir / "manifest.json").write_text(
        json.dumps(
            {
                "schema": "grain.sdk.release.manifest.v1",
                "commit": COMMIT,
                "artifact_policy": {
                    "release_kind": "source-archive",
                    "wasm_binary": "not_included_source_only",
                    "platform_store_packages": "not_included",
                    "registry_publication": "not_included",
                },
                "artifacts": manifest_artifacts,
            }
        )
        + "\n",
        encoding="utf-8",
    )


class ExternalSdkHandoffTests(unittest.TestCase):
    def test_source_release_extracts_into_external_vendor_layout(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            release_dir = Path(tmp) / "release"
            vendor_dir = Path(tmp) / "external-app" / "vendor" / "grain-sdk"
            release_dir.mkdir()
            write_minimal_release(release_dir)

            result = module.check_handoff(
                release_dir=release_dir,
                expected_commit=COMMIT,
                vendor_dir=vendor_dir,
            )

            self.assertEqual(result.commit, COMMIT)
            self.assertEqual(result.registry_channel, "source-only")
            self.assertTrue((vendor_dir / COMMIT / "sdk/swift/Package.swift").is_file())
            self.assertTrue((vendor_dir / COMMIT / "sdk/kotlin/build.gradle.kts").is_file())
            self.assertTrue((vendor_dir / COMMIT / "sdk/wasm/package.json").is_file())

    def test_registry_publication_claim_is_rejected_for_source_handoff(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            release_dir = Path(tmp) / "release"
            vendor_dir = Path(tmp) / "external-app" / "vendor" / "grain-sdk"
            release_dir.mkdir()
            write_minimal_release(release_dir)
            manifest_path = release_dir / "manifest.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["artifact_policy"]["registry_publication"] = "npm"
            manifest_path.write_text(json.dumps(manifest) + "\n", encoding="utf-8")

            with self.assertRaisesRegex(SystemExit, "EXTERNAL_SDK_HANDOFF_ERR_REGISTRY_CHANNEL"):
                module.check_handoff(
                    release_dir=release_dir,
                    expected_commit=COMMIT,
                    vendor_dir=vendor_dir,
                )

    def test_archive_parent_directories_are_allowed(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            archive_path = Path(tmp) / f"grain-generated-bindings-{COMMIT}.tar.gz"
            target_dir = Path(tmp) / "vendor"
            write_archive(
                archive_path,
                {
                    "generated-bindings/": "",
                    "generated-bindings/swift/": "",
                    "generated-bindings/swift/GrainClientCore.swift": "// generated\n",
                    "generated-bindings/kotlin/": "",
                    "generated-bindings/kotlin/GrainClientCore.kt": "package dev.grain.generated\n",
                },
            )

            module.safe_extract_archive(
                archive_path,
                target_dir,
                ["generated-bindings/swift/", "generated-bindings/kotlin/"],
            )

            self.assertTrue((target_dir / "generated-bindings/swift/GrainClientCore.swift").is_file())


if __name__ == "__main__":
    unittest.main()
