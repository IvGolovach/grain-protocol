#!/usr/bin/env python3
"""Build SDK release manifest, checksums, and SPDX SBOM metadata."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import re
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ARTIFACT_KINDS = {
    "grain-generated-bindings": {
        "kind": "generated-bindings",
        "name": "Grain generated Swift/Kotlin bindings",
        "source_paths": [
            "core/rust/grain-client-core/src/grain_client_core.udl",
            "scripts/sdk/generate_client_bindings.sh",
        ],
    },
    "grain-swift-client": {
        "kind": "swift-client",
        "name": "Grain Swift client source package",
        "source_paths": ["sdk/swift"],
    },
    "grain-kotlin-client": {
        "kind": "kotlin-client",
        "name": "Grain Kotlin client source package",
        "source_paths": ["sdk/kotlin"],
    },
    "grain-wasm-client": {
        "kind": "wasm-client",
        "name": "Grain WASM/mobile-web client source package",
        "source_paths": ["sdk/wasm", "core/rust/grain-client-wasm"],
    },
    "grain-sdk-workflow-contract": {
        "kind": "workflow-contract",
        "name": "Grain client workflow contract package",
        "source_paths": [
            "sdk/workflows",
            "sdk/generated",
            "docs/human/sdk/version-matrix.md",
            "docs/llm/SDK_GENERATED_VERIFICATION.md",
        ],
    },
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--dirty", choices=["true", "false"], required=True)
    parser.add_argument(
        "--verification-mode",
        choices=["strict", "strict-upstream", "skipped"],
        required=True,
    )
    parser.add_argument("--verification-source", required=True)
    return parser.parse_args()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_cargo_package(path: str) -> dict[str, str]:
    data = tomllib.loads((ROOT / path).read_text(encoding="utf-8"))
    package = data["package"]
    return {
        "name": str(package["name"]),
        "version": str(package["version"]),
        "license": str(package.get("license", "NOASSERTION")),
        "source": path,
    }


def load_wasm_package() -> dict[str, str]:
    path = "sdk/wasm/package.json"
    data = json.loads((ROOT / path).read_text(encoding="utf-8"))
    return {
        "name": str(data["name"]),
        "version": str(data["version"]),
        "license": "Apache-2.0",
        "source": path,
    }


def load_kotlin_package() -> dict[str, str]:
    path = "sdk/kotlin/build.gradle.kts"
    text = (ROOT / path).read_text(encoding="utf-8")
    match = re.search(r'^\s*version\s*=\s*"([^"]+)"', text, re.MULTILINE)
    if not match:
        raise SystemExit(f"SDK_RELEASE_METADATA_ERR_KOTLIN_VERSION: missing {path} version")
    return {
        "name": "dev.grain:grain-client",
        "version": match.group(1),
        "license": "Apache-2.0",
        "source": path,
    }


def load_sdk_versions() -> dict[str, dict[str, str]]:
    return {
        "grain_client_core": load_cargo_package("core/rust/grain-client-core/Cargo.toml"),
        "grain_client_wasm": load_cargo_package("core/rust/grain-client-wasm/Cargo.toml"),
        "swift_client": {
            "name": "GrainClient",
            "version": "repo-sha",
            "license": "Apache-2.0",
            "source": "sdk/swift/Package.swift",
        },
        "kotlin_client": load_kotlin_package(),
        "wasm_client": load_wasm_package(),
    }


def classify_artifact(file_name: str, commit: str) -> dict[str, object]:
    suffix = f"-{commit}.tar.gz"
    if not file_name.endswith(suffix):
        raise SystemExit(f"SDK_RELEASE_METADATA_ERR_ARTIFACT_NAME: {file_name}")
    prefix = file_name[: -len(suffix)]
    spec = ARTIFACT_KINDS.get(prefix)
    if spec is None:
        raise SystemExit(f"SDK_RELEASE_METADATA_ERR_ARTIFACT_KIND: {file_name}")
    return spec


def build_sbom(
    *,
    commit: str,
    created_at: str,
    artifacts: list[dict[str, object]],
    sdk_versions: dict[str, dict[str, str]],
) -> dict[str, object]:
    packages: list[dict[str, object]] = []
    relationships: list[dict[str, str]] = []

    for entry in artifacts:
        spdx_id = f"SPDXRef-Package-{entry['kind']}"
        packages.append(
            {
                "name": entry["name"],
                "SPDXID": spdx_id,
                "versionInfo": commit,
                "downloadLocation": "NOASSERTION",
                "filesAnalyzed": False,
                "licenseConcluded": "Apache-2.0",
                "licenseDeclared": "Apache-2.0",
                "copyrightText": "NOASSERTION",
                "checksums": [
                    {"algorithm": "SHA256", "checksumValue": entry["sha256"]},
                ],
                "supplier": "Organization: Grain maintainers",
            }
        )
        relationships.append(
            {
                "spdxElementId": "SPDXRef-DOCUMENT",
                "relationshipType": "DESCRIBES",
                "relatedSpdxElement": spdx_id,
            }
        )

    for key, meta in sdk_versions.items():
        spdx_id = f"SPDXRef-Component-{key.replace('_', '-')}"
        packages.append(
            {
                "name": meta["name"],
                "SPDXID": spdx_id,
                "versionInfo": meta["version"],
                "downloadLocation": "NOASSERTION",
                "filesAnalyzed": False,
                "licenseConcluded": meta["license"],
                "licenseDeclared": meta["license"],
                "copyrightText": "NOASSERTION",
                "supplier": "Organization: Grain maintainers",
            }
        )
        relationships.append(
            {
                "spdxElementId": "SPDXRef-DOCUMENT",
                "relationshipType": "DESCRIBES",
                "relatedSpdxElement": spdx_id,
            }
        )

    return {
        "spdxVersion": "SPDX-2.3",
        "dataLicense": "CC0-1.0",
        "SPDXID": "SPDXRef-DOCUMENT",
        "name": f"grain-client-sdk-source-{commit}",
        "documentNamespace": f"https://github.com/IvGolovach/grain-protocol/sdk-release/{commit}",
        "creationInfo": {
            "created": created_at,
            "creators": ["Tool: scripts/sdk/package_client_sdks.sh"],
        },
        "packages": packages,
        "relationships": relationships,
    }


def main() -> int:
    args = parse_args()
    out_dir = Path(args.out_dir).resolve()
    if not out_dir.is_dir():
        raise SystemExit(f"SDK_RELEASE_METADATA_ERR_OUT_DIR_MISSING: {out_dir}")

    created_at = dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    sdk_versions = load_sdk_versions()
    version_matrix = ROOT / "docs/human/sdk/version-matrix.md"

    artifacts: list[dict[str, object]] = []
    for artifact_path in sorted(out_dir.glob("*.tar.gz")):
        spec = classify_artifact(artifact_path.name, args.commit)
        artifacts.append(
            {
                "file": artifact_path.name,
                "kind": spec["kind"],
                "name": spec["name"],
                "sha256": sha256_file(artifact_path),
                "bytes": artifact_path.stat().st_size,
                "source_paths": spec["source_paths"],
            }
        )

    if len(artifacts) != len(ARTIFACT_KINDS):
        raise SystemExit(
            "SDK_RELEASE_METADATA_ERR_ARTIFACT_COUNT: "
            f"expected {len(ARTIFACT_KINDS)}, found {len(artifacts)}"
        )

    sbom = build_sbom(
        commit=args.commit,
        created_at=created_at,
        artifacts=artifacts,
        sdk_versions=sdk_versions,
    )
    sbom_path = out_dir / "sbom.spdx.json"
    sbom_path.write_text(json.dumps(sbom, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    sbom_sha = sha256_file(sbom_path)

    sums_entries = [(entry["sha256"], entry["file"]) for entry in artifacts]
    sums_entries.append((sbom_sha, sbom_path.name))
    sums_path = out_dir / "SHA256SUMS"
    sums_path.write_text(
        "".join(f"{checksum}  {file_name}\n" for checksum, file_name in sorted(sums_entries)),
        encoding="utf-8",
    )

    manifest = {
        "schema": "grain.sdk.release.manifest.v1",
        "commit": args.commit,
        "created_at": created_at,
        "dirty": args.dirty == "true",
        "verification": {
            "mode": args.verification_mode,
            "source": args.verification_source,
        },
        "workflow_contract": "client_workflow_v1",
        "artifact_policy": {
            "release_kind": "source-archive",
            "wasm_binary": "not_included_source_only",
            "platform_store_packages": "not_included",
            "registry_publication": "not_included",
        },
        "version_matrix": {
            "path": "docs/human/sdk/version-matrix.md",
            "sha256": sha256_file(version_matrix),
            "rule": "same-repo-sha",
        },
        "sdk_versions": sdk_versions,
        "sbom": {
            "file": sbom_path.name,
            "sha256": sbom_sha,
            "bytes": sbom_path.stat().st_size,
            "format": "SPDX-2.3 JSON",
        },
        "artifacts": artifacts,
    }
    (out_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    print("SDK release metadata: OK")
    print(f"manifest: {out_dir / 'manifest.json'}")
    print(f"sha256sums: {sums_path}")
    print(f"sbom: {sbom_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
