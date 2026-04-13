#!/usr/bin/env python3
"""Validate conformance vectors (schema + anti-placeholder + op shape)."""

import base64
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VECTORS_DIR = ROOT / "conformance" / "vectors"

REQUIRED_TOP = {"vector_id", "op", "strict", "input", "expect"}

REQUIRED_INPUT_BY_OP = {
    "dagcbor_validate": {"bytes_b64"},
    "cid_derive": {"bytes_b64"},
    "cose_verify": {"cose_b64", "pub_b64", "external_aad_b64"},
    "qr_decode_gr1": {"qr_string"},
    "e2e_decrypt": {"encrypted_object_b64", "sync_secret_b64", "cid_link_b64"},
    "e2e_derive_v1": {"sync_secret_b64", "cap_id_b64", "cid_link_bstr_b64"},
    "parse_cborseq_stream_v1": {"stream_kind"},
    "manifest_resolve": {"cid_b64", "eligible_records", "eligible_tombstones"},
    "ledger_reduce": {"root_kid", "events"},
}

PLACEHOLDER_TOKENS = ("placeholder", "illustrative", "next phase")
MAX_SAFE_INTEGER = 9007199254740991


def _is_b64_field(name: str) -> bool:
    return name.endswith("_b64") or name == "bytes_b64"


def _validate_b64(value: str) -> bool:
    try:
        base64.b64decode(value, validate=True)
        return True
    except Exception:
        return False


def _walk_strings(node):
    if isinstance(node, str):
        yield node
    elif isinstance(node, dict):
        for v in node.values():
            yield from _walk_strings(v)
    elif isinstance(node, list):
        for item in node:
            yield from _walk_strings(item)


def _collect_unsafe_expect_integers(node, path=""):
    out = []
    if isinstance(node, bool):
        return out
    if isinstance(node, int):
        if abs(node) > MAX_SAFE_INTEGER:
            out.append((path or "<root>", node))
        return out
    if isinstance(node, dict):
        for key, value in node.items():
            child_path = f"{path}.{key}" if path else key
            out.extend(_collect_unsafe_expect_integers(value, child_path))
        return out
    if isinstance(node, list):
        for idx, item in enumerate(node):
            out.extend(_collect_unsafe_expect_integers(item, f"{path}[{idx}]"))
    return out


def _collect_b64_fields(node, path=""):
    out = []
    if isinstance(node, dict):
        for k, v in node.items():
            child_path = f"{path}.{k}" if path else k
            if isinstance(v, str) and _is_b64_field(k):
                out.append((child_path, v))
            else:
                out.extend(_collect_b64_fields(v, child_path))
    elif isinstance(node, list):
        for i, item in enumerate(node):
            out.extend(_collect_b64_fields(item, f"{path}[{i}]"))
    return out


def _validate_manifest_record_shape(rec: dict) -> str | None:
    op = rec.get("op")
    if op not in {"put", "del"}:
        return "manifest record op must be 'put' or 'del'"
    has_cap = "cap_id_b64" in rec
    has_chash = "chash_b64" in rec
    if op == "put" and (not has_cap or not has_chash):
        return "manifest put record must include cap_id_b64 and chash_b64"
    if op == "del" and (has_cap or has_chash):
        return "manifest del record must not include cap_id_b64/chash_b64"
    return None


def _validate_ledger_event_shape(ev: dict) -> str | None:
    required = {"t", "ak", "seq", "payload_cid", "body"}
    missing = required - set(ev.keys())
    if missing:
        return f"ledger event missing keys: {sorted(missing)}"
    if not isinstance(ev["body"], dict):
        return "ledger event body must be object"
    t = ev["t"]
    body = ev["body"]
    if t == "DeviceKeyGrant" and "grant_ak" not in body:
        return "DeviceKeyGrant body must include grant_ak"
    if t == "DeviceKeyRevoke" and "revoke_ak" not in body:
        return "DeviceKeyRevoke body must include revoke_ak"
    if t == "IntakeEvent":
        if "mean" not in body or "var" not in body:
            return "IntakeEvent body must include mean and var"
    return None


def _looks_like_wa_id(vector_id: str) -> bool:
    parts = vector_id.split("-")
    if len(parts) != 4:
        return False
    head, area, wave, digits = parts[0], parts[1], parts[2], parts[3]
    if head not in {"POS", "NEG"}:
        return False
    if not area or not area.isalnum():
        return False
    if wave != "WA":
        return False
    if len(digits) != 4 or not digits.isdigit():
        return False
    return True


def main() -> int:
    bad = []
    known_ops = set(REQUIRED_INPUT_BY_OP.keys())

    for p in sorted(VECTORS_DIR.rglob("*.json")):
        obj = json.loads(p.read_text(encoding="utf-8"))
        rel = str(p.relative_to(ROOT))

        missing = REQUIRED_TOP - set(obj.keys())
        if missing:
            bad.append((rel, f"missing top-level keys: {sorted(missing)}"))
            continue

        if not isinstance(obj["vector_id"], str):
            bad.append((rel, "vector_id must be string"))

        expected_name = p.stem
        if obj["vector_id"] != expected_name:
            bad.append((rel, f"vector_id must match filename stem ({expected_name})"))

        if "-WA-" in obj["vector_id"] and not _looks_like_wa_id(obj["vector_id"]):
            bad.append((rel, "Wave-A vector_id must match POS/NEG-<AREA>-WA-####"))

        if obj["strict"] is not True:
            bad.append((rel, "strict must be true for v0.1 vectors"))

        op = obj["op"]
        if op not in known_ops:
            bad.append((rel, f"unknown op: {op}"))
            continue

        if not isinstance(obj["input"], dict):
            bad.append((rel, "input must be object"))
            continue

        required_input = REQUIRED_INPUT_BY_OP[op]
        missing_input = required_input - set(obj["input"].keys())
        if missing_input:
            bad.append((rel, f"missing op input keys: {sorted(missing_input)}"))

        # Ban placeholder/illustrative vectors.
        for s in _walk_strings(obj):
            low = s.lower()
            if any(tok in low for tok in PLACEHOLDER_TOKENS):
                bad.append((rel, f"contains forbidden placeholder token in string: {s!r}"))
                break

        # Validate base64 fields.
        for field_path, value in _collect_b64_fields(obj):
            if not _validate_b64(value):
                bad.append((rel, f"invalid base64 in field {field_path}"))

        for expect_key in ("out", "out_equals"):
            expect_value = obj.get("expect", {}).get(expect_key)
            if expect_value is None:
                continue
            for field_path, value in _collect_unsafe_expect_integers(expect_value, f"expect.{expect_key}"):
                bad.append(
                    (
                        rel,
                        f"{field_path} uses integer {value} outside the JSON safe range; encode unsafe output integers as decimal strings",
                    )
                )

        # Op-specific shape rules.
        if op == "manifest_resolve":
            for key in ("eligible_records", "eligible_tombstones"):
                if not isinstance(obj["input"].get(key), list):
                    bad.append((rel, f"{key} must be array"))
            for key in ("ineligible_records", "ineligible_tombstones"):
                if key in obj["input"] and not isinstance(obj["input"][key], list):
                    bad.append((rel, f"{key} must be array when present"))

            expect_pass = bool(obj.get("expect", {}).get("pass"))
            expected_diags = obj.get("expect", {}).get("diag_contains", [])
            allow_manifest_shape_negative = (not expect_pass) and ("GRAIN_ERR_MANIFEST_OP" in expected_diags)

            for bucket in ("eligible_records", "ineligible_records", "eligible_tombstones", "ineligible_tombstones"):
                records = obj["input"].get(bucket, [])
                for i, rec in enumerate(records):
                    if not isinstance(rec, dict):
                        bad.append((rel, f"{bucket}[{i}] must be object"))
                        continue
                    if allow_manifest_shape_negative:
                        continue
                    err = _validate_manifest_record_shape(rec)
                    if err:
                        bad.append((rel, f"{bucket}[{i}]: {err}"))

        if op == "parse_cborseq_stream_v1":
            expect_pass = bool(obj.get("expect", {}).get("pass"))
            expected_diags = obj.get("expect", {}).get("diag_contains", [])
            stream_kind = obj["input"].get("stream_kind")
            has_seq = "cborseq_b64" in obj["input"]
            has_segments = "segments_b64" in obj["input"]
            stream_kind_valid = stream_kind in {"ledger", "manifest"}
            xor_input_form_valid = has_seq != has_segments
            schema_shape_violation_count = int(not stream_kind_valid) + int(not xor_input_form_valid)
            allow_single_schema_shape_negative = (
                (not expect_pass)
                and ("GRAIN_ERR_SCHEMA" in expected_diags)
                and schema_shape_violation_count == 1
            )

            if (not allow_single_schema_shape_negative) and not stream_kind_valid:
                bad.append((rel, "stream_kind must be 'ledger' or 'manifest'"))
            if (not allow_single_schema_shape_negative) and not xor_input_form_valid:
                bad.append((rel, "parse_cborseq_stream_v1 requires exactly one of cborseq_b64 or segments_b64"))
            if has_segments:
                segments = obj["input"].get("segments_b64")
                if not isinstance(segments, list):
                    bad.append((rel, "segments_b64 must be array"))
                else:
                    for i, seg in enumerate(segments):
                        if not isinstance(seg, str):
                            bad.append((rel, f"segments_b64[{i}] must be string"))

        if op == "ledger_reduce":
            if not isinstance(obj["input"].get("events"), list):
                bad.append((rel, "events must be array"))
            else:
                for i, ev in enumerate(obj["input"]["events"]):
                    if not isinstance(ev, dict):
                        bad.append((rel, f"events[{i}] must be object"))
                        continue
                    err = _validate_ledger_event_shape(ev)
                    if err:
                        bad.append((rel, f"events[{i}]: {err}"))

    if bad:
        for f, err in bad:
            print(f"[BAD] {f}: {err}")
        raise SystemExit(1)

    print("Vectors schema: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
