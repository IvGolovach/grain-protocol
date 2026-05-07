#!/usr/bin/env python3
"""Validate SDK registry dry-run metadata stays non-publishing."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

SCHEMA = "grain.sdk.registry_dry_run.v1"
COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")
SAFE_RELATIVE_RE = re.compile(r"^[A-Za-z0-9._/-]+$")
EXPECTED_CHANNELS = {
    "swiftpm": {
        "ecosystem": "swiftpm",
        "publication": {"none"},
        "command_tokens": {"swift", "package", "describe"},
    },
    "maven-local": {
        "ecosystem": "maven-local",
        "publication": {"local-dry-run"},
        "command_tokens": {"publishToMavenLocal", "--dry-run"},
    },
    "npm-pack": {
        "ecosystem": "npm-pack",
        "publication": {"pack-only"},
        "command_tokens": {"npm", "pack", "--dry-run"},
    },
}
ALLOWED_STATUS = {"pass", "unsupported_prereq", "unsupported_channel"}
FORBIDDEN_PUBLICATION_RE = re.compile(
    r"(npm[-\s]*publish|npm[-\s]*registry|maven[-\s]*central|sonatype|ossrh|github[-\s]*packages|"
    r"app[-\s]*store|app[-\s]*store[-\s]*connect|testflight|play[-\s]*console|play[-\s]*store|"
    r"store[-\s]*connect|registry[-\s]*publish|required[-\s]*credentials?|credentials?[-\s]*required|"
    r"external[-\s]*credentials?)",
    re.IGNORECASE,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--metadata", required=True)
    parser.add_argument("--expected-commit")
    return parser.parse_args()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def safe_relative_path(value: object, field: str) -> str:
    require(isinstance(value, str) and value, f"REGISTRY_DRY_RUN_ERR_{field}_MISSING")
    path = Path(value)
    require(
        not path.is_absolute() and ".." not in path.parts and SAFE_RELATIVE_RE.match(value) is not None,
        f"REGISTRY_DRY_RUN_ERR_{field}_PATH: {value}",
    )
    return value


def command_tokens(command: object) -> set[str]:
    require(isinstance(command, list) and command, "REGISTRY_DRY_RUN_ERR_COMMAND")
    tokens: set[str] = set()
    for token in command:
        require(isinstance(token, str) and token, "REGISTRY_DRY_RUN_ERR_COMMAND_TOKEN")
        tokens.add(token)
    return tokens


def reject_credential_claim(channel: dict[str, object]) -> None:
    require(channel.get("credentials") == "not_required", "REGISTRY_DRY_RUN_ERR_CREDENTIAL_CLAIM")
    if "external_credentials" in channel:
        require(
            channel.get("external_credentials") == "not_required",
            "REGISTRY_DRY_RUN_ERR_CREDENTIAL_CLAIM",
        )
    for key in ("credential_env", "credential_file", "token_env", "secret_env"):
        require(key not in channel, "REGISTRY_DRY_RUN_ERR_CREDENTIAL_CLAIM")


def reject_store_claim(value: object) -> None:
    require(value == "none", "REGISTRY_DRY_RUN_ERR_STORE_PUBLICATION_CLAIM")


def reject_top_level_publication_claims(metadata: dict[str, object]) -> None:
    for key in ("registry_publication", "package_registry_publication"):
        if key in metadata:
            value = metadata[key]
            require(
                value in (None, "none", "not_included"),
                f"REGISTRY_DRY_RUN_ERR_PUBLICATION_CLAIM: {key}",
            )
    for key in ("store_publication", "platform_store_publication"):
        if key in metadata:
            value = metadata[key]
            require(
                value in (None, "none", "not_included"),
                f"REGISTRY_DRY_RUN_ERR_STORE_PUBLICATION_CLAIM: {key}",
            )
    for key in ("external_credentials", "registry_credentials", "store_credentials"):
        if key in metadata:
            require(metadata[key] == "not_required", f"REGISTRY_DRY_RUN_ERR_CREDENTIAL_CLAIM: {key}")


def reject_forbidden_claims(value: object, context: str = "metadata") -> None:
    if isinstance(value, dict):
        for key, item in value.items():
            reject_forbidden_claims(item, f"{context}.{key}")
    elif isinstance(value, list):
        for index, item in enumerate(value):
            reject_forbidden_claims(item, f"{context}[{index}]")
    elif isinstance(value, str):
        require(
            FORBIDDEN_PUBLICATION_RE.search(value) is None,
            f"REGISTRY_DRY_RUN_ERR_FORBIDDEN_PUBLICATION_CLAIM: {context}",
        )


def validate_channel(channel: object) -> str:
    require(isinstance(channel, dict), "REGISTRY_DRY_RUN_ERR_CHANNEL_TYPE")
    name = channel.get("name")
    require(isinstance(name, str) and name in EXPECTED_CHANNELS, "REGISTRY_DRY_RUN_ERR_CHANNEL_NAME")
    expected = EXPECTED_CHANNELS[name]
    require(channel.get("ecosystem") == expected["ecosystem"], f"REGISTRY_DRY_RUN_ERR_ECOSYSTEM: {name}")
    require(channel.get("mode") == "dry-run-only", f"REGISTRY_DRY_RUN_ERR_MODE: {name}")
    reject_credential_claim(channel)
    reject_store_claim(channel.get("store_publication"))

    publication = channel.get("publication")
    require(
        isinstance(publication, str) and publication in expected["publication"],
        f"REGISTRY_DRY_RUN_ERR_PUBLICATION_CLAIM: {name}",
    )
    require(
        FORBIDDEN_PUBLICATION_RE.search(publication) is None,
        f"REGISTRY_DRY_RUN_ERR_PUBLICATION_CLAIM: {name}",
    )

    status = channel.get("status", "pass")
    require(isinstance(status, str) and status in ALLOWED_STATUS, f"REGISTRY_DRY_RUN_ERR_STATUS: {name}")
    safe_relative_path(channel.get("output"), "OUTPUT")
    tokens = command_tokens(channel.get("command"))
    missing = expected["command_tokens"] - tokens
    require(not missing, f"REGISTRY_DRY_RUN_ERR_COMMAND_POLICY: {name}:{','.join(sorted(missing))}")
    if status != "pass":
        reason = channel.get("reason")
        require(isinstance(reason, str) and reason, f"REGISTRY_DRY_RUN_ERR_REASON: {name}")
    return name


def validate_metadata(path: Path | str, expected_commit: str | None = None) -> dict[str, object]:
    metadata_path = Path(path)
    require(metadata_path.is_file(), f"REGISTRY_DRY_RUN_ERR_METADATA_MISSING: {metadata_path}")
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    require(isinstance(metadata, dict), "REGISTRY_DRY_RUN_ERR_METADATA_TYPE")
    require(metadata.get("schema") == SCHEMA, "REGISTRY_DRY_RUN_ERR_SCHEMA")
    commit = metadata.get("commit")
    require(isinstance(commit, str) and COMMIT_RE.match(commit) is not None, "REGISTRY_DRY_RUN_ERR_COMMIT")
    if expected_commit is not None:
        require(commit == expected_commit, "REGISTRY_DRY_RUN_ERR_COMMIT_MISMATCH")
    require(isinstance(metadata.get("dirty"), bool), "REGISTRY_DRY_RUN_ERR_DIRTY")
    require(metadata.get("credentials") == "not_required", "REGISTRY_DRY_RUN_ERR_CREDENTIAL_CLAIM")
    require(metadata.get("external_credentials") == "not_required", "REGISTRY_DRY_RUN_ERR_CREDENTIAL_CLAIM")
    require(
        metadata.get("publication_boundary") == "local-source-validation-only",
        "REGISTRY_DRY_RUN_ERR_PUBLICATION_BOUNDARY",
    )
    reject_top_level_publication_claims(metadata)

    channels = metadata.get("channels")
    require(isinstance(channels, list), "REGISTRY_DRY_RUN_ERR_CHANNELS")
    seen = {validate_channel(channel) for channel in channels}
    require(seen == set(EXPECTED_CHANNELS), "REGISTRY_DRY_RUN_ERR_CHANNEL_SET")
    reject_forbidden_claims(metadata)
    return metadata


def main() -> int:
    args = parse_args()
    metadata = validate_metadata(args.metadata, args.expected_commit)
    print(f"registry dry-run metadata: PASS ({len(metadata['channels'])} channels, commit {metadata['commit']})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
