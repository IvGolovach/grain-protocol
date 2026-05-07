#!/usr/bin/env python3
"""Validate Grain SDK release package integrity metadata."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import tarfile
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
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
            "docs/human/sdk/start-here.md",
            "docs/human/sdk/scan-quickstart.md",
        ],
    },
}
FORBIDDEN_ARCHIVE_RE = re.compile(
    r"(^|/)(node_modules|dist|build|\.build|\.gradle|\.kotlin|target|pkg)/|\.wasm$"
)
SECRET_ARCHIVE_RE = re.compile(r"(^|/)(\.env(?:[._-][^/]*)?|secrets?)(/|$)|\.(pem|key|p12|pfx)$")
SHA_RE = re.compile(r"^[0-9a-f]{64}$")
COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--expected-commit")
    parser.add_argument("--require-strict", action="store_true")
    parser.add_argument("--require-clean", action="store_true")
    return parser.parse_args()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def safe_file_name(file_name: str) -> bool:
    p = Path(file_name)
    return (
        file_name
        and p.name == file_name
        and not p.is_absolute()
        and ".." not in p.parts
        and "/" not in file_name
    )


def artifact_prefix(file_name: str, commit: str) -> str:
    suffix = f"-{commit}.tar.gz"
    require(
        file_name.endswith(suffix),
        f"SDK_RELEASE_CHECK_ERR_ARTIFACT_COMMIT: {file_name} does not end with {suffix}",
    )
    return file_name[: -len(suffix)]


def load_cargo_version(path: str) -> str:
    data = tomllib.loads((ROOT / path).read_text(encoding="utf-8"))
    return str(data["package"]["version"])


def expected_versions() -> dict[str, str]:
    kotlin_text = (ROOT / "sdk/kotlin/build.gradle.kts").read_text(encoding="utf-8")
    kotlin_version = re.search(r'^\s*version\s*=\s*"([^"]+)"', kotlin_text, re.MULTILINE)
    require(kotlin_version is not None, "SDK_RELEASE_CHECK_ERR_KOTLIN_VERSION_MISSING")
    wasm = json.loads((ROOT / "sdk/wasm/package.json").read_text(encoding="utf-8"))
    return {
        "grain_client_core": load_cargo_version("core/rust/grain-client-core/Cargo.toml"),
        "grain_client_wasm": load_cargo_version("core/rust/grain-client-wasm/Cargo.toml"),
        "kotlin_client": kotlin_version.group(1),
        "wasm_client": str(wasm["version"]),
        "swift_client": "repo-sha",
    }


def validate_archive(path: Path, expected: dict[str, object]) -> None:
    seen: set[str] = set()
    entries: list[str] = []
    with tarfile.open(path, "r:gz") as archive:
        for member in archive.getmembers():
            name = member.name
            require(name not in seen, f"SDK_RELEASE_CHECK_ERR_DUP_ARCHIVE_ENTRY: {path.name}:{name}")
            seen.add(name)
            entries.append(name)
            parts = Path(name).parts
            require(name and not name.startswith("/"), f"SDK_RELEASE_CHECK_ERR_ABSOLUTE_ENTRY: {path.name}:{name}")
            require(".." not in parts, f"SDK_RELEASE_CHECK_ERR_TRAVERSAL_ENTRY: {path.name}:{name}")
            require(
                member.isfile() or member.isdir(),
                f"SDK_RELEASE_CHECK_ERR_UNSUPPORTED_ARCHIVE_ENTRY: {path.name}:{name}",
            )
            require(
                not FORBIDDEN_ARCHIVE_RE.search(name),
                f"SDK_RELEASE_CHECK_ERR_FORBIDDEN_ARCHIVE_ENTRY: {path.name}:{name}",
            )
            require(
                not SECRET_ARCHIVE_RE.search(name),
                f"SDK_RELEASE_CHECK_ERR_SECRET_ARCHIVE_ENTRY: {path.name}:{name}",
            )

    for required in expected["required_entries"]:
        require(
            any(entry == required or entry.startswith(required) for entry in entries),
            f"SDK_RELEASE_CHECK_ERR_REQUIRED_ENTRY_MISSING: {path.name}:{required}",
        )


def validate_sums(out_dir: Path, expected: dict[str, str]) -> None:
    sums_path = out_dir / "SHA256SUMS"
    require(sums_path.is_file(), "SDK_RELEASE_CHECK_ERR_SHA256SUMS_MISSING")
    actual: dict[str, str] = {}
    for line in sums_path.read_text(encoding="utf-8").splitlines():
        if not line:
            continue
        parts = line.split("  ")
        require(len(parts) == 2, f"SDK_RELEASE_CHECK_ERR_SHA256SUMS_LINE: {line}")
        checksum, file_name = parts
        require(SHA_RE.match(checksum) is not None, f"SDK_RELEASE_CHECK_ERR_SHA256SUMS_HASH: {line}")
        require(safe_file_name(file_name), f"SDK_RELEASE_CHECK_ERR_SHA256SUMS_FILE: {line}")
        require(file_name not in actual, f"SDK_RELEASE_CHECK_ERR_SHA256SUMS_DUP: {file_name}")
        actual[file_name] = checksum
    require(actual == expected, "SDK_RELEASE_CHECK_ERR_SHA256SUMS_MISMATCH")


def validate_sbom(out_dir: Path, manifest: dict[str, object]) -> None:
    sbom_meta = manifest.get("sbom")
    require(isinstance(sbom_meta, dict), "SDK_RELEASE_CHECK_ERR_SBOM_META")
    file_name = sbom_meta.get("file")
    require(isinstance(file_name, str) and safe_file_name(file_name), "SDK_RELEASE_CHECK_ERR_SBOM_FILE")
    sbom_path = out_dir / file_name
    require(sbom_path.is_file(), "SDK_RELEASE_CHECK_ERR_SBOM_MISSING")
    require(sbom_meta.get("sha256") == sha256_file(sbom_path), "SDK_RELEASE_CHECK_ERR_SBOM_SHA")
    require(sbom_meta.get("bytes") == sbom_path.stat().st_size, "SDK_RELEASE_CHECK_ERR_SBOM_BYTES")

    sbom = json.loads(sbom_path.read_text(encoding="utf-8"))
    require(sbom.get("spdxVersion") == "SPDX-2.3", "SDK_RELEASE_CHECK_ERR_SBOM_VERSION")
    require(sbom.get("SPDXID") == "SPDXRef-DOCUMENT", "SDK_RELEASE_CHECK_ERR_SBOM_ID")
    package_by_name = {pkg.get("name"): pkg for pkg in sbom.get("packages", []) if isinstance(pkg, dict)}

    for artifact in manifest["artifacts"]:
        pkg = package_by_name.get(artifact["name"])
        require(pkg is not None, f"SDK_RELEASE_CHECK_ERR_SBOM_PACKAGE_MISSING: {artifact['name']}")
        checksums = pkg.get("checksums", [])
        require(isinstance(checksums, list), f"SDK_RELEASE_CHECK_ERR_SBOM_CHECKSUMS: {artifact['name']}")
        sha_values = {
            item.get("checksumValue")
            for item in checksums
            if isinstance(item, dict) and item.get("algorithm") == "SHA256"
        }
        require(
            artifact["sha256"] in sha_values,
            f"SDK_RELEASE_CHECK_ERR_SBOM_ARTIFACT_SHA: {artifact['name']}",
        )


def validate_manifest(out_dir: Path, args: argparse.Namespace) -> dict[str, object]:
    manifest_path = out_dir / "manifest.json"
    require(manifest_path.is_file(), "SDK_RELEASE_CHECK_ERR_MANIFEST_MISSING")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))

    require(manifest.get("schema") == "grain.sdk.release.manifest.v1", "SDK_RELEASE_CHECK_ERR_SCHEMA")
    commit = manifest.get("commit")
    require(isinstance(commit, str) and COMMIT_RE.match(commit) is not None, "SDK_RELEASE_CHECK_ERR_COMMIT")
    if args.expected_commit:
        require(commit == args.expected_commit, "SDK_RELEASE_CHECK_ERR_COMMIT_MISMATCH")

    require(isinstance(manifest.get("dirty"), bool), "SDK_RELEASE_CHECK_ERR_DIRTY_TYPE")
    if args.require_clean:
        require(manifest["dirty"] is False, "SDK_RELEASE_CHECK_ERR_DIRTY_RELEASE")

    verification = manifest.get("verification")
    require(isinstance(verification, dict), "SDK_RELEASE_CHECK_ERR_VERIFICATION")
    mode = verification.get("mode")
    require(mode in {"strict", "strict-upstream", "skipped"}, "SDK_RELEASE_CHECK_ERR_VERIFICATION_MODE")
    require(isinstance(verification.get("source"), str) and verification["source"], "SDK_RELEASE_CHECK_ERR_VERIFICATION_SOURCE")
    if args.require_strict:
        require(mode in {"strict", "strict-upstream"}, "SDK_RELEASE_CHECK_ERR_VERIFICATION_NOT_STRICT")

    require(manifest.get("workflow_contract") == "client_workflow_v1", "SDK_RELEASE_CHECK_ERR_WORKFLOW_CONTRACT")
    policy = manifest.get("artifact_policy")
    require(isinstance(policy, dict), "SDK_RELEASE_CHECK_ERR_ARTIFACT_POLICY")
    require(policy.get("release_kind") == "source-archive", "SDK_RELEASE_CHECK_ERR_RELEASE_KIND")
    require(policy.get("wasm_binary") == "not_included_source_only", "SDK_RELEASE_CHECK_ERR_WASM_BINARY_POLICY")
    require(policy.get("platform_store_packages") == "not_included", "SDK_RELEASE_CHECK_ERR_STORE_PACKAGE_POLICY")
    require(policy.get("registry_publication") == "not_included", "SDK_RELEASE_CHECK_ERR_REGISTRY_POLICY")

    matrix = manifest.get("version_matrix")
    require(isinstance(matrix, dict), "SDK_RELEASE_CHECK_ERR_VERSION_MATRIX")
    require(matrix.get("path") == "docs/human/sdk/version-matrix.md", "SDK_RELEASE_CHECK_ERR_VERSION_MATRIX_PATH")
    require(
        matrix.get("sha256") == sha256_file(ROOT / "docs/human/sdk/version-matrix.md"),
        "SDK_RELEASE_CHECK_ERR_VERSION_MATRIX_SHA",
    )
    require(matrix.get("rule") == "same-repo-sha", "SDK_RELEASE_CHECK_ERR_VERSION_MATRIX_RULE")

    versions = manifest.get("sdk_versions")
    require(isinstance(versions, dict), "SDK_RELEASE_CHECK_ERR_SDK_VERSIONS")
    for key, expected in expected_versions().items():
        require(key in versions and isinstance(versions[key], dict), f"SDK_RELEASE_CHECK_ERR_VERSION_KEY: {key}")
        require(versions[key].get("version") == expected, f"SDK_RELEASE_CHECK_ERR_VERSION_VALUE: {key}")

    artifacts = manifest.get("artifacts")
    require(isinstance(artifacts, list), "SDK_RELEASE_CHECK_ERR_ARTIFACTS_TYPE")
    require(len(artifacts) == len(EXPECTED_ARTIFACTS), "SDK_RELEASE_CHECK_ERR_ARTIFACT_COUNT")
    seen: set[str] = set()
    expected_sums: dict[str, str] = {}

    for artifact in artifacts:
        require(isinstance(artifact, dict), "SDK_RELEASE_CHECK_ERR_ARTIFACT_TYPE")
        file_name = artifact.get("file")
        require(isinstance(file_name, str) and safe_file_name(file_name), "SDK_RELEASE_CHECK_ERR_ARTIFACT_FILE")
        require(file_name not in seen, f"SDK_RELEASE_CHECK_ERR_ARTIFACT_DUP: {file_name}")
        seen.add(file_name)
        prefix = artifact_prefix(file_name, commit)
        expected = EXPECTED_ARTIFACTS.get(prefix)
        require(expected is not None, f"SDK_RELEASE_CHECK_ERR_ARTIFACT_UNKNOWN: {file_name}")
        require(artifact.get("kind") == expected["kind"], f"SDK_RELEASE_CHECK_ERR_ARTIFACT_KIND: {file_name}")
        artifact_path = out_dir / file_name
        require(artifact_path.is_file(), f"SDK_RELEASE_CHECK_ERR_ARTIFACT_MISSING: {file_name}")
        require(artifact.get("bytes") == artifact_path.stat().st_size, f"SDK_RELEASE_CHECK_ERR_ARTIFACT_BYTES: {file_name}")
        checksum = artifact.get("sha256")
        require(isinstance(checksum, str) and SHA_RE.match(checksum) is not None, f"SDK_RELEASE_CHECK_ERR_ARTIFACT_SHA_FORMAT: {file_name}")
        require(checksum == sha256_file(artifact_path), f"SDK_RELEASE_CHECK_ERR_ARTIFACT_SHA: {file_name}")
        validate_archive(artifact_path, expected)
        expected_sums[file_name] = checksum

    sbom = manifest.get("sbom")
    require(isinstance(sbom, dict), "SDK_RELEASE_CHECK_ERR_SBOM_META")
    expected_sums[str(sbom["file"])] = str(sbom["sha256"])
    validate_sums(out_dir, expected_sums)
    validate_sbom(out_dir, manifest)
    return manifest


def main() -> int:
    args = parse_args()
    out_dir = Path(args.out_dir).resolve()
    require(out_dir.is_dir(), f"SDK_RELEASE_CHECK_ERR_OUT_DIR_MISSING: {out_dir}")
    manifest = validate_manifest(out_dir, args)
    print(
        "SDK release package check: OK "
        f"({len(manifest['artifacts'])} artifacts, commit {manifest['commit']})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
