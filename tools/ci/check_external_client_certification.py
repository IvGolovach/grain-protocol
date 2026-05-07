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
    "template_smoke",
    "no_secret_telemetry",
    "trust_governance",
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


def validate_report(path: Path) -> CertificationResult:
    report = load_json(path)
    require(
        report.get("schema") == "grain.external_client.certification.v1",
        "EXTERNAL_CLIENT_CERT_ERR_SCHEMA",
    )
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
