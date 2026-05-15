#!/usr/bin/env python3
"""Validate the local Food pilot proof report shape."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "grain.sdk.local_food_pilot.v1"
PROOF_SCHEMA = "grain.sdk.local_food_pilot_proof.v1"
HEX_SHA_RE = re.compile(r"^[0-9a-f]{40}$")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
ALLOWED_CHECK_STATUSES = {"pass", "fail"}
REQUIRED_CHECKS = {
    "food_profile",
    "sdk_build",
    "sdk_reduce",
    "reference_issuer",
    "reference_issuer_verify",
    "local_trust_bundle",
}
REQUIRED_ARTIFACTS = {
    "pilot_fixture": "food-local-pilot.valid.v1.json",
    "sdk_proof": "local-food-pilot-sdk-proof.json",
    "issuer_output": "issuer-output.json",
    "qr_string": "qr-string.txt",
    "trust_bundle": "local-trust-bundle.json",
    "logs": "logs",
}
REQUIRED_SAFE_REPORT = {
    "raw_qr_string",
    "raw_trust_material",
    "raw_snapshot_material",
    "raw_sync_material",
}
EXPECTED_REDUCER = {
    "sum_mean": {"kcal": 620},
    "sum_var": {"kcal": 9},
}
FORBIDDEN_FIELD_NAMES = {
    "qr_string",
    "qrString",
    "trust_pub_b64",
    "trustPubB64",
    "snapshot_b64",
    "snapshotB64",
    "bundle_b64",
    "bundleB64",
    "sync_bundle",
    "syncBundle",
    "identity_bundle",
    "identityBundle",
    "cose_b64",
    "coseB64",
    "trust_material",
    "trustMaterial",
}


def fail(message: str) -> None:
    raise SystemExit(message)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def require_object(value: Any, message: str) -> dict[str, Any]:
    require(isinstance(value, dict), message)
    return value


def require_string(value: Any, message: str) -> str:
    require(isinstance(value, str) and bool(value) and value.strip() == value, message)
    return value


def reject_forbidden_fields(value: Any, path: str = "$") -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            if key in FORBIDDEN_FIELD_NAMES and path != "$.artifacts":
                fail(f"SDK_LOCAL_FOOD_PILOT_REPORT_ERR_FORBIDDEN_FIELD: {path}.{key}")
            reject_forbidden_fields(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            reject_forbidden_fields(child, f"{path}[{index}]")


def validate_sdk_proof(report_path: Path, sdk_proof_path: str) -> None:
    proof_path = report_path.parent / sdk_proof_path
    try:
        proof = json.loads(proof_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        fail(f"SDK_LOCAL_FOOD_PILOT_REPORT_ERR_PROOF_JSON: {proof_path}: {exc}")
    require(isinstance(proof, dict), "SDK_LOCAL_FOOD_PILOT_REPORT_ERR_PROOF_OBJECT")
    require(proof.get("schema") == PROOF_SCHEMA, "SDK_LOCAL_FOOD_PILOT_REPORT_ERR_PROOF_SCHEMA")
    require(proof.get("fixture_id") == "food-local-pilot.valid.v1", "SDK_LOCAL_FOOD_PILOT_REPORT_ERR_PROOF_FIXTURE")
    require(proof.get("profile_id") == "food-v0.1", "SDK_LOCAL_FOOD_PILOT_REPORT_ERR_PROOF_PROFILE")
    require(proof.get("event_count") == 1, "SDK_LOCAL_FOOD_PILOT_REPORT_ERR_PROOF_EVENT_COUNT")
    require(proof.get("reducer_pass") is True, "SDK_LOCAL_FOOD_PILOT_REPORT_ERR_PROOF_REDUCER")
    require(proof.get("reducer_diag") == [], "SDK_LOCAL_FOOD_PILOT_REPORT_ERR_PROOF_REDUCER")
    require(proof.get("reducer_out") == EXPECTED_REDUCER, "SDK_LOCAL_FOOD_PILOT_REPORT_ERR_PROOF_REDUCER")
    proof_sha = require_string(proof.get("proof_sha256"), "SDK_LOCAL_FOOD_PILOT_REPORT_ERR_PROOF_SHA")
    require(SHA256_RE.fullmatch(proof_sha) is not None, "SDK_LOCAL_FOOD_PILOT_REPORT_ERR_PROOF_SHA")


def validate_report(path: Path, *, expected_commit: str | None = None, require_clean: bool = False) -> None:
    try:
        report = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        fail(f"SDK_LOCAL_FOOD_PILOT_REPORT_ERR_JSON: {path}: {exc}")
    require(isinstance(report, dict), f"SDK_LOCAL_FOOD_PILOT_REPORT_ERR_OBJECT: {path}")
    reject_forbidden_fields(report)

    require(report.get("schema") == SCHEMA, "SDK_LOCAL_FOOD_PILOT_REPORT_ERR_SCHEMA")
    commit = require_string(report.get("commit"), "SDK_LOCAL_FOOD_PILOT_REPORT_ERR_COMMIT")
    require(HEX_SHA_RE.fullmatch(commit) is not None, "SDK_LOCAL_FOOD_PILOT_REPORT_ERR_COMMIT")
    if expected_commit is not None:
        require(commit == expected_commit, "SDK_LOCAL_FOOD_PILOT_REPORT_ERR_COMMIT_MISMATCH")

    require(isinstance(report.get("dirty"), bool), "SDK_LOCAL_FOOD_PILOT_REPORT_ERR_DIRTY")
    if require_clean:
        require(report.get("dirty") is False, "SDK_LOCAL_FOOD_PILOT_REPORT_ERR_DIRTY")

    expected_boundaries = {
        "publication_boundary": "local-source-validation-only",
        "external_apps": "not_required",
        "external_devices": "not_required",
        "external_credentials": "not_required",
        "registry_publication": "not_included",
        "app_store_publication": "not_included",
        "play_console_publication": "not_included",
    }
    for field, expected in expected_boundaries.items():
        require(report.get(field) == expected, f"SDK_LOCAL_FOOD_PILOT_REPORT_ERR_BOUNDARY: {field}")

    flow = report.get("flow")
    require(isinstance(flow, list) and all(isinstance(item, str) for item in flow), "SDK_LOCAL_FOOD_PILOT_REPORT_ERR_FLOW")
    for required in REQUIRED_CHECKS:
        require(required in flow, f"SDK_LOCAL_FOOD_PILOT_REPORT_ERR_FLOW: {required}")

    artifacts = require_object(report.get("artifacts"), "SDK_LOCAL_FOOD_PILOT_REPORT_ERR_ARTIFACTS")
    require(set(artifacts) == set(REQUIRED_ARTIFACTS), "SDK_LOCAL_FOOD_PILOT_REPORT_ERR_ARTIFACTS")
    for name, value in artifacts.items():
        artifact_path = require_string(value, f"SDK_LOCAL_FOOD_PILOT_REPORT_ERR_ARTIFACT_PATH: {name}")
        require(artifact_path == REQUIRED_ARTIFACTS[name], f"SDK_LOCAL_FOOD_PILOT_REPORT_ERR_ARTIFACT_PATH: {name}")
        require(not artifact_path.startswith("/"), f"SDK_LOCAL_FOOD_PILOT_REPORT_ERR_ABSOLUTE_ARTIFACT: {name}")

    checks = require_object(report.get("checks"), "SDK_LOCAL_FOOD_PILOT_REPORT_ERR_CHECKS")
    require(REQUIRED_CHECKS.issubset(set(checks)), "SDK_LOCAL_FOOD_PILOT_REPORT_ERR_CHECKS")
    for name, raw_check in checks.items():
        check = require_object(raw_check, f"SDK_LOCAL_FOOD_PILOT_REPORT_ERR_CHECK_OBJECT: {name}")
        status = require_string(check.get("status"), f"SDK_LOCAL_FOOD_PILOT_REPORT_ERR_CHECK_STATUS: {name}")
        require(status in ALLOWED_CHECK_STATUSES, f"SDK_LOCAL_FOOD_PILOT_REPORT_ERR_CHECK_STATUS: {name}")
        require_string(check.get("command"), f"SDK_LOCAL_FOOD_PILOT_REPORT_ERR_CHECK_COMMAND: {name}")
        output = require_string(check.get("output"), f"SDK_LOCAL_FOOD_PILOT_REPORT_ERR_CHECK_OUTPUT: {name}")
        require(not output.startswith("/"), f"SDK_LOCAL_FOOD_PILOT_REPORT_ERR_ABSOLUTE_OUTPUT: {name}")
        if status != "pass":
            fail(f"SDK_LOCAL_FOOD_PILOT_REPORT_ERR_CHECK_STATUS: {name}")

    reducer = require_object(report.get("reducer"), "SDK_LOCAL_FOOD_PILOT_REPORT_ERR_REDUCER")
    require(reducer.get("expected") == EXPECTED_REDUCER, "SDK_LOCAL_FOOD_PILOT_REPORT_ERR_REDUCER")
    require(reducer.get("actual") == EXPECTED_REDUCER, "SDK_LOCAL_FOOD_PILOT_REPORT_ERR_REDUCER")

    safe_report = require_object(report.get("safe_report"), "SDK_LOCAL_FOOD_PILOT_REPORT_ERR_SAFE_REPORT")
    require(set(safe_report) == REQUIRED_SAFE_REPORT, "SDK_LOCAL_FOOD_PILOT_REPORT_ERR_SAFE_REPORT")
    for name, value in safe_report.items():
        require(value == "not_included", f"SDK_LOCAL_FOOD_PILOT_REPORT_ERR_SAFE_REPORT: {name}")

    residual_gaps = report.get("residual_gaps")
    require(isinstance(residual_gaps, list) and not residual_gaps, "SDK_LOCAL_FOOD_PILOT_REPORT_ERR_RESIDUAL_GAPS")
    validate_sdk_proof(path, str(artifacts["sdk_proof"]))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--report", required=True, help="Path to local-food-pilot.json")
    parser.add_argument("--expected-commit")
    parser.add_argument("--require-clean", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    validate_report(Path(args.report), expected_commit=args.expected_commit, require_clean=args.require_clean)
    print("local Food pilot report: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
