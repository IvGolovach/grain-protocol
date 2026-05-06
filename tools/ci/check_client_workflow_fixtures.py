#!/usr/bin/env python3
"""Validate client workflow fixture shape and local references."""

from __future__ import annotations

import json
import re
import sys
from base64 import b64decode
from binascii import Error as Base64Error
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
FIXTURE_ROOT = ROOT / "sdk" / "workflows" / "fixtures"
REF_RE = re.compile(r"^conformance/vectors/[A-Za-z0-9_/-]+\.json#/[A-Za-z0-9_~./-]+$")
TRUST_BUNDLE_REF_RE = re.compile(r"^sdk/trust/fixtures/[A-Za-z0-9_-]+\.json$")
ALLOWED_WORKFLOW = {
    "scan_preview",
    "scan_accept",
    "scan_handoff",
    "device_lifecycle",
    "pairing",
    "sync_bundle",
    "store_snapshot",
}
ALLOWED_STATUS = {
    "Verified",
    "Untrusted",
    "Accepted",
    "AlreadyAccepted",
    "Created",
    "Valid",
    "Paired",
    "AlreadyPaired",
    "Ready",
    "Uninitialized",
    "Exported",
    "Restored",
    "Empty",
    "Imported",
    "AlreadyImported",
    "Rejected",
}
SCAN_PREVIEW_STATUS = {"Verified", "Untrusted", "Rejected"}
SCAN_ACCEPT_STATUS = {"Accepted", "AlreadyAccepted", "Rejected"}
SCAN_HANDOFF_STATUS = {"Accepted", "AlreadyAccepted", "Rejected"}
DEVICE_LIFECYCLE_STATUS = {"Ready", "Uninitialized"}
PAIRING_STATUS = {"Paired", "AlreadyPaired", "Rejected"}
SYNC_BUNDLE_STATUS = {"Imported", "AlreadyImported", "Rejected"}
STORE_SNAPSHOT_STATUS = {"Exported", "Restored", "Empty", "Rejected"}
ALLOWED_TOP_LEVEL = {"fixture_id", "workflow", "strict", "input", "expect", "meta"}
ALLOWED_INPUT = {
    "qr_string_ref",
    "trust_pub_b64_ref",
    "trust_pub_b64",
    "trust_anchor_id",
    "trust_anchor_bundle_ref",
    "accept_attempts",
    "import_attempts",
    "root_label",
    "device_label",
    "handoff_source",
}
ALLOWED_EXPECT = {
    "status",
    "diag",
    "diag_contains",
    "cose_b64",
    "store_mutation",
    "accepted_record_count",
    "device_count",
    "revoked_count",
    "lifecycle_event_count",
    "root_kid",
    "active_ak",
    "device_ak",
    "pairing_id",
    "envelope_b64",
    "bundle_b64",
    "snapshot_b64",
    "handoff_source",
}
ALLOWED_HANDOFF_SOURCE = {
    "manual_entry",
    "camera",
    "injected",
    "share_sheet",
    "deep_link",
    "clipboard",
    "robot_vision",
    "external_sensor",
    "unknown",
}
REQUIRED_EXPECT = {"status"}
PRESENCE_FIELDS = {
    "root_kid",
    "active_ak",
    "device_ak",
    "pairing_id",
    "envelope_b64",
    "bundle_b64",
    "snapshot_b64",
}
COUNT_FIELDS = {"accepted_record_count", "device_count", "revoked_count", "lifecycle_event_count"}


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


def resolve_trust_anchor_bundle_ref(ref: Any, fixture_path: Path) -> dict[str, str]:
    require(isinstance(ref, str), f"{fixture_path}: trust_anchor_bundle_ref must be a string")
    require(
        TRUST_BUNDLE_REF_RE.fullmatch(ref) is not None,
        f"{fixture_path}: invalid trust_anchor_bundle_ref {ref!r}",
    )
    rel = Path(ref)
    require(
        not rel.is_absolute() and ".." not in rel.parts,
        f"{fixture_path}: trust_anchor_bundle_ref escapes repository root: {ref!r}",
    )

    bundle_root = (ROOT / "sdk" / "trust" / "fixtures").resolve()
    target = (ROOT / rel).resolve()
    require(
        target == bundle_root or bundle_root in target.parents,
        f"{fixture_path}: trust_anchor_bundle_ref must stay under sdk/trust/fixtures: {ref!r}",
    )

    bundle = load_json(target)
    require(isinstance(bundle, dict), f"{fixture_path}: trust anchor bundle must be an object")
    require(
        set(bundle) == {"bundle_v", "anchors"},
        f"{fixture_path}: trust anchor bundle keys must be bundle_v and anchors",
    )
    require(bundle["bundle_v"] == 1, f"{fixture_path}: trust anchor bundle_v must be 1")
    anchors = bundle["anchors"]
    require(
        isinstance(anchors, list) and anchors,
        f"{fixture_path}: trust anchor bundle anchors must be a non-empty list",
    )

    seen: set[str] = set()
    for anchor in anchors:
        require(isinstance(anchor, dict), f"{fixture_path}: trust anchor must be an object")
        require(
            set(anchor) == {"id", "trust_pub_b64"},
            f"{fixture_path}: trust anchor keys must be id and trust_pub_b64",
        )
        anchor_id = anchor["id"]
        trust_pub_b64 = anchor["trust_pub_b64"]
        require(
            isinstance(anchor_id, str) and anchor_id and anchor_id.strip() == anchor_id,
            f"{fixture_path}: trust anchor id must be non-blank without edge whitespace",
        )
        require(anchor_id not in seen, f"{fixture_path}: duplicate trust anchor id {anchor_id}")
        seen.add(anchor_id)
        require(
            isinstance(trust_pub_b64, str) and trust_pub_b64,
            f"{fixture_path}: trust_pub_b64 must be a non-empty string",
        )
        try:
            decoded = b64decode(trust_pub_b64, validate=True)
        except (Base64Error, ValueError):
            fail(f"{fixture_path}: trust_pub_b64 must be standard base64")
        require(decoded, f"{fixture_path}: trust_pub_b64 must decode to non-empty bytes")

    return {anchor["id"]: anchor["trust_pub_b64"] for anchor in anchors}


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

    workflow = data["workflow"]
    require(workflow in ALLOWED_WORKFLOW, f"{path}: invalid workflow")
    require(data["strict"] is True, f"{path}: strict must be true")

    input_obj = data["input"]
    require(isinstance(input_obj, dict), f"{path}: input must be an object")
    require(set(input_obj).issubset(ALLOWED_INPUT), f"{path}: unexpected input keys")
    require(
        not ("trust_pub_b64_ref" in input_obj and "trust_pub_b64" in input_obj),
        f"{path}: trust_pub_b64_ref and trust_pub_b64 are mutually exclusive",
    )
    for direct_trust_key in ("trust_pub_b64_ref", "trust_pub_b64"):
        require(
            not ("trust_anchor_bundle_ref" in input_obj and direct_trust_key in input_obj),
            f"{path}: trust_anchor_bundle_ref and {direct_trust_key} are mutually exclusive",
        )
    if workflow in {"scan_preview", "scan_accept", "sync_bundle", "store_snapshot"}:
        require("qr_string_ref" in input_obj, f"{path}: qr_string_ref is required")
    if "qr_string_ref" in input_obj:
        resolve_ref(input_obj["qr_string_ref"], path)
    if "trust_pub_b64_ref" in input_obj:
        resolve_ref(input_obj["trust_pub_b64_ref"], path)
    if "trust_pub_b64" in input_obj:
        require(
            isinstance(input_obj["trust_pub_b64"], str),
            f"{path}: trust_pub_b64 must be a string",
        )
    if "trust_anchor_id" in input_obj:
        require(
            isinstance(input_obj["trust_anchor_id"], str),
            f"{path}: trust_anchor_id must be a string",
        )
    if "trust_anchor_bundle_ref" in input_obj:
        require(
            "trust_anchor_id" in input_obj,
            f"{path}: trust_anchor_bundle_ref requires trust_anchor_id",
        )
        resolve_trust_anchor_bundle_ref(input_obj["trust_anchor_bundle_ref"], path)
    accept_attempts = input_obj.get("accept_attempts", 1)
    if "accept_attempts" in input_obj:
        require(
            isinstance(accept_attempts, int)
            and not isinstance(accept_attempts, bool)
            and accept_attempts >= 1,
            f"{path}: accept_attempts must be a positive integer",
        )
    import_attempts = input_obj.get("import_attempts", 1)
    if "import_attempts" in input_obj:
        require(
            isinstance(import_attempts, int)
            and not isinstance(import_attempts, bool)
            and import_attempts >= 1,
            f"{path}: import_attempts must be a positive integer",
        )
    for label in ("root_label", "device_label"):
        if label in input_obj:
            require(isinstance(input_obj[label], str), f"{path}: {label} must be a string")
    if "handoff_source" in input_obj:
        require(
            input_obj["handoff_source"] in ALLOWED_HANDOFF_SOURCE,
            f"{path}: invalid handoff_source",
        )

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
    status = expect.get("status")
    require(status in ALLOWED_STATUS, f"{path}: invalid status")
    if workflow == "scan_preview":
        require(status in SCAN_PREVIEW_STATUS, f"{path}: invalid scan_preview status")
    if workflow == "scan_accept":
        require(status in SCAN_ACCEPT_STATUS, f"{path}: invalid scan_accept status")
    if workflow == "scan_handoff":
        require(status in SCAN_HANDOFF_STATUS, f"{path}: invalid scan_handoff status")
    if workflow == "device_lifecycle":
        require(status in DEVICE_LIFECYCLE_STATUS, f"{path}: invalid device_lifecycle status")
    if workflow == "pairing":
        require(status in PAIRING_STATUS, f"{path}: invalid pairing status")
    if workflow == "sync_bundle":
        require(status in SYNC_BUNDLE_STATUS, f"{path}: invalid sync_bundle status")
    if workflow == "store_snapshot":
        require(status in STORE_SNAPSHOT_STATUS, f"{path}: invalid store_snapshot status")

    if "cose_b64" in expect:
        require(expect.get("cose_b64") in {"present", "absent"}, f"{path}: invalid cose_b64")
    store_mutation = expect.get("store_mutation")
    if "store_mutation" in expect:
        require(
            store_mutation in {"none", "accepted_scan_inserted"},
            f"{path}: invalid store_mutation",
        )
    for field in PRESENCE_FIELDS & set(expect):
        require(expect[field] in {"present", "absent"}, f"{path}: invalid {field}")
    for field in COUNT_FIELDS & set(expect):
        require(
            isinstance(expect[field], int)
            and not isinstance(expect[field], bool)
            and expect[field] >= 0,
            f"{path}: {field} must be a non-negative integer",
        )

    if workflow == "scan_preview":
        require({"cose_b64", "store_mutation"}.issubset(expect), f"{path}: scan_preview missing scan expectations")
        require(
            "accept_attempts" not in input_obj,
            f"{path}: scan_preview must not set accept_attempts",
        )
        require(store_mutation == "none", f"{path}: scan_preview store_mutation must be none")
        require(
            "accepted_record_count" not in expect,
            f"{path}: scan_preview must not assert accepted_record_count",
        )
    if workflow == "scan_accept":
        require({"cose_b64", "store_mutation", "accepted_record_count"}.issubset(expect), f"{path}: scan_accept missing scan expectations")
        require(
            "accepted_record_count" in expect,
            f"{path}: scan_accept must assert accepted_record_count",
        )
        if status == "Accepted":
            require(
                accept_attempts == 1,
                f"{path}: Accepted fixture must use exactly one accept attempt",
            )
            require(
                store_mutation == "accepted_scan_inserted",
                f"{path}: accepted scan must insert a record",
            )
        if status == "AlreadyAccepted":
            require(
                accept_attempts >= 2,
                f"{path}: AlreadyAccepted fixture must repeat scan_accept",
            )
            require(
                store_mutation == "accepted_scan_inserted"
                and expect["accepted_record_count"] == 1,
                f"{path}: AlreadyAccepted fixture must leave exactly one inserted record",
            )
        if status == "Rejected":
            require(
                store_mutation == "none" and expect["accepted_record_count"] == 0,
                f"{path}: rejected scan_accept must not persist records",
            )
    if workflow == "scan_handoff":
        require(
            {"cose_b64", "store_mutation", "accepted_record_count", "handoff_source"}.issubset(expect),
            f"{path}: scan_handoff missing handoff expectations",
        )
        require(
            "trust_anchor_bundle_ref" in input_obj and "trust_anchor_id" in input_obj,
            f"{path}: scan_handoff must use explicit trust anchor bundle and ID",
        )
        require(
            expect["handoff_source"] in ALLOWED_HANDOFF_SOURCE,
            f"{path}: invalid expected handoff_source",
        )
        require(
            input_obj.get("handoff_source", "manual_entry") == expect["handoff_source"],
            f"{path}: handoff source expectation must match input",
        )
        if status == "Rejected":
            require(
                store_mutation == "none" and expect["accepted_record_count"] == 0,
                f"{path}: rejected scan_handoff must not persist records",
            )
        else:
            require(
                store_mutation == "accepted_scan_inserted"
                and expect["accepted_record_count"] == 1,
                f"{path}: accepted scan_handoff must leave exactly one record",
            )
    if workflow == "device_lifecycle":
        require(
            "qr_string_ref" not in input_obj
            and "trust_pub_b64_ref" not in input_obj
            and "trust_pub_b64" not in input_obj
            and "trust_anchor_id" not in input_obj,
            f"{path}: device_lifecycle must not set scan input",
        )
        require(
            {"root_kid", "active_ak", "device_ak", "device_count", "revoked_count", "accepted_record_count", "lifecycle_event_count"}.issubset(expect),
            f"{path}: device_lifecycle missing lifecycle expectations",
        )
        require(
            "cose_b64" not in expect and "store_mutation" not in expect,
            f"{path}: device_lifecycle must not set scan expectations",
        )
    if workflow == "pairing":
        require(
            "qr_string_ref" not in input_obj
            and "trust_pub_b64_ref" not in input_obj
            and "trust_pub_b64" not in input_obj
            and "trust_anchor_id" not in input_obj,
            f"{path}: pairing must not set scan input",
        )
        require(
            {"root_kid", "pairing_id", "envelope_b64", "device_count"}.issubset(expect),
            f"{path}: pairing missing pairing expectations",
        )
        require(
            accept_attempts >= 1,
            f"{path}: pairing accept_attempts must be positive",
        )
        if status == "AlreadyPaired":
            require(accept_attempts >= 2, f"{path}: AlreadyPaired fixture must repeat accept")
    if workflow == "sync_bundle":
        require(
            "trust_pub_b64_ref" in input_obj or "trust_pub_b64" in input_obj,
            f"{path}: sync_bundle requires trust material",
        )
        require(
            "trust_anchor_bundle_ref" not in input_obj,
            f"{path}: sync_bundle must use direct trust material",
        )
        require(
            {"bundle_b64", "accepted_record_count", "device_count", "lifecycle_event_count"}.issubset(expect),
            f"{path}: sync_bundle missing sync expectations",
        )
        if status == "AlreadyImported":
            require(import_attempts >= 2, f"{path}: AlreadyImported fixture must repeat import")
    if workflow == "store_snapshot":
        require(
            "trust_pub_b64_ref" in input_obj or "trust_pub_b64" in input_obj,
            f"{path}: store_snapshot requires trust material",
        )
        require(
            "trust_anchor_bundle_ref" not in input_obj,
            f"{path}: store_snapshot must use direct trust material",
        )
        require(
            {"snapshot_b64", "accepted_record_count", "device_count", "lifecycle_event_count"}.issubset(expect),
            f"{path}: store_snapshot missing snapshot expectations",
        )
        require(
            "cose_b64" not in expect and "store_mutation" not in expect,
            f"{path}: store_snapshot must not set scan expectations",
        )

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
    paths = sorted(FIXTURE_ROOT.glob("*/*.json"))
    require(paths, "expected at least one client workflow fixture")

    seen_ids: set[str] = set()
    seen_workflows: set[str] = set()
    for path in paths:
        validate_fixture(path, seen_ids)
        seen_workflows.add(load_json(path)["workflow"])

    missing_workflows = ALLOWED_WORKFLOW - seen_workflows
    require(
        not missing_workflows,
        f"missing fixture coverage for workflows: {sorted(missing_workflows)}",
    )

    print(f"Client workflow fixture check: OK ({len(paths)} fixtures)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
