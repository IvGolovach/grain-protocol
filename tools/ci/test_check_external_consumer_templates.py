#!/usr/bin/env python3
"""Focused tests for external consumer template release validation."""

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
MODULE_PATH = ROOT / "tools" / "ci" / "check_external_consumer_templates.py"
COMMIT = "0123456789abcdef0123456789abcdef01234567"


def load_module():
    spec = importlib.util.spec_from_file_location("check_external_consumer_templates", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise AssertionError("Could not load check_external_consumer_templates.py")
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


def write_release(release_dir: Path, *, wasm_commit: str = COMMIT) -> None:
    artifacts = [
        (
            "grain-swift-client",
            "swift-client",
            COMMIT,
            {"sdk/swift/Package.swift": "// swift\n", "sdk/swift/Sources/GrainClient/GrainClient.swift": "// api\n"},
        ),
        (
            "grain-kotlin-client",
            "kotlin-client",
            COMMIT,
            {
                "sdk/kotlin/build.gradle.kts": "version = \"0.1.0\"\n",
                "sdk/kotlin/src/main/kotlin/dev/grain/GrainClient.kt": "package dev.grain\n",
            },
        ),
        (
            "grain-wasm-client",
            "wasm-client",
            wasm_commit,
            {
                "sdk/wasm/package.json": '{"name":"@grain/client-wasm","version":"0.1.0"}\n',
                "sdk/wasm/src/index.mjs": "export class GrainClient {}\n",
                "core/rust/grain-client-wasm/Cargo.toml": "[package]\nname='grain-client-wasm'\n",
            },
        ),
        (
            "grain-generated-bindings",
            "generated-bindings",
            COMMIT,
            {
                "generated-bindings/swift/GrainClientCore.swift": "// generated\n",
                "generated-bindings/kotlin/GrainClientCore.kt": "package dev.grain.generated\n",
            },
        ),
        (
            "grain-sdk-workflow-contract",
            "workflow-contract",
            COMMIT,
            {
                "sdk/api/public-sdk-v0.1.json": "{}\n",
                "sdk/custody/secure_storage_adapter_v1.md": "# storage\n",
                "sdk/device/device_adapter_v1.schema.json": "{}\n",
                "sdk/device/README.md": "# device\n",
                "sdk/workflows/contract/client_workflow_v1.md": "# contract\n",
                "sdk/workflows/contract/safe_diagnostic_event_v1.schema.json": "{}\n",
                "sdk/trust/trust_anchor_bundle_v1.schema.json": "{}\n",
                "sdk/generated/README.md": "# generated\n",
                "docs/human/sdk/version-matrix.md": "# matrix\n",
                "docs/human/sdk/security-review.md": "# security\n",
                "docs/human/sdk/release-train.md": "# release train\n",
                "docs/llm/SDK_GENERATED_VERIFICATION.md": "# verification\n",
            },
        ),
        (
            "grain-starter-templates",
            "starter-templates",
            COMMIT,
            {
                "templates/ios-starter/Package.swift": "// swift\n",
                "templates/android-starter/build.gradle.kts": "plugins {}\n",
                "templates/web-wasm-starter/package.json": "{}\n",
                "examples/ios-scanner/Package.swift": "// swift\n",
                "examples/android-scanner/build.gradle.kts": "plugins {}\n",
                "examples/wasm-scanner/package.json": "{}\n",
                "examples/ios-reference-app/Package.swift": "// swift reference app\n",
                "examples/android-reference-app/build.gradle.kts": "plugins {}\n",
                "scripts/sdk/check_starter_templates.sh": "#!/usr/bin/env bash\n",
                "scripts/sdk/run_local_scanner_flow.sh": "#!/usr/bin/env bash\n",
                "tools/ci/check_local_scanner_flow_report.py": "#!/usr/bin/env python3\n",
            },
        ),
    ]

    manifest_artifacts = []
    for prefix, kind, commit, entries in artifacts:
        file_name = f"{prefix}-{commit}.tar.gz"
        write_archive(release_dir / file_name, entries)
        manifest_artifacts.append({"name": prefix, "file": file_name, "kind": kind, "commit": commit})

    (release_dir / "manifest.json").write_text(
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


class ExternalConsumerTemplateTests(unittest.TestCase):
    def test_same_sha_release_builds_external_consumer_layout(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            release_dir = Path(tmp) / "release"
            release_dir.mkdir()
            write_release(release_dir)

            result = module.check_external_consumer_templates(
                release_dir=release_dir,
                expected_commit=COMMIT,
            )

            self.assertEqual(result.commit, COMMIT)
            self.assertEqual(result.consumer_root.name, "consumer")
            self.assertTrue((result.consumer_root / "vendor/grain-sdk/sdk/swift/Package.swift").is_file())
            self.assertTrue((result.consumer_root / "vendor/grain-sdk/sdk/kotlin/build.gradle.kts").is_file())
            self.assertTrue((result.consumer_root / "vendor/grain-sdk/sdk/wasm/package.json").is_file())
            self.assertTrue(
                (result.consumer_root / "vendor/grain-sdk/sdk/device/device_adapter_v1.schema.json").is_file()
            )
            self.assertTrue((result.consumer_root / "vendor/grain-sdk/templates/ios-starter/Package.swift").is_file())
            self.assertTrue((result.consumer_root / "vendor/grain-sdk/examples/ios-scanner/Package.swift").is_file())
            self.assertTrue((result.consumer_root / "vendor/grain-sdk/examples/ios-reference-app/Package.swift").is_file())
            self.assertTrue(
                (result.consumer_root / "vendor/grain-sdk/examples/android-reference-app/build.gradle.kts").is_file()
            )
            self.assertTrue(
                (result.consumer_root / "vendor/grain-sdk/scripts/sdk/run_local_scanner_flow.sh").is_file()
            )
            self.assertTrue(
                (result.consumer_root / "vendor/grain-sdk/tools/ci/check_local_scanner_flow_report.py").is_file()
            )

    def test_mixed_sha_release_artifact_is_rejected(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            release_dir = Path(tmp) / "release"
            release_dir.mkdir()
            write_release(release_dir, wasm_commit="fedcba9876543210fedcba9876543210fedcba98")

            with self.assertRaisesRegex(SystemExit, "EXTERNAL_CONSUMER_TEMPLATES_ERR_ARTIFACT_COMMIT"):
                module.check_external_consumer_templates(
                    release_dir=release_dir,
                    expected_commit=COMMIT,
                )

    def test_publication_policy_claim_is_rejected(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            release_dir = Path(tmp) / "release"
            release_dir.mkdir()
            write_release(release_dir)
            manifest_path = release_dir / "manifest.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["artifact_policy"]["notes"] = "Ready for Play Console"
            manifest_path.write_text(json.dumps(manifest) + "\n", encoding="utf-8")

            with self.assertRaisesRegex(SystemExit, "EXTERNAL_CONSUMER_TEMPLATES_ERR_PUBLICATION_CLAIM"):
                module.check_external_consumer_templates(
                    release_dir=release_dir,
                    expected_commit=COMMIT,
                )


if __name__ == "__main__":
    unittest.main()
