#!/usr/bin/env python3
"""Validate the repo-native developer-product surface."""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
REQUIRED_SECURITY_IDS = {f"GRAIN-SEC-{idx:02d}" for idx in range(1, 10)}
REQUIRED_PROFILE_IDS = {"food-v0.1", "inventory-v0.1", "audit-artifact-v0.1"}
REQUIRED_INTEROP_LANES = {"rust-strict-full", "typescript-strict-full", "wasm-read-verify-subset"}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def load_json(relative: str) -> dict[str, Any]:
    path = ROOT / relative
    require(path.is_file(), f"REPO_NATIVE_PLATFORM_ERR_FILE_MISSING: {relative}")
    data = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(data, dict), f"REPO_NATIVE_PLATFORM_ERR_JSON_OBJECT: {relative}")
    return data


def vector_index() -> dict[str, Path]:
    out: dict[str, Path] = {}
    for path in (ROOT / "conformance/vectors").rglob("*.json"):
        data = json.loads(path.read_text(encoding="utf-8"))
        vector_id = data.get("vector_id")
        if isinstance(vector_id, str):
            out[vector_id] = path
    return out


def validate_demo_script() -> None:
    script = ROOT / "scripts/demo"
    require(script.is_file(), "REPO_NATIVE_PLATFORM_ERR_DEMO_SCRIPT_MISSING")
    require(os.access(script, os.X_OK), "REPO_NATIVE_PLATFORM_ERR_DEMO_SCRIPT_NOT_EXECUTABLE")
    quickstart = (ROOT / "docs/human/quickstart.md").read_text(encoding="utf-8")
    start_here = (ROOT / "docs/human/start-here.md").read_text(encoding="utf-8")
    require("./scripts/demo" in quickstart, "REPO_NATIVE_PLATFORM_ERR_QUICKSTART_DEMO_LINK")
    require("./scripts/demo" in start_here, "REPO_NATIVE_PLATFORM_ERR_START_HERE_DEMO_LINK")


def validate_external_consumer_fixture() -> None:
    fixture = ROOT / "fixtures/external-consumers/npm-sdk"
    for relative in ("package.json", "tsconfig.json", "src/import-smoke.ts", "src/runtime-smoke.mjs"):
        require((fixture / relative).is_file(), f"REPO_NATIVE_PLATFORM_ERR_EXTERNAL_NPM_FIXTURE: {relative}")
    text = (ROOT / "docs/human/sdk/source-sdk-handoff.md").read_text(encoding="utf-8")
    require("check_npm_release_dry_run.py" in text, "REPO_NATIVE_PLATFORM_ERR_NPM_DRY_RUN_DOC")


def validate_profile_registry() -> set[str]:
    registry = load_json("spec/profiles/profile-registry.v1.json")
    require(registry.get("schema") == "grain.profile-registry.v1", "REPO_NATIVE_PLATFORM_ERR_PROFILE_SCHEMA")
    profiles = registry.get("profiles")
    require(isinstance(profiles, list), "REPO_NATIVE_PLATFORM_ERR_PROFILE_LIST")
    seen: set[str] = set()

    for entry in profiles:
        require(isinstance(entry, dict), "REPO_NATIVE_PLATFORM_ERR_PROFILE_ENTRY")
        profile_id = entry.get("profile_id")
        require(isinstance(profile_id, str) and profile_id, "REPO_NATIVE_PLATFORM_ERR_PROFILE_ID")
        require(profile_id not in seen, f"REPO_NATIVE_PLATFORM_ERR_PROFILE_DUP: {profile_id}")
        seen.add(profile_id)
        for key in ("doc", "constraints"):
            value = entry.get(key)
            require(isinstance(value, str) and (ROOT / value).is_file(), f"REPO_NATIVE_PLATFORM_ERR_PROFILE_{key.upper()}: {profile_id}")
        constraints = json.loads((ROOT / str(entry["constraints"])).read_text(encoding="utf-8"))
        require(constraints.get("profile") == profile_id, f"REPO_NATIVE_PLATFORM_ERR_PROFILE_CONSTRAINT_ID: {profile_id}")
        for sample in entry.get("sample_fixtures", []):
            require(isinstance(sample, str) and (ROOT / sample).is_file(), f"REPO_NATIVE_PLATFORM_ERR_PROFILE_SAMPLE: {profile_id}")

    require(REQUIRED_PROFILE_IDS.issubset(seen), "REPO_NATIVE_PLATFORM_ERR_REQUIRED_PROFILES")
    return seen


def validate_reference_fixtures(profile_ids: set[str], vectors: dict[str, Path]) -> None:
    catalog = load_json("examples/reference-fixtures/catalog.v1.json")
    require(catalog.get("schema") == "grain.reference-fixtures.v1", "REPO_NATIVE_PLATFORM_ERR_FIXTURE_SCHEMA")
    fixtures = catalog.get("fixtures")
    require(isinstance(fixtures, list) and fixtures, "REPO_NATIVE_PLATFORM_ERR_FIXTURE_LIST")
    seen: set[str] = set()
    kinds: set[str] = set()

    for fixture in fixtures:
        require(isinstance(fixture, dict), "REPO_NATIVE_PLATFORM_ERR_FIXTURE_ENTRY")
        fixture_id = fixture.get("fixture_id")
        require(isinstance(fixture_id, str) and fixture_id, "REPO_NATIVE_PLATFORM_ERR_FIXTURE_ID")
        require(fixture_id not in seen, f"REPO_NATIVE_PLATFORM_ERR_FIXTURE_DUP: {fixture_id}")
        seen.add(fixture_id)
        kind = fixture.get("kind")
        require(kind in {"vector", "sample"}, f"REPO_NATIVE_PLATFORM_ERR_FIXTURE_KIND: {fixture_id}")
        kinds.add(str(kind))
        path_value = fixture.get("path")
        require(isinstance(path_value, str) and (ROOT / path_value).is_file(), f"REPO_NATIVE_PLATFORM_ERR_FIXTURE_PATH: {fixture_id}")
        if kind == "vector":
            vector_id = fixture.get("vector_id")
            require(isinstance(vector_id, str) and vector_id in vectors, f"REPO_NATIVE_PLATFORM_ERR_FIXTURE_VECTOR_ID: {fixture_id}")
            require(vectors[vector_id] == (ROOT / str(path_value)), f"REPO_NATIVE_PLATFORM_ERR_FIXTURE_VECTOR_PATH: {fixture_id}")
        else:
            profile_id = fixture.get("profile_id")
            require(isinstance(profile_id, str) and profile_id in profile_ids, f"REPO_NATIVE_PLATFORM_ERR_FIXTURE_PROFILE: {fixture_id}")
            sample = json.loads((ROOT / str(path_value)).read_text(encoding="utf-8"))
            require(sample.get("profile_id") == profile_id, f"REPO_NATIVE_PLATFORM_ERR_FIXTURE_SAMPLE_PROFILE: {fixture_id}")

    require(kinds == {"vector", "sample"}, "REPO_NATIVE_PLATFORM_ERR_FIXTURE_KIND_COVERAGE")


def validate_interop_matrix(vectors: dict[str, Path]) -> None:
    matrix = load_json("conformance/interop-matrix.v1.json")
    require(matrix.get("schema") == "grain.interop-matrix.v1", "REPO_NATIVE_PLATFORM_ERR_INTEROP_SCHEMA")
    lanes = matrix.get("lanes")
    require(isinstance(lanes, list) and lanes, "REPO_NATIVE_PLATFORM_ERR_INTEROP_LANES")
    lane_ids = {str(lane.get("lane_id")) for lane in lanes if isinstance(lane, dict)}
    require(REQUIRED_INTEROP_LANES.issubset(lane_ids), "REPO_NATIVE_PLATFORM_ERR_INTEROP_REQUIRED_LANES")

    for lane in lanes:
        require(isinstance(lane, dict), "REPO_NATIVE_PLATFORM_ERR_INTEROP_LANE")
        lane_id = str(lane.get("lane_id"))
        command = lane.get("command")
        require(isinstance(command, str) and command, f"REPO_NATIVE_PLATFORM_ERR_INTEROP_COMMAND: {lane_id}")
        vectors_ref = lane.get("vectors")
        require(isinstance(vectors_ref, str), f"REPO_NATIVE_PLATFORM_ERR_INTEROP_VECTOR_REF: {lane_id}")
        if vectors_ref.endswith(".json") and vectors_ref.startswith("runner/"):
            profile = json.loads((ROOT / vectors_ref).read_text(encoding="utf-8"))
            ids = profile.get("vector_ids", [])
            if ids:
                for vector_id in ids:
                    require(vector_id in vectors, f"REPO_NATIVE_PLATFORM_ERR_INTEROP_WASM_VECTOR: {vector_id}")

    gates = matrix.get("gates")
    require(isinstance(gates, list) and gates, "REPO_NATIVE_PLATFORM_ERR_INTEROP_GATES")
    for gate in gates:
        require(isinstance(gate, dict), "REPO_NATIVE_PLATFORM_ERR_INTEROP_GATE")
        for lane_id in gate.get("requires", []):
            require(lane_id in lane_ids, f"REPO_NATIVE_PLATFORM_ERR_INTEROP_GATE_LANE: {lane_id}")


def validate_security_regressions(vectors: dict[str, Path]) -> None:
    pack = load_json("conformance/security-regressions.v1.json")
    require(pack.get("schema") == "grain.security-regressions.v1", "REPO_NATIVE_PLATFORM_ERR_SECURITY_SCHEMA")
    findings = pack.get("findings")
    require(isinstance(findings, list), "REPO_NATIVE_PLATFORM_ERR_SECURITY_FINDINGS")
    ids = {str(item.get("id")) for item in findings if isinstance(item, dict)}
    require(ids == REQUIRED_SECURITY_IDS, "REPO_NATIVE_PLATFORM_ERR_SECURITY_ID_COVERAGE")

    for finding in findings:
        require(isinstance(finding, dict), "REPO_NATIVE_PLATFORM_ERR_SECURITY_FINDING")
        finding_id = str(finding["id"])
        evidence = finding.get("evidence")
        require(isinstance(evidence, list) and evidence, f"REPO_NATIVE_PLATFORM_ERR_SECURITY_EVIDENCE: {finding_id}")
        for item in evidence:
            require(isinstance(item, dict), f"REPO_NATIVE_PLATFORM_ERR_SECURITY_EVIDENCE_ITEM: {finding_id}")
            kind = item.get("kind")
            path_value = item.get("path")
            require(kind in {"vector", "path"}, f"REPO_NATIVE_PLATFORM_ERR_SECURITY_EVIDENCE_KIND: {finding_id}")
            require(isinstance(path_value, str) and (ROOT / path_value).is_file(), f"REPO_NATIVE_PLATFORM_ERR_SECURITY_EVIDENCE_PATH: {finding_id}")
            if kind == "vector":
                vector_id = item.get("id")
                require(isinstance(vector_id, str) and vector_id in vectors, f"REPO_NATIVE_PLATFORM_ERR_SECURITY_VECTOR: {finding_id}")
                require(vectors[vector_id] == (ROOT / str(path_value)), f"REPO_NATIVE_PLATFORM_ERR_SECURITY_VECTOR_PATH: {finding_id}")


def check_all() -> None:
    vectors = vector_index()
    validate_demo_script()
    validate_external_consumer_fixture()
    profile_ids = validate_profile_registry()
    validate_reference_fixtures(profile_ids, vectors)
    validate_interop_matrix(vectors)
    validate_security_regressions(vectors)


def main() -> int:
    check_all()
    print("repo-native developer platform: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
