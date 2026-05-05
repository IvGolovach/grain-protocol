#!/usr/bin/env python3
"""Validate client workflow fixture shape and local references."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
FIXTURE_DIR = ROOT / "sdk" / "workflows" / "fixtures" / "scan-preview"
REF_RE = re.compile(r"^conformance/vectors/[A-Za-z0-9_/-]+\.json#/[A-Za-z0-9_~./-]+$")
ALLOWED_STATUS = {"Verified", "Untrusted", "Rejected"}
ALLOWED_TOP_LEVEL = {"fixture_id", "workflow", "strict", "input", "expect", "meta"}
ALLOWED_INPUT = {"qr_string_ref", "trust_pub_b64_ref", "trust_pub_b64"}
ALLOWED_EXPECT = {"status", "diag", "diag_contains", "cose_b64", "store_mutation"}
REQUIRED_EXPECT = {"status", "cose_b64", "store_mutation"}


def load_json(path: Path) -> Any:
    try:
        with path.open(encoding="utf-8") as fh:
            return json.load(fh)
    except OSError as exc:
        fail(f"{path}: unable to read JSON: {exc}")
    except json.JSONDecodeError as exc:
        fail(f"{path}: invalid JSON: {exc}")


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def resolve_ref(ref: Any, fixture_path: Path) -> str:
    require(isinstance(ref, str), f"{fixture_path}: ref must be a string: {ref!r}")
    require(REF_RE.fullmatch(ref) is not None, f"{fixture_path}: invalid ref {ref!r}")
    file_part, pointer = ref.split("#/", 1)
    rel = Path(file_part)
    require(
        not rel.is_absolute() and ".." not in rel.parts,
        f"{fixture_path}: ref escapes repository root: {ref!r}",
    )

    vectors_root = (ROOT / "conformance" / "vectors").resolve()
    target = (ROOT / rel).resolve()
    require(
        target == vectors_root or vectors_root in target.parents,
        f"{fixture_path}: ref must stay under conformance/vectors: {ref!r}",
    )

    node = load_json(target)
    for raw_part in pointer.split("/"):
        part = raw_part.replace("~1", "/").replace("~0", "~")
        require(isinstance(node, dict) and part in node, f"{fixture_path}: missing {ref!r}")
        node = node[part]

    require(isinstance(node, str), f"{fixture_path}: ref must point to string: {ref!r}")
    return node


def require_string_list(value: Any, label: str, fixture_path: Path) -> None:
    require(isinstance(value, list), f"{fixture_path}: {label} must be a list")
    require(
        all(isinstance(item, str) for item in value),
        f"{fixture_path}: {label} must contain only strings",
    )


def validate_fixture(path: Path, seen_ids: set[str]) -> None:
    data = load_json(path)
    require(isinstance(data, dict), f"{path}: fixture must be a JSON object")
    missing_top_level = ALLOWED_TOP_LEVEL - set(data)
    extra_top_level = set(data) - ALLOWED_TOP_LEVEL
    require(
        not missing_top_level,
        f"{path}: missing top-level keys: {sorted(missing_top_level)}",
    )
    require(
        not extra_top_level,
        f"{path}: unexpected top-level keys: {sorted(extra_top_level)}",
    )
    require("vector_id" not in data and "op" not in data, f"{path}: protocol vector shape leaked")

    fixture_id = data["fixture_id"]
    require(isinstance(fixture_id, str), f"{path}: fixture_id must be a string")
    require(fixture_id not in seen_ids, f"{path}: duplicate fixture_id {fixture_id}")
    seen_ids.add(fixture_id)
    require(path.stem == fixture_id, f"{path}: filename must match fixture_id")

    require(data["workflow"] == "scan_preview", f"{path}: workflow must be scan_preview")
    require(data["strict"] is True, f"{path}: strict must be true")

    input_obj = data["input"]
    require(isinstance(input_obj, dict), f"{path}: input must be an object")
    require(set(input_obj).issubset(ALLOWED_INPUT), f"{path}: unexpected input keys")
    require("qr_string_ref" in input_obj, f"{path}: qr_string_ref is required")
    require(
        not ("trust_pub_b64_ref" in input_obj and "trust_pub_b64" in input_obj),
        f"{path}: trust_pub_b64_ref and trust_pub_b64 are mutually exclusive",
    )
    resolve_ref(input_obj["qr_string_ref"], path)
    if "trust_pub_b64_ref" in input_obj:
        resolve_ref(input_obj["trust_pub_b64_ref"], path)
    if "trust_pub_b64" in input_obj:
        require(isinstance(input_obj["trust_pub_b64"], str), f"{path}: trust_pub_b64 must be a string")

    expect = data["expect"]
    require(isinstance(expect, dict), f"{path}: expect must be an object")
    missing_expect = REQUIRED_EXPECT - set(expect)
    extra_expect = set(expect) - ALLOWED_EXPECT
    require(
        not missing_expect,
        f"{path}: missing expect keys: {sorted(missing_expect)}",
    )
    require(
        not extra_expect,
        f"{path}: unexpected expect keys: {sorted(extra_expect)}",
    )
    require(expect.get("status") in ALLOWED_STATUS, f"{path}: invalid status")
    require(expect.get("cose_b64") in {"present", "absent"}, f"{path}: invalid cose_b64")
    require(expect.get("store_mutation") == "none", f"{path}: store_mutation must be none")

    diag_keys = {"diag", "diag_contains"} & set(expect)
    require(len(diag_keys) == 1, f"{path}: expected exactly one diagnostic expectation")
    if "diag" in expect:
        require_string_list(expect["diag"], "diag", path)
    if "diag_contains" in expect:
        require_string_list(expect["diag_contains"], "diag_contains", path)
        require(
            len(expect["diag_contains"]) > 0,
            f"{path}: diag_contains must not be empty; use diag: [] to assert empty diagnostics",
        )

    meta = data["meta"]
    require(isinstance(meta, dict), f"{path}: meta must be an object")
    require(set(meta) == {"desc"}, f"{path}: meta must contain only desc")
    require(isinstance(meta["desc"], str) and meta["desc"], f"{path}: meta.desc must be a string")


def main() -> int:
    paths = sorted(FIXTURE_DIR.glob("*.json"))
    require(paths, "expected at least one scan-preview fixture")

    seen_ids: set[str] = set()
    for path in paths:
        validate_fixture(path, seen_ids)

    print(f"Client workflow fixture check: OK ({len(paths)} fixtures)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
