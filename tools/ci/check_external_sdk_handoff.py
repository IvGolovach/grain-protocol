#!/usr/bin/env python3
"""Validate a source SDK handoff from the outside-app consumer boundary."""

from __future__ import annotations

import argparse
import json
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
        "required_entries": [
            "generated-bindings/swift/",
            "generated-bindings/kotlin/",
        ],
    },
    "grain-swift-client": {
        "kind": "swift-client",
        "required_entries": [
            "sdk/swift/Package.swift",
            "sdk/swift/Sources/GrainClient/",
        ],
    },
    "grain-kotlin-client": {
        "kind": "kotlin-client",
        "required_entries": [
            "sdk/kotlin/build.gradle.kts",
            "sdk/kotlin/src/main/kotlin/",
        ],
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
            "scripts/sdk/check_starter_templates.sh",
        ],
    },
}

ALLOWED_ENTRY_PREFIXES = (
    "generated-bindings/swift/",
    "generated-bindings/kotlin/",
    "sdk/swift/",
    "sdk/kotlin/",
    "sdk/wasm/",
    "sdk/api/",
    "sdk/custody/",
    "sdk/workflows/",
    "sdk/trust/",
    "sdk/generated/",
    "templates/",
    "examples/ios-scanner/",
    "examples/android-scanner/",
    "examples/wasm-scanner/",
    "scripts/sdk/check_starter_templates.sh",
    "core/rust/grain-client-wasm/",
    "docs/human/sdk/version-matrix.md",
    "docs/human/sdk/start-here.md",
    "docs/human/sdk/scan-quickstart.md",
    "docs/human/sdk/security-review.md",
    "docs/human/sdk/release-train.md",
    "docs/llm/SDK_GENERATED_VERIFICATION.md",
)
ALLOWED_DIRECTORY_ENTRIES = {
    "generated-bindings",
    "generated-bindings/swift",
    "generated-bindings/kotlin",
    "sdk",
    "sdk/swift",
    "sdk/swift/Sources",
    "sdk/kotlin",
    "sdk/kotlin/src",
    "sdk/kotlin/src/main",
    "sdk/kotlin/src/main/kotlin",
    "sdk/wasm",
    "sdk/wasm/src",
    "sdk/api",
    "sdk/custody",
    "sdk/workflows",
    "sdk/workflows/contract",
    "sdk/trust",
    "sdk/generated",
    "templates",
    "templates/ios-starter",
    "templates/android-starter",
    "templates/web-wasm-starter",
    "examples",
    "examples/ios-scanner",
    "examples/android-scanner",
    "examples/wasm-scanner",
    "scripts",
    "scripts/sdk",
    "core",
    "core/rust",
    "core/rust/grain-client-wasm",
    "docs",
    "docs/human",
    "docs/human/sdk",
    "docs/llm",
}


@dataclass(frozen=True)
class HandoffResult:
    commit: str
    registry_channel: str
    vendor_root: Path
    artifacts: tuple[str, ...]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--out-dir", required=True, help="Directory containing SDK release assets")
    parser.add_argument("--expected-commit", help="Expected Grain repo commit/tag SHA")
    parser.add_argument(
        "--vendor-dir",
        help="External app vendor directory. Defaults to a temporary network-free consumer layout.",
    )
    parser.add_argument("--require-strict", action="store_true")
    parser.add_argument("--require-clean", action="store_true")
    return parser.parse_args()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def load_manifest(release_dir: Path) -> dict[str, object]:
    manifest_path = release_dir / "manifest.json"
    require(manifest_path.is_file(), "EXTERNAL_SDK_HANDOFF_ERR_MANIFEST_MISSING")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    require(
        manifest.get("schema") == "grain.sdk.release.manifest.v1",
        "EXTERNAL_SDK_HANDOFF_ERR_SCHEMA",
    )
    commit = manifest.get("commit")
    require(
        isinstance(commit, str) and release_check.COMMIT_RE.match(commit) is not None,
        "EXTERNAL_SDK_HANDOFF_ERR_COMMIT",
    )
    return manifest


def validate_source_policy(manifest: dict[str, object]) -> None:
    policy = manifest.get("artifact_policy")
    require(isinstance(policy, dict), "EXTERNAL_SDK_HANDOFF_ERR_ARTIFACT_POLICY")
    require(policy.get("release_kind") == "source-archive", "EXTERNAL_SDK_HANDOFF_ERR_RELEASE_KIND")
    require(
        policy.get("wasm_binary") == "not_included_source_only",
        "EXTERNAL_SDK_HANDOFF_ERR_WASM_BINARY_POLICY",
    )
    require(
        policy.get("platform_store_packages") == "not_included",
        "EXTERNAL_SDK_HANDOFF_ERR_STORE_PACKAGE_CHANNEL",
    )
    require(
        policy.get("registry_publication") == "not_included",
        "EXTERNAL_SDK_HANDOFF_ERR_REGISTRY_CHANNEL",
    )


def artifact_prefix(file_name: str, commit: str) -> str:
    suffix = f"-{commit}.tar.gz"
    require(
        file_name.endswith(suffix),
        f"EXTERNAL_SDK_HANDOFF_ERR_ARTIFACT_COMMIT: {file_name}",
    )
    return file_name[: -len(suffix)]


def validate_entry_boundary(archive_name: str, entry_name: str) -> None:
    parts = Path(entry_name).parts
    require(
        entry_name and not entry_name.startswith("/"),
        f"EXTERNAL_SDK_HANDOFF_ERR_ABSOLUTE_ENTRY: {archive_name}:{entry_name}",
    )
    require(
        ".." not in parts,
        f"EXTERNAL_SDK_HANDOFF_ERR_TRAVERSAL_ENTRY: {archive_name}:{entry_name}",
    )
    require(
        entry_name in ALLOWED_DIRECTORY_ENTRIES
        or any(entry_name == prefix.rstrip("/") or entry_name.startswith(prefix) for prefix in ALLOWED_ENTRY_PREFIXES),
        f"EXTERNAL_SDK_HANDOFF_ERR_MONOREPO_INTERNAL_ENTRY: {archive_name}:{entry_name}",
    )


def safe_extract_archive(archive_path: Path, target_dir: Path, required_entries: list[str]) -> None:
    entries: list[str] = []
    with tarfile.open(archive_path, "r:gz") as archive:
        members = archive.getmembers()
        for member in members:
            validate_entry_boundary(archive_path.name, member.name)
            require(
                member.isfile() or member.isdir(),
                f"EXTERNAL_SDK_HANDOFF_ERR_UNSUPPORTED_ARCHIVE_ENTRY: {archive_path.name}:{member.name}",
            )
            entries.append(member.name)
            output_path = target_dir / member.name
            if member.isdir():
                output_path.mkdir(parents=True, exist_ok=True)
                continue
            output_path.parent.mkdir(parents=True, exist_ok=True)
            source = archive.extractfile(member)
            require(
                source is not None,
                f"EXTERNAL_SDK_HANDOFF_ERR_UNREADABLE_ENTRY: {archive_path.name}:{member.name}",
            )
            with source, output_path.open("wb") as handle:
                handle.write(source.read())

    for required in required_entries:
        require(
            any(entry == required or entry.startswith(required) for entry in entries),
            f"EXTERNAL_SDK_HANDOFF_ERR_REQUIRED_ENTRY_MISSING: {archive_path.name}:{required}",
        )


def validate_artifacts(manifest: dict[str, object], release_dir: Path, target_dir: Path) -> tuple[str, ...]:
    commit = str(manifest["commit"])
    artifacts = manifest.get("artifacts")
    require(isinstance(artifacts, list), "EXTERNAL_SDK_HANDOFF_ERR_ARTIFACTS_TYPE")
    require(len(artifacts) == len(EXPECTED_ARTIFACTS), "EXTERNAL_SDK_HANDOFF_ERR_ARTIFACT_COUNT")

    seen_prefixes: set[str] = set()
    extracted: list[str] = []
    for artifact in artifacts:
        require(isinstance(artifact, dict), "EXTERNAL_SDK_HANDOFF_ERR_ARTIFACT_TYPE")
        file_name = artifact.get("file")
        require(
            isinstance(file_name, str) and release_check.safe_file_name(file_name),
            "EXTERNAL_SDK_HANDOFF_ERR_ARTIFACT_FILE",
        )
        prefix = artifact_prefix(file_name, commit)
        expected = EXPECTED_ARTIFACTS.get(prefix)
        require(expected is not None, f"EXTERNAL_SDK_HANDOFF_ERR_ARTIFACT_UNKNOWN: {file_name}")
        require(prefix not in seen_prefixes, f"EXTERNAL_SDK_HANDOFF_ERR_ARTIFACT_DUP: {file_name}")
        seen_prefixes.add(prefix)
        require(
            artifact.get("kind") == expected["kind"],
            f"EXTERNAL_SDK_HANDOFF_ERR_ARTIFACT_KIND: {file_name}",
        )
        archive_path = release_dir / file_name
        require(archive_path.is_file(), f"EXTERNAL_SDK_HANDOFF_ERR_ARTIFACT_MISSING: {file_name}")
        safe_extract_archive(archive_path, target_dir, expected["required_entries"])
        extracted.append(file_name)

    require(
        seen_prefixes == set(EXPECTED_ARTIFACTS),
        "EXTERNAL_SDK_HANDOFF_ERR_ARTIFACT_SET",
    )
    return tuple(sorted(extracted))


def validate_vendor_layout(target_dir: Path) -> None:
    required_files = [
        "sdk/swift/Package.swift",
        "sdk/kotlin/build.gradle.kts",
        "sdk/wasm/package.json",
        "core/rust/grain-client-wasm/Cargo.toml",
        "sdk/workflows/contract/client_workflow_v1.md",
        "sdk/workflows/contract/safe_diagnostic_event_v1.schema.json",
        "sdk/api/public-sdk-v0.1.json",
        "sdk/custody/secure_storage_adapter_v1.md",
        "sdk/trust/trust_anchor_bundle_v1.schema.json",
        "templates/ios-starter/Package.swift",
        "templates/android-starter/build.gradle.kts",
        "templates/web-wasm-starter/package.json",
        "examples/ios-scanner/Package.swift",
        "examples/android-scanner/build.gradle.kts",
        "examples/wasm-scanner/package.json",
        "scripts/sdk/check_starter_templates.sh",
        "generated-bindings/swift",
        "generated-bindings/kotlin",
    ]
    for relative in required_files:
        path = target_dir / relative
        require(path.exists(), f"EXTERNAL_SDK_HANDOFF_ERR_VENDOR_FILE_MISSING: {relative}")


def check_handoff(
    *,
    release_dir: Path,
    expected_commit: str | None = None,
    vendor_dir: Path,
    require_strict: bool = False,
    require_clean: bool = False,
) -> HandoffResult:
    release_dir = release_dir.resolve()
    vendor_dir = vendor_dir.resolve()
    manifest = load_manifest(release_dir)
    commit = str(manifest["commit"])
    if expected_commit is not None:
        require(commit == expected_commit, "EXTERNAL_SDK_HANDOFF_ERR_COMMIT_MISMATCH")
    validate_source_policy(manifest)

    if (release_dir / "SHA256SUMS").exists() and (release_dir / "sbom.spdx.json").exists():
        release_args = argparse.Namespace(
            out_dir=str(release_dir),
            expected_commit=expected_commit,
            require_strict=require_strict,
            require_clean=require_clean,
        )
        release_check.validate_manifest(release_dir, release_args)

    target_dir = vendor_dir / commit
    require(
        not target_dir.exists() or not any(target_dir.iterdir()),
        f"EXTERNAL_SDK_HANDOFF_ERR_VENDOR_TARGET_EXISTS: {target_dir}",
    )
    target_dir.mkdir(parents=True, exist_ok=True)

    artifacts = validate_artifacts(manifest, release_dir, target_dir)
    validate_vendor_layout(target_dir)
    return HandoffResult(
        commit=commit,
        registry_channel="source-only",
        vendor_root=target_dir,
        artifacts=artifacts,
    )


def main() -> int:
    args = parse_args()
    release_dir = Path(args.out_dir)
    if args.vendor_dir:
        result = check_handoff(
            release_dir=release_dir,
            expected_commit=args.expected_commit,
            vendor_dir=Path(args.vendor_dir),
            require_strict=args.require_strict,
            require_clean=args.require_clean,
        )
    else:
        with tempfile.TemporaryDirectory(prefix="grain-external-sdk-consumer.") as tmp:
            result = check_handoff(
                release_dir=release_dir,
                expected_commit=args.expected_commit,
                vendor_dir=Path(tmp) / "external-app" / "vendor" / "grain-sdk",
                require_strict=args.require_strict,
                require_clean=args.require_clean,
            )

    print(
        "External SDK handoff check: OK "
        f"({len(result.artifacts)} source artifacts, commit {result.commit}, channel {result.registry_channel})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
