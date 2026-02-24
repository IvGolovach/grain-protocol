#!/usr/bin/env python3
"""Build interop-evidence.json and interop-report.md, enforcing certification gates."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(allow_abbrev=False)
    p.add_argument("--commit-sha", required=True)
    p.add_argument("--out-dir", required=True)
    p.add_argument("--suite-rust", required=True)
    p.add_argument("--suite-ts", required=True)
    p.add_argument("--div-c01", required=True)
    p.add_argument("--div-full", required=True)
    p.add_argument("--properties", required=True)
    p.add_argument("--invariants-audit", required=True)
    return p.parse_args()


def load_json(path: str) -> dict:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def main() -> int:
    args = parse_args()

    rust = load_json(args.suite_rust)
    ts = load_json(args.suite_ts)
    div_c01 = load_json(args.div_c01)
    div_full = load_json(args.div_full)
    props = load_json(args.properties)
    inv = load_json(args.invariants_audit)

    gates = {
        "rust_suite_pass": rust.get("failed", 1) == 0,
        "ts_suite_pass": ts.get("failed", 1) == 0,
        "divergence_c01_zero": div_c01.get("mismatches", 1) == 0,
        "divergence_full_zero": div_full.get("mismatches", 1) == 0,
        "property_tests_pass": props.get("failed", 1) == 0,
        "invariants_audit_pass": inv.get("status") == "PASS",
    }

    verdict = "PASS" if all(gates.values()) else "FAIL"

    evidence = {
        "commit_sha": args.commit_sha,
        "strict": True,
        "verdict": verdict,
        "gates": gates,
        "metrics": {
            "rust_suite": {
                "total": rust.get("total"),
                "passed": rust.get("passed"),
                "failed": rust.get("failed"),
            },
            "ts_suite": {
                "total": ts.get("total"),
                "passed": ts.get("passed"),
                "failed": ts.get("failed"),
            },
            "divergence_c01": {
                "total": div_c01.get("total"),
                "mismatches": div_c01.get("mismatches"),
            },
            "divergence_full": {
                "total": div_full.get("total"),
                "mismatches": div_full.get("mismatches"),
            },
            "properties": {
                "failed": props.get("failed"),
            },
            "invariants": {
                "status": inv.get("status"),
                "invariants_total": inv.get("invariants_total"),
                "partial_coverage_invariants": len(inv.get("partial_coverage_invariants", [])),
                "uncovered_invariants": len(inv.get("uncovered_invariants", [])),
            },
        },
    }

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    (out_dir / "interop-evidence.json").write_text(
        json.dumps(evidence, indent=2, ensure_ascii=True) + "\n",
        encoding="utf-8",
    )

    lines = [
        "# Interop Report",
        "",
        f"- Commit: `{args.commit_sha}`",
        f"- Verdict: **{verdict}**",
        "- Strict mode: true",
        "",
        "## Suite Summary",
        "",
        f"- Rust suite: {rust.get('passed')}/{rust.get('total')} passed",
        f"- TS suite: {ts.get('passed')}/{ts.get('total')} passed",
        f"- Divergence C01 mismatches: {div_c01.get('mismatches')}",
        f"- Divergence full mismatches: {div_full.get('mismatches')}",
        f"- Property test failures: {props.get('failed')}",
        "",
        "## Gate Status",
        "",
    ]

    for gate, ok in gates.items():
        lines.append(f"- {gate}: {'PASS' if ok else 'FAIL'}")

    lines.extend(
        [
            "",
            "## Notes",
            "",
            "- This certification covers Strict Conformance Mode only.",
            "- Diagnostics are compared by error codes; free-text messages are non-normative.",
        ]
    )

    (out_dir / "interop-report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"Interop summary: {verdict}")
    if verdict != "PASS":
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
