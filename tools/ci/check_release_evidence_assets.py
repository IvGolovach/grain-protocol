#!/usr/bin/env python3
"""Validate downloaded release-evidence assets for one commit/tag."""

from __future__ import annotations

import argparse
import json
import re
import sys
import zipfile
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import check_sdk_release_package

COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")
SHA_RE = re.compile(r"^[0-9a-f]{64}$")
REQUIRED_EVIDENCE_ENTRIES = {
    "evidence/suite-summary.json",
    "evidence/suite-run.json",
    "evidence/sdk-suite-summary.json",
    "evidence/evidence.sha256",
}
ZERO_FAILURE_FIELDS = [
    ("rust_full", "failed"),
    ("ts_c01", "failed"),
    ("divergence_c01", "mismatches"),
    ("ts_full", "failed"),
    ("ts_suite_runner", "failed"),
    ("divergence_full", "mismatches"),
    ("properties_full", "failed"),
    ("sdk_suite", "failed"),
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--release-dir", required=True)
    parser.add_argument("--expected-commit", required=True)
    parser.add_argument("--expected-tag")
    return parser.parse_args()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def safe_zip_name(name: str) -> bool:
    parts = Path(name).parts
    return bool(name) and not name.startswith("/") and ".." not in parts


def require_zero(summary: dict[str, object], section: str, key: str) -> None:
    value = summary.get(section)
    require(isinstance(value, dict), f"RELEASE_EVIDENCE_ERR_SUMMARY_SECTION: {section}")
    if section == "sdk_suite" and value.get(key) != 0:
        raise SystemExit(f"RELEASE_EVIDENCE_ERR_SDK_SUITE: {section}.{key}")
    require(value.get(key) == 0, f"RELEASE_EVIDENCE_ERR_SUITE_FAILURE: {section}.{key}")


def validate_embedded_sdk_summary(
    suite_summary: dict[str, object],
    sdk_summary: dict[str, object],
    *,
    expected_commit: str,
) -> None:
    embedded = suite_summary.get("sdk_suite")
    require(isinstance(embedded, dict), "RELEASE_EVIDENCE_ERR_SDK_SUITE_SUMMARY")
    require(sdk_summary.get("commit_sha") == expected_commit, "RELEASE_EVIDENCE_ERR_SDK_SUMMARY_COMMIT")
    require(sdk_summary.get("strict") is True, "RELEASE_EVIDENCE_ERR_SDK_SUMMARY_STRICT")
    for key in ("total", "passed", "failed"):
        require(
            embedded.get(key) == sdk_summary.get(key),
            f"RELEASE_EVIDENCE_ERR_SDK_SUITE_SUMMARY: {key}",
        )


def read_json_entry(archive: zipfile.ZipFile, entry: str) -> dict[str, object]:
    try:
        raw = archive.read(entry)
    except KeyError:
        raise SystemExit(f"RELEASE_EVIDENCE_ERR_ENTRY_MISSING: {entry}") from None
    try:
        data = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise SystemExit(f"RELEASE_EVIDENCE_ERR_JSON: {entry}") from exc
    require(isinstance(data, dict), f"RELEASE_EVIDENCE_ERR_JSON_OBJECT: {entry}")
    return data


def validate_evidence_zip(path: Path, *, expected_commit: str, expected_tag: str | None) -> None:
    require(path.is_file(), f"RELEASE_EVIDENCE_ERR_ZIP_MISSING: {path}")
    require(path.name == f"evidence-{expected_commit}.zip", "RELEASE_EVIDENCE_ERR_ZIP_NAME")

    seen: set[str] = set()
    with zipfile.ZipFile(path) as archive:
        for info in archive.infolist():
            require(info.filename not in seen, f"RELEASE_EVIDENCE_ERR_DUP_ENTRY: {info.filename}")
            seen.add(info.filename)
            require(safe_zip_name(info.filename), f"RELEASE_EVIDENCE_ERR_UNSAFE_ENTRY: {info.filename}")
            mode = (info.external_attr >> 16) & 0o170000
            require(mode != 0o120000, f"RELEASE_EVIDENCE_ERR_SYMLINK_ENTRY: {info.filename}")

        missing = sorted(REQUIRED_EVIDENCE_ENTRIES - seen)
        require(not missing, f"RELEASE_EVIDENCE_ERR_REQUIRED_ENTRIES: {', '.join(missing)}")

        suite_summary = read_json_entry(archive, "evidence/suite-summary.json")
        suite_run = read_json_entry(archive, "evidence/suite-run.json")
        sdk_summary = read_json_entry(archive, "evidence/sdk-suite-summary.json")
        evidence_sha = archive.read("evidence/evidence.sha256").decode("utf-8")

    require(suite_summary.get("commit_sha") == expected_commit, "RELEASE_EVIDENCE_ERR_SUMMARY_COMMIT")
    require(suite_summary.get("strict") is True, "RELEASE_EVIDENCE_ERR_SUMMARY_STRICT")
    if expected_tag is not None:
        require(suite_summary.get("tag") == expected_tag, "RELEASE_EVIDENCE_ERR_SUMMARY_TAG")

    require(suite_run.get("commit_sha") == expected_commit, "RELEASE_EVIDENCE_ERR_RUN_COMMIT")
    if expected_tag is not None:
        require(suite_run.get("tag") == expected_tag, "RELEASE_EVIDENCE_ERR_RUN_TAG")
    metadata = suite_run.get("metadata")
    require(isinstance(metadata, dict), "RELEASE_EVIDENCE_ERR_RUN_METADATA")
    require(metadata.get("workflow") == "release-evidence", "RELEASE_EVIDENCE_ERR_WORKFLOW")

    validate_embedded_sdk_summary(
        suite_summary,
        sdk_summary,
        expected_commit=expected_commit,
    )
    for section, key in ZERO_FAILURE_FIELDS:
        require_zero(suite_summary, section, key)

    first_line = evidence_sha.splitlines()[0] if evidence_sha.splitlines() else ""
    require(
        re.fullmatch(rf"evidence_sha256 {SHA_RE.pattern[1:-1]}", first_line) is not None,
        "RELEASE_EVIDENCE_ERR_SHA_HEADER",
    )
    require(" sdk-suite-summary.json" in evidence_sha, "RELEASE_EVIDENCE_ERR_SDK_SUITE_HASH_MISSING")


def validate_sdk_assets(release_dir: Path, expected_commit: str) -> None:
    args = argparse.Namespace(
        out_dir=str(release_dir),
        expected_commit=expected_commit,
        require_strict=True,
        require_clean=True,
    )
    check_sdk_release_package.validate_manifest(release_dir, args)


def main() -> int:
    args = parse_args()
    expected_commit = args.expected_commit
    require(COMMIT_RE.fullmatch(expected_commit) is not None, "RELEASE_EVIDENCE_ERR_COMMIT")
    release_dir = Path(args.release_dir).resolve()
    require(release_dir.is_dir(), f"RELEASE_EVIDENCE_ERR_RELEASE_DIR: {release_dir}")

    validate_sdk_assets(release_dir, expected_commit)
    validate_evidence_zip(
        release_dir / f"evidence-{expected_commit}.zip",
        expected_commit=expected_commit,
        expected_tag=args.expected_tag,
    )
    print(f"release evidence assets check: OK ({expected_commit})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
