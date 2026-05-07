#!/usr/bin/env python3
"""Validate third-party Grain client certification reports."""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")
REQUIRED_CHECKS = (
    "workflow_fixtures",
    "no_network",
    "trust_provider",
    "secret_logging",
    "api_compatibility",
    "starter_templates",
    "ios_reference_app",
    "android_reference_app",
    "device_contract",
    "no_secret_telemetry",
    "trust_governance",
    "registry_dry_runs",
    "sdk_release_package",
    "release_consumer",
)
FORBIDDEN_PUBLICATION_RE = re.compile(
    r"(app[-\s]*store|testflight|play[-\s]*console|play[-\s]*store|npm[-\s]*publish|"
    r"maven[-\s]*central|sonatype|ossrh|required[-\s]*credentials?|credentials?[-\s]*required|"
    r"external[-\s]*credentials?)",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class CertificationResult:
    client_name: str
    grain_commit: str
    summary: str


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def load_json(path: Path) -> dict[str, Any]:
    require(path.is_file(), f"EXTERNAL_CLIENT_CERT_ERR_MISSING_REPORT: {path}")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"EXTERNAL_CLIENT_CERT_ERR_INVALID_JSON: {path}: {exc}") from exc
    require(isinstance(data, dict), "EXTERNAL_CLIENT_CERT_ERR_REPORT_OBJECT")
    return data


def reject_forbidden_claims(value: Any, context: str = "report") -> None:
    if isinstance(value, dict):
        for key, item in value.items():
            reject_forbidden_claims(item, f"{context}.{key}")
    elif isinstance(value, list):
        for index, item in enumerate(value):
            reject_forbidden_claims(item, f"{context}[{index}]")
    elif isinstance(value, str):
        require(
            FORBIDDEN_PUBLICATION_RE.search(value) is None,
            f"EXTERNAL_CLIENT_CERT_ERR_PUBLICATION_CLAIM: {context}",
        )


def validate_scope(report: dict[str, Any]) -> None:
    scope = report.get("certification_scope")
    require(isinstance(scope, dict), "EXTERNAL_CLIENT_CERT_ERR_SCOPE")
    require(scope.get("mode") == "local-source-validation", "EXTERNAL_CLIENT_CERT_ERR_SCOPE_MODE")
    require(
        scope.get("publication_boundary") == "source-validation-only",
        "EXTERNAL_CLIENT_CERT_ERR_PUBLICATION_BOUNDARY",
    )
    for key in (
        "registry_publication",
        "app_store_publication",
        "play_console_publication",
        "npm_publication",
        "maven_central_publication",
    ):
        require(scope.get(key) == "not_included", f"EXTERNAL_CLIENT_CERT_ERR_PUBLICATION_CLAIM: {key}")
    require(scope.get("external_credentials") == "not_required", "EXTERNAL_CLIENT_CERT_ERR_CREDENTIAL_CLAIM")
    require(scope.get("paid_developer_accounts") == "not_required", "EXTERNAL_CLIENT_CERT_ERR_CREDENTIAL_CLAIM")


def validate_report(path: Path) -> CertificationResult:
    report = load_json(path)
    require(
        report.get("schema") == "grain.external_client.certification.v1",
        "EXTERNAL_CLIENT_CERT_ERR_SCHEMA",
    )
    validate_scope(report)
    reject_forbidden_claims(report)
    client = report.get("client")
    require(isinstance(client, dict), "EXTERNAL_CLIENT_CERT_ERR_CLIENT")
    client_name = client.get("name")
    grain_commit = client.get("grain_commit")
    require(isinstance(client_name, str) and client_name.strip(), "EXTERNAL_CLIENT_CERT_ERR_CLIENT_NAME")
    require(
        isinstance(grain_commit, str) and COMMIT_RE.fullmatch(grain_commit) is not None,
        "EXTERNAL_CLIENT_CERT_ERR_COMMIT",
    )

    checks = report.get("checks")
    require(isinstance(checks, dict), "EXTERNAL_CLIENT_CERT_ERR_CHECKS")
    missing = [name for name in REQUIRED_CHECKS if name not in checks]
    require(
        not missing,
        "EXTERNAL_CLIENT_CERT_ERR_MISSING_CHECK: " + ", ".join(missing),
    )
    for name in REQUIRED_CHECKS:
        check = checks[name]
        require(isinstance(check, dict), f"EXTERNAL_CLIENT_CERT_ERR_CHECK_OBJECT: {name}")
        require(
            check.get("status") == "pass",
            f"EXTERNAL_CLIENT_CERT_ERR_CHECK_NOT_PASS: {name}",
        )
        command = check.get("command")
        require(
            isinstance(command, str) and command.strip(),
            f"EXTERNAL_CLIENT_CERT_ERR_CHECK_COMMAND: {name}",
        )
        output = check.get("output")
        require(isinstance(output, str) and output.strip(), f"EXTERNAL_CLIENT_CERT_ERR_CHECK_OUTPUT: {name}")

    artifacts = report.get("artifacts")
    require(isinstance(artifacts, dict), "EXTERNAL_CLIENT_CERT_ERR_ARTIFACTS")
    source_handoff = artifacts.get("source_handoff")
    require(
        isinstance(source_handoff, str) and source_handoff.strip(),
        "EXTERNAL_CLIENT_CERT_ERR_SOURCE_HANDOFF",
    )

    gaps = report.get("residual_gaps")
    require(isinstance(gaps, list), "EXTERNAL_CLIENT_CERT_ERR_RESIDUAL_GAPS")
    require(
        all(isinstance(item, str) for item in gaps),
        "EXTERNAL_CLIENT_CERT_ERR_RESIDUAL_GAPS",
    )
    summary = f"{client_name}: {len(REQUIRED_CHECKS)} checks passed for {grain_commit}"
    if gaps:
        summary += f"; residual gaps: {len(gaps)}"
    return CertificationResult(client_name=client_name, grain_commit=grain_commit, summary=summary)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--report", required=True, help="Certification report JSON path")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    result = validate_report((ROOT / args.report).resolve() if not Path(args.report).is_absolute() else Path(args.report))
    print(result.summary)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
