#!/usr/bin/env python3
"""Validate SDK release artifacts against the supported compatibility matrix."""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")
VERSION_KEYS = (
    "swift_client",
    "kotlin_client",
    "wasm_client",
    "grain_client_core",
    "grain_client_wasm",
)


@dataclass(frozen=True)
class CompatibilityMatrixResult:
    commit: str
    rule: str


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--manifest", required=True, help="SDK release manifest.json")
    parser.add_argument(
        "--matrix",
        help="Compatibility matrix JSON. Defaults to compatibility_matrix in sdk/api/public-sdk-v0.1.json.",
    )
    return parser.parse_args()


def load_json(path: Path) -> dict[str, object]:
    require(path.is_file(), f"SDK_COMPAT_MATRIX_ERR_FILE_MISSING: {path}")
    data = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(data, dict), f"SDK_COMPAT_MATRIX_ERR_JSON_OBJECT: {path}")
    return data


def default_matrix_data() -> dict[str, object]:
    snapshot = load_json(ROOT / "sdk/api/public-sdk-v0.1.json")
    matrix = snapshot.get("compatibility_matrix")
    require(isinstance(matrix, dict), "SDK_COMPAT_MATRIX_ERR_DEFAULT_MATRIX")
    return matrix


def artifact_commit(file_name: str) -> str | None:
    match = re.search(r"-([0-9a-f]{40})\.tar\.gz$", file_name)
    return match.group(1) if match else None


def validate_same_repo_sha(manifest: dict[str, object], commit: str) -> None:
    versions = manifest.get("sdk_versions")
    require(isinstance(versions, dict), "SDK_COMPAT_MATRIX_ERR_SDK_VERSIONS")
    for key in VERSION_KEYS:
        value = versions.get(key)
        require(isinstance(value, dict), f"SDK_COMPAT_MATRIX_ERR_VERSION_KEY: {key}")
        component_commit = value.get("commit", commit)
        require(component_commit == commit, f"SDK_COMPAT_MATRIX_ERR_COMPONENT_COMMIT: {key}")

    artifacts = manifest.get("artifacts", [])
    require(isinstance(artifacts, list), "SDK_COMPAT_MATRIX_ERR_ARTIFACTS")
    for artifact in artifacts:
        require(isinstance(artifact, dict), "SDK_COMPAT_MATRIX_ERR_ARTIFACT_TYPE")
        file_name = artifact.get("file")
        require(isinstance(file_name, str), "SDK_COMPAT_MATRIX_ERR_ARTIFACT_FILE")
        file_commit = artifact_commit(file_name)
        require(file_commit == commit, f"SDK_COMPAT_MATRIX_ERR_COMPONENT_COMMIT: {file_name}")
        if "commit" in artifact:
            require(artifact.get("commit") == commit, f"SDK_COMPAT_MATRIX_ERR_COMPONENT_COMMIT: {file_name}")


def manifest_combination(manifest: dict[str, object], commit: str) -> dict[str, str]:
    versions = manifest.get("sdk_versions")
    require(isinstance(versions, dict), "SDK_COMPAT_MATRIX_ERR_SDK_VERSIONS")
    combo = {
        "grain_commit": commit,
        "workflow_contract": str(manifest.get("workflow_contract")),
    }
    for key in VERSION_KEYS:
        value = versions.get(key)
        require(isinstance(value, dict), f"SDK_COMPAT_MATRIX_ERR_VERSION_KEY: {key}")
        version = value.get("version")
        require(isinstance(version, str) and version, f"SDK_COMPAT_MATRIX_ERR_VERSION_VALUE: {key}")
        combo[key] = version
    return combo


def matrix_entry_matches(entry: object, combo: dict[str, str]) -> bool:
    if not isinstance(entry, dict):
        return False
    for key, value in combo.items():
        expected = entry.get(key)
        if key == "grain_commit" and expected == "repo-sha":
            continue
        if expected != value:
            return False
    return True


def check_sdk_compatibility_matrix(
    *,
    manifest_path: Path,
    matrix_data: dict[str, object] | None = None,
) -> CompatibilityMatrixResult:
    manifest = load_json(manifest_path)
    require(manifest.get("schema") == "grain.sdk.release.manifest.v1", "SDK_COMPAT_MATRIX_ERR_MANIFEST_SCHEMA")
    commit = manifest.get("commit")
    require(isinstance(commit, str) and COMMIT_RE.match(commit) is not None, "SDK_COMPAT_MATRIX_ERR_COMMIT")

    matrix = matrix_data or default_matrix_data()
    require(matrix.get("schema") == "grain.sdk.compatibility-matrix.v1", "SDK_COMPAT_MATRIX_ERR_MATRIX_SCHEMA")
    rule = matrix.get("default_rule")
    require(rule == "same-repo-sha", "SDK_COMPAT_MATRIX_ERR_RULE")
    validate_same_repo_sha(manifest, commit)

    supported = matrix.get("supported")
    require(isinstance(supported, list), "SDK_COMPAT_MATRIX_ERR_SUPPORTED")
    combo = manifest_combination(manifest, commit)
    require(
        any(matrix_entry_matches(entry, combo) for entry in supported),
        "SDK_COMPAT_MATRIX_ERR_UNSUPPORTED_COMBINATION",
    )
    return CompatibilityMatrixResult(commit=commit, rule=str(rule))


def main() -> int:
    args = parse_args()
    matrix = load_json(Path(args.matrix)) if args.matrix else None
    result = check_sdk_compatibility_matrix(manifest_path=Path(args.manifest), matrix_data=matrix)
    print(f"SDK compatibility matrix check: OK (commit {result.commit}, rule {result.rule})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
