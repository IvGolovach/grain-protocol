#!/usr/bin/env python3
"""Validate SDK release assets from an external consumer layout."""

from __future__ import annotations

import argparse
import json
import shutil
import sys
import tarfile
import tempfile
from dataclasses import dataclass
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import check_sdk_release_package as release_check

EXPECTED_ARTIFACTS = {
    "grain-generated-bindings": {
        "kind": "generated-bindings",
        "required_entries": ["generated-bindings/swift/", "generated-bindings/kotlin/"],
    },
    "grain-swift-client": {
        "kind": "swift-client",
        "required_entries": ["sdk/swift/Package.swift", "sdk/swift/Sources/GrainClient/"],
    },
    "grain-kotlin-client": {
        "kind": "kotlin-client",
        "required_entries": ["sdk/kotlin/build.gradle.kts", "sdk/kotlin/src/main/kotlin/"],
    },
    "grain-wasm-client": {
        "kind": "wasm-client",
        "required_entries": [
            "sdk/wasm/package.json",
            "sdk/wasm/src/index.mjs",
            "core/rust/grain-client-wasm/Cargo.toml",
        ],
    },
    "grain-sdk-workflow-contract": {
        "kind": "workflow-contract",
        "required_entries": [
            "sdk/api/public-sdk-v0.1.json",
            "sdk/custody/secure_storage_adapter_v1.md",
            "sdk/device/device_adapter_v1.schema.json",
            "sdk/device/README.md",
            "sdk/workflows/contract/client_workflow_v1.md",
            "sdk/workflows/contract/safe_diagnostic_event_v1.schema.json",
            "sdk/trust/trust_anchor_bundle_v1.schema.json",
            "sdk/generated/README.md",
            "docs/human/sdk/version-matrix.md",
            "docs/human/sdk/security-review.md",
            "docs/human/sdk/release-train.md",
            "docs/llm/SDK_GENERATED_VERIFICATION.md",
        ],
    },
    "grain-starter-templates": {
        "kind": "starter-templates",
        "required_entries": [
            "templates/ios-starter/Package.swift",
            "templates/android-starter/build.gradle.kts",
            "templates/web-wasm-starter/package.json",
            "examples/ios-scanner/Package.swift",
            "examples/android-scanner/build.gradle.kts",
            "examples/wasm-scanner/package.json",
            "examples/ios-reference-app/Package.swift",
            "examples/android-reference-app/build.gradle.kts",
            "scripts/sdk/check_starter_templates.sh",
        ],
    },
}


@dataclass(frozen=True)
class ExternalConsumerResult:
    commit: str
    consumer_root: Path
    artifacts: tuple[str, ...]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--out-dir", required=True, help="Directory containing SDK release assets")
    parser.add_argument("--expected-commit")
    parser.add_argument("--consumer-root", help="External consumer root. Defaults to a temporary directory.")
    return parser.parse_args()


def load_manifest(release_dir: Path) -> dict[str, object]:
    manifest_path = release_dir / "manifest.json"
    require(manifest_path.is_file(), "EXTERNAL_CONSUMER_TEMPLATES_ERR_MANIFEST_MISSING")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    require(
        manifest.get("schema") == "grain.sdk.release.manifest.v1",
        "EXTERNAL_CONSUMER_TEMPLATES_ERR_SCHEMA",
    )
    commit = manifest.get("commit")
    require(
        isinstance(commit, str) and release_check.COMMIT_RE.match(commit) is not None,
        "EXTERNAL_CONSUMER_TEMPLATES_ERR_COMMIT",
    )
    return manifest


def validate_policy(manifest: dict[str, object]) -> None:
    release_check.validate_artifact_policy(
        manifest.get("artifact_policy"),
        error_prefix="EXTERNAL_CONSUMER_TEMPLATES_ERR",
    )


def artifact_prefix(file_name: str, commit: str) -> str:
    suffix = f"-{commit}.tar.gz"
    require(
        file_name.endswith(suffix),
        f"EXTERNAL_CONSUMER_TEMPLATES_ERR_ARTIFACT_COMMIT: {file_name}",
    )
    return file_name[: -len(suffix)]


def validate_archive_entry(archive_name: str, entry_name: str) -> None:
    parts = Path(entry_name).parts
    require(entry_name and not entry_name.startswith("/"), f"EXTERNAL_CONSUMER_TEMPLATES_ERR_ABSOLUTE_ENTRY: {archive_name}:{entry_name}")
    require(".." not in parts, f"EXTERNAL_CONSUMER_TEMPLATES_ERR_TRAVERSAL_ENTRY: {archive_name}:{entry_name}")


def extract_archive(archive_path: Path, target_dir: Path, required_entries: list[str]) -> None:
    entries: list[str] = []
    with tarfile.open(archive_path, "r:gz") as archive:
        for member in archive.getmembers():
            validate_archive_entry(archive_path.name, member.name)
            require(
                member.isfile() or member.isdir(),
                f"EXTERNAL_CONSUMER_TEMPLATES_ERR_UNSUPPORTED_ENTRY: {archive_path.name}:{member.name}",
            )
            entries.append(member.name)
            output_path = target_dir / member.name
            if member.isdir():
                output_path.mkdir(parents=True, exist_ok=True)
                continue
            output_path.parent.mkdir(parents=True, exist_ok=True)
            source = archive.extractfile(member)
            require(source is not None, f"EXTERNAL_CONSUMER_TEMPLATES_ERR_UNREADABLE_ENTRY: {archive_path.name}:{member.name}")
            with source, output_path.open("wb") as handle:
                shutil.copyfileobj(source, handle)

    for required in required_entries:
        require(
            any(entry == required or entry.startswith(required) for entry in entries),
            f"EXTERNAL_CONSUMER_TEMPLATES_ERR_REQUIRED_ENTRY_MISSING: {archive_path.name}:{required}",
        )


def validate_artifacts(manifest: dict[str, object], release_dir: Path, vendor_root: Path) -> tuple[str, ...]:
    commit = str(manifest["commit"])
    artifacts = manifest.get("artifacts")
    require(isinstance(artifacts, list), "EXTERNAL_CONSUMER_TEMPLATES_ERR_ARTIFACTS_TYPE")
    require(len(artifacts) == len(EXPECTED_ARTIFACTS), "EXTERNAL_CONSUMER_TEMPLATES_ERR_ARTIFACT_COUNT")
    seen: set[str] = set()
    extracted: list[str] = []

    for artifact in artifacts:
        require(isinstance(artifact, dict), "EXTERNAL_CONSUMER_TEMPLATES_ERR_ARTIFACT_TYPE")
        file_name = artifact.get("file")
        require(
            isinstance(file_name, str) and release_check.safe_file_name(file_name),
            "EXTERNAL_CONSUMER_TEMPLATES_ERR_ARTIFACT_FILE",
        )
        prefix = artifact_prefix(file_name, commit)
        expected = EXPECTED_ARTIFACTS.get(prefix)
        require(expected is not None, f"EXTERNAL_CONSUMER_TEMPLATES_ERR_ARTIFACT_UNKNOWN: {file_name}")
        require(prefix not in seen, f"EXTERNAL_CONSUMER_TEMPLATES_ERR_ARTIFACT_DUP: {file_name}")
        seen.add(prefix)
        require(artifact.get("kind") == expected["kind"], f"EXTERNAL_CONSUMER_TEMPLATES_ERR_ARTIFACT_KIND: {file_name}")
        if "commit" in artifact:
            require(artifact.get("commit") == commit, f"EXTERNAL_CONSUMER_TEMPLATES_ERR_ARTIFACT_COMMIT: {file_name}")
        archive_path = release_dir / file_name
        require(archive_path.is_file(), f"EXTERNAL_CONSUMER_TEMPLATES_ERR_ARTIFACT_MISSING: {file_name}")
        extract_archive(archive_path, vendor_root, expected["required_entries"])
        extracted.append(file_name)

    require(seen == set(EXPECTED_ARTIFACTS), "EXTERNAL_CONSUMER_TEMPLATES_ERR_ARTIFACT_SET")
    return tuple(sorted(extracted))


def validate_consumer_inputs(consumer_root: Path) -> None:
    required = [
        "vendor/grain-sdk/sdk/swift/Package.swift",
        "vendor/grain-sdk/sdk/kotlin/build.gradle.kts",
        "vendor/grain-sdk/sdk/wasm/package.json",
        "vendor/grain-sdk/sdk/api/public-sdk-v0.1.json",
        "vendor/grain-sdk/sdk/custody/secure_storage_adapter_v1.md",
        "vendor/grain-sdk/sdk/device/device_adapter_v1.schema.json",
        "vendor/grain-sdk/sdk/device/README.md",
        "vendor/grain-sdk/sdk/workflows/contract/client_workflow_v1.md",
        "vendor/grain-sdk/sdk/workflows/contract/safe_diagnostic_event_v1.schema.json",
        "vendor/grain-sdk/sdk/trust/trust_anchor_bundle_v1.schema.json",
        "vendor/grain-sdk/templates/ios-starter/Package.swift",
        "vendor/grain-sdk/templates/android-starter/build.gradle.kts",
        "vendor/grain-sdk/templates/web-wasm-starter/package.json",
        "vendor/grain-sdk/examples/ios-scanner/Package.swift",
        "vendor/grain-sdk/examples/android-scanner/build.gradle.kts",
        "vendor/grain-sdk/examples/wasm-scanner/package.json",
        "vendor/grain-sdk/examples/ios-reference-app/Package.swift",
        "vendor/grain-sdk/examples/android-reference-app/build.gradle.kts",
        "vendor/grain-sdk/scripts/sdk/check_starter_templates.sh",
        "vendor/grain-sdk/generated-bindings/swift",
        "vendor/grain-sdk/generated-bindings/kotlin",
    ]
    for relative in required:
        require(
            (consumer_root / relative).exists(),
            f"EXTERNAL_CONSUMER_TEMPLATES_ERR_CONSUMER_INPUT_MISSING: {relative}",
        )


def check_external_consumer_templates(
    *,
    release_dir: Path,
    expected_commit: str | None = None,
    consumer_root: Path | None = None,
) -> ExternalConsumerResult:
    release_dir = release_dir.resolve()
    manifest = load_manifest(release_dir)
    commit = str(manifest["commit"])
    if expected_commit is not None:
        require(commit == expected_commit, "EXTERNAL_CONSUMER_TEMPLATES_ERR_COMMIT_MISMATCH")
    validate_policy(manifest)

    if consumer_root is None:
        consumer_root = Path(tempfile.mkdtemp(prefix="grain-external-consumer.")) / "consumer"
    consumer_root = consumer_root.resolve()
    require(
        not consumer_root.exists() or not any(consumer_root.iterdir()),
        f"EXTERNAL_CONSUMER_TEMPLATES_ERR_CONSUMER_ROOT_EXISTS: {consumer_root}",
    )
    vendor_root = consumer_root / "vendor" / "grain-sdk"
    vendor_root.mkdir(parents=True, exist_ok=True)
    artifacts = validate_artifacts(manifest, release_dir, vendor_root)
    validate_consumer_inputs(consumer_root)
    return ExternalConsumerResult(commit=commit, consumer_root=consumer_root, artifacts=artifacts)


def main() -> int:
    args = parse_args()
    result = check_external_consumer_templates(
        release_dir=Path(args.out_dir),
        expected_commit=args.expected_commit,
        consumer_root=Path(args.consumer_root) if args.consumer_root else None,
    )
    print(
        "External consumer template check: OK "
        f"({len(result.artifacts)} source artifacts, commit {result.commit})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
