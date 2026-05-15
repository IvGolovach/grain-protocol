#!/usr/bin/env python3
"""Focused tests for external release consumer smoke validation."""

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
MODULE_PATH = ROOT / "tools" / "ci" / "check_external_release_consumer_smoke.py"
COMMIT = "0123456789abcdef0123456789abcdef01234567"


def load_module():
    spec = importlib.util.spec_from_file_location("check_external_release_consumer_smoke", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise AssertionError("Could not load check_external_release_consumer_smoke.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def write_archive(path: Path, entries: dict[str, str]) -> None:
    with tarfile.open(path, "w:gz") as archive:
        for name, text in entries.items():
            payload = text.encode("utf-8")
            info = tarfile.TarInfo(name)
            info.size = len(payload)
            info.mode = 0o755 if name.endswith(".sh") or name.endswith("gradlew") else 0o644
            archive.addfile(info, io.BytesIO(payload))


def write_release(release_dir: Path, *, rust_members: str | None = None) -> None:
    rust_members = rust_members or '"grain-core",\n  "grain-client-core",\n  "grain-client-wasm"'
    artifacts = [
        (
            "grain-rust-client-core",
            "rust-client-core",
            {
                "core/rust/Cargo.toml": f"[workspace]\nmembers = [\n  {rust_members},\n]\nresolver = \"2\"\n",
                "core/rust/Cargo.lock": "# lock\n",
                "core/rust/rust-toolchain.toml": "[toolchain]\nchannel = \"stable\"\n",
                "core/rust/grain-core/Cargo.toml": "[package]\nname = \"grain-core\"\n",
                "core/rust/grain-client-core/Cargo.toml": "[package]\nname = \"grain-client-core\"\n",
                "core/rust/grain-client-core/src/grain_client_core.udl": "namespace grain_client_core {};\n",
                "core/rust/grain-client-wasm/Cargo.toml": "[package]\nname = \"grain-client-wasm\"\n",
            },
        ),
        (
            "grain-swift-client",
            "swift-client",
            {"sdk/swift/Package.swift": "// swift\n", "sdk/swift/Sources/GrainClient/GrainClient.swift": "// api\n"},
        ),
        (
            "grain-kotlin-client",
            "kotlin-client",
            {
                "sdk/kotlin/build.gradle.kts": "plugins {}\n",
                "sdk/kotlin/gradlew": "#!/usr/bin/env sh\n",
                "sdk/kotlin/src/main/kotlin/dev/grain/GrainClient.kt": "package dev.grain\n",
            },
        ),
        (
            "grain-wasm-client",
            "wasm-client",
            {
                "sdk/wasm/package.json": '{"name":"@grain/client-wasm"}\n',
                "sdk/wasm/src/index.mjs": "export {}\n",
                "core/rust/grain-client-wasm/Cargo.toml": "[package]\nname = \"grain-client-wasm\"\n",
            },
        ),
        (
            "grain-typescript-sdk",
            "typescript-sdk",
            {
                "core/ts/grain-ts-core/package.json": '{"name":"grain-ts-core","version":"0.1.0","files":["dist"],"exports":{"./types":{"types":"./dist/src/types.d.ts","default":"./dist/src/types.js"}}}\n',
                "core/ts/grain-ts-core/src/types.ts": "export type Grain = string;\n",
                "core/ts/grain-sdk/package.json": '{"name":"grain-sdk-ts","version":"0.2.0","files":["dist"],"exports":{".":{"types":"./dist/src/index.d.ts","default":"./dist/src/index.js"}}}\n',
                "core/ts/grain-sdk/src/index.ts": "export const grain = true;\n",
                "core/ts/grain-sdk-ai/package.json": '{"name":"grain-sdk-ai-ts","version":"0.2.0","files":["dist"],"exports":{".":{"types":"./dist/src/index.d.ts","default":"./dist/src/index.js"}}}\n',
                "core/ts/grain-sdk-ai/src/index.ts": "export const ai = true;\n",
                "fixtures/external-consumers/npm-sdk/package.json": '{"private":true,"dependencies":{"grain-ts-core":"file:../../../core/ts/grain-ts-core","grain-sdk-ts":"file:../../../core/ts/grain-sdk","grain-sdk-ai-ts":"file:../../../core/ts/grain-sdk-ai"}}\n',
                "fixtures/external-consumers/npm-sdk/src/import-smoke.ts": 'import "grain-sdk-ts";\n',
                "fixtures/external-consumers/npm-sdk/src/runtime-smoke.mjs": 'await import("grain-sdk-ts");\n',
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
    for prefix, kind, entries in artifacts:
        file_name = f"{prefix}-{COMMIT}.tar.gz"
        write_archive(release_dir / file_name, entries)
        manifest_artifacts.append({"file": file_name, "kind": kind, "commit": COMMIT})

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


class ExternalReleaseConsumerSmokeTests(unittest.TestCase):
    def test_release_assets_can_seed_consumer_smoke_layout(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            release_dir = Path(tmp) / "release"
            consumer_root = Path(tmp) / "consumer"
            release_dir.mkdir()
            write_release(release_dir)

            result = module.check_external_release_consumer_smoke(
                release_dir=release_dir,
                expected_commit=COMMIT,
                consumer_root=consumer_root,
                run_commands=False,
            )

            self.assertEqual(result.commit, COMMIT)
            self.assertIn("rust-workspace-policy", result.checks)
            self.assertTrue((consumer_root / "vendor/grain-sdk/core/rust/Cargo.toml").is_file())
            self.assertTrue((consumer_root / "vendor/grain-sdk/core/ts/grain-sdk/package.json").is_file())

    def test_release_rust_workspace_rejects_monorepo_internal_members(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            release_dir = Path(tmp) / "release"
            release_dir.mkdir()
            write_release(release_dir, rust_members='"grain-core",\n  "grain-runner",\n  "grain-client-core"')

            with self.assertRaisesRegex(SystemExit, "EXTERNAL_RELEASE_CONSUMER_SMOKE_ERR_RUST_WORKSPACE_MEMBERS"):
                module.check_external_release_consumer_smoke(
                    release_dir=release_dir,
                    expected_commit=COMMIT,
                    consumer_root=Path(tmp) / "consumer",
                    run_commands=False,
                )


if __name__ == "__main__":
    unittest.main()
