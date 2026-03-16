#!/usr/bin/env python3
"""TOR-RC-STAB-A01 stabilization runner (smoke/deep)."""

from __future__ import annotations

import argparse
import base64
import copy
import hashlib
import json
import os
import random
import shutil
import stat
import subprocess
import tempfile
import textwrap
import time
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_BASELINE_TAG = "repo-rc-v0.4.0-rc1"
DEFAULT_BASELINE_EVIDENCE_SHA = "35475fd1767ec873a4bfa46c51ffffd23843831e21df5c17db0e5d2162b3a1bd"

ATTACK_CASES: list[dict[str, Any]] = [
    {
        "id": "AM-001",
        "name": "GR1 replay yields deterministic decode",
        "kind": "replay",
        "vector": "conformance/vectors/qr/POS-QR-001.json",
        "replays": 3,
    },
    {
        "id": "AM-002",
        "name": "COSE tag18 injection rejected",
        "kind": "vector",
        "vector": "conformance/vectors/cose/NEG-COSE-010.json",
    },
    {
        "id": "AM-003",
        "name": "COSE profile header anomaly rejected",
        "kind": "vector",
        "vector": "conformance/vectors/cose/NEG-COSE-001.json",
    },
    {
        "id": "AM-004",
        "name": "CBOR-seq garbage tail rejected",
        "kind": "vector",
        "vector": "conformance/vectors/ledger/NEG-LED-WA-0002.json",
    },
    {
        "id": "AM-005",
        "name": "CBOR-seq invalid initial byte rejected",
        "kind": "vector",
        "vector": "conformance/vectors/ledger/NEG-LED-WA-0003.json",
    },
    {
        "id": "AM-006",
        "name": "deterministic nonce mismatch rejected",
        "kind": "vector",
        "vector": "conformance/vectors/e2e/NEG-E2E-010.json",
    },
    {
        "id": "AM-007",
        "name": "ciphertext hash mismatch rejected",
        "kind": "vector",
        "vector": "conformance/vectors/e2e/NEG-E2E-020.json",
    },
    {
        "id": "AM-008",
        "name": "mixed manifest with tombstone remains unresolvable",
        "kind": "vector",
        "vector": "conformance/vectors/manifest/NEG-MAN-WA-0200.json",
    },
    {
        "id": "AM-009",
        "name": "cap/chash ambiguity conflict deterministic",
        "kind": "vector",
        "vector": "conformance/vectors/manifest/NEG-MAN-WA-0201.json",
    },
    {
        "id": "AM-010",
        "name": "ineligible records never perturb eligible winner",
        "kind": "vector",
        "vector": "conformance/vectors/manifest/NEG-MAN-WA-0202.json",
    },
    {
        "id": "AM-011",
        "name": "retroactive revoke removes revoked semantics",
        "kind": "vector",
        "vector": "conformance/vectors/ledger/NEG-LED-010.json",
    },
    {
        "id": "AM-012",
        "name": "UTF-8 bytes sorting trap rejected",
        "kind": "vector",
        "vector": "conformance/vectors/utf8/NEG-UTF8-WA-0001.json",
    },
]

FUZZ_SEED_VECTORS = [
    "conformance/vectors/cid/POS-CID-001.json",
    "conformance/vectors/cose/POS-COSE-001.json",
    "conformance/vectors/ledger/POS-LED-WA-0001.json",
    "conformance/vectors/manifest/POS-MAN-WA-0001.json",
    "conformance/vectors/e2e/POS-E2E-WA-0001.json",
    "conformance/vectors/e2e/POS-E2E-001.json",
]


@dataclass
class RunnerResult:
    crash: bool
    timeout: bool
    return_code: int
    output: dict[str, Any]
    raw_stdout: str
    raw_stderr: str


@dataclass
class CampaignContext:
    rust_cmd: list[str]
    ts_cmd: list[str]
    out_dir: Path
    minimized_dir: Path
    rng: random.Random


def _rmtree_onerror(func: Any, path: str, _exc_info: Any) -> None:
    try:
        os.chmod(path, stat.S_IRWXU | stat.S_IRWXG | stat.S_IRWXO)
    except Exception:
        # Some files can be owned by another uid/gid in containerized runs.
        pass
    try:
        func(path)
    except Exception:
        # The caller decides whether cleanup failure should affect process status.
        pass


def safe_rmtree(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {
            "status": "ok",
            "root_path": str(path),
            "error_type": None,
            "errno": None,
        }
    try:
        shutil.rmtree(path, onerror=_rmtree_onerror)
        return {
            "status": "ok",
            "root_path": str(path),
            "error_type": None,
            "errno": None,
        }
    except Exception as exc:
        try:
            shutil.rmtree(path, ignore_errors=True)
        except Exception:
            pass
        return {
            "status": "failed",
            "root_path": str(path),
            "error_type": type(exc).__name__,
            "errno": getattr(exc, "errno", None),
        }



def run(cmd: list[str], *, cwd: Path, timeout: int = 120) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        cwd=cwd,
        text=True,
        capture_output=True,
        timeout=timeout,
        check=False,
    )



def command_exists(name: str) -> bool:
    return run(["bash", "-lc", f"command -v {name}"], cwd=ROOT, timeout=30).returncode == 0


def git_rev_parse(ref: str) -> str:
    out = run(["git", "rev-parse", ref], cwd=ROOT)
    if out.returncode != 0:
        raise RuntimeError(f"git rev-parse failed for {ref}: {out.stderr.strip()}")
    return out.stdout.strip()


def git_commit_rev_parse(ref: str) -> str:
    # Peel annotated tags to commit SHA so evidence anchors are stable and comparable.
    return git_rev_parse(f"{ref}^{{commit}}")


def detect_repo_slug() -> str:
    env_repo = os.environ.get("GITHUB_REPOSITORY", "").strip()
    if env_repo and "/" in env_repo:
        return env_repo

    out = run(["git", "config", "--get", "remote.origin.url"], cwd=ROOT)
    if out.returncode != 0:
        return "<owner>/<repo>"
    url = out.stdout.strip()
    if url.startswith("git@github.com:"):
        slug = url.split("git@github.com:", 1)[1]
    elif "github.com/" in url:
        slug = url.split("github.com/", 1)[1]
    else:
        return "<owner>/<repo>"
    if slug.endswith(".git"):
        slug = slug[:-4]
    slug = slug.strip("/")
    if "/" not in slug:
        return "<owner>/<repo>"
    return slug



def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))



def dump_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")



def stable(value: Any) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)



def parse_runner_output(stdout: str) -> dict[str, Any]:
    lines = [line.strip() for line in stdout.splitlines() if line.strip()]
    if not lines:
        raise ValueError("empty stdout")
    return json.loads(lines[-1])



def invoke_runner(prefix: list[str], vector: dict[str, Any], timeout: int = 40) -> RunnerResult:
    temp_dir = ROOT / "artifacts" / ".tmp-rc-stab"
    temp_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8", dir=temp_dir) as tf:
        tf.write(json.dumps(vector, ensure_ascii=False))
        temp_name = tf.name

    cmd = [*prefix, "run", "--strict", "--vector", temp_name]
    try:
        completed = run(cmd, cwd=ROOT, timeout=timeout)
    except OSError as exc:
        # macOS can keep an incompatible linux binary in `core/rust/target/debug`.
        # In that case run the Rust runner through docker as a deterministic fallback.
        if exc.errno == 8 and command_exists("docker"):
            rel = Path(temp_name).resolve().relative_to(ROOT)
            docker_cmd = [
                "docker",
                "run",
                "--rm",
                "-v",
                f"{ROOT}:/work",
                "-w",
                "/work/core/rust",
                "rust:1.86",
                "bash",
                "-lc",
                f"set -euo pipefail; export PATH=/usr/local/cargo/bin:$PATH; cargo run -q -p grain-runner -- run --strict --vector /work/{rel}",
            ]
            completed = run(docker_cmd, cwd=ROOT, timeout=max(timeout, 240))
        else:
            raise
    except subprocess.TimeoutExpired as exc:
        os.unlink(temp_name)
        return RunnerResult(
            crash=True,
            timeout=True,
            return_code=124,
            output={},
            raw_stdout=exc.stdout or "",
            raw_stderr=exc.stderr or "",
        )
    finally:
        if os.path.exists(temp_name):
            os.unlink(temp_name)

    try:
        parsed = parse_runner_output(completed.stdout)
        crash = False
    except Exception:
        parsed = {}
        crash = True

    return RunnerResult(
        crash=crash,
        timeout=False,
        return_code=completed.returncode,
        output=parsed,
        raw_stdout=completed.stdout,
        raw_stderr=completed.stderr,
    )



def set_at_path(node: Any, path: list[Any], value: Any) -> Any:
    cur = node
    for part in path[:-1]:
        cur = cur[part]
    cur[path[-1]] = value
    return node



def find_b64_paths(node: Any, path: list[Any] | None = None) -> list[list[Any]]:
    if path is None:
        path = []
    out: list[list[Any]] = []
    if isinstance(node, dict):
        for k, v in node.items():
            p = [*path, k]
            if k.endswith("_b64") and isinstance(v, str):
                out.append(p)
            out.extend(find_b64_paths(v, p))
    elif isinstance(node, list):
        for idx, v in enumerate(node):
            out.extend(find_b64_paths(v, [*path, idx]))
    return out



def get_at_path(node: Any, path: list[Any]) -> Any:
    cur = node
    for part in path:
        cur = cur[part]
    return cur



def mutate_bytes(src: bytes, idx: int, rng: random.Random) -> bytes:
    if idx % 8 == 0:
        if not src:
            return bytes([0x00])
        arr = bytearray(src)
        arr[0] ^= 0x80
        return bytes(arr)
    if idx % 8 == 1:
        if not src:
            return bytes([0x01])
        arr = bytearray(src)
        arr[-1] ^= 0x01
        return bytes(arr)
    if idx % 8 == 2:
        return src[:-1] if src else src
    if idx % 8 == 3:
        half = max(0, len(src) // 2)
        return src[:half]
    if idx % 8 == 4:
        return src + bytes([0x00])
    if idx % 8 == 5:
        return src + bytes([0xFF])
    if idx % 8 == 6:
        n = len(src) if src else 8
        return bytes(rng.getrandbits(8) for _ in range(n))
    n = max(1, min(32, len(src) + 3))
    return bytes(rng.getrandbits(8) for _ in range(n))



def build_fuzz_vector(base: dict[str, Any], path: list[Any], mbytes: bytes, case_id: str) -> dict[str, Any]:
    vector = copy.deepcopy(base)
    encoded = base64.b64encode(mbytes).decode("ascii")
    set_at_path(vector["input"], path, encoded)
    vector["vector_id"] = case_id
    vector["strict"] = True
    vector["expect"] = {
        "pass": False,
        "diag_contains": [],
    }
    return vector



def evaluate_mutation_case(ctx: CampaignContext, vector: dict[str, Any], case_id: str) -> dict[str, Any]:
    rust = invoke_runner(ctx.rust_cmd, vector)
    ts = invoke_runner(ctx.ts_cmd, vector)

    case: dict[str, Any] = {
        "id": case_id,
        "rust": {
            "crash": rust.crash,
            "timeout": rust.timeout,
            "return_code": rust.return_code,
            "diag": rust.output.get("diag", []),
            "pass": rust.output.get("pass"),
        },
        "ts": {
            "crash": ts.crash,
            "timeout": ts.timeout,
            "return_code": ts.return_code,
            "diag": ts.output.get("diag", []),
            "pass": ts.output.get("pass"),
        },
    }

    if rust.crash or ts.crash:
        case["verdict"] = "FOUND_BUG"
        case["reason"] = "runner_crash_or_unparseable_output"
        return case

    # runner output "pass=true" means vector expectation matched.
    # For fuzz vectors we set expect.pass=false, so:
    # - pass=true  => input was rejected (intentionally rejected)
    # - pass=false => input was accepted (interesting)
    rust_matched = bool(rust.output.get("pass", False))
    ts_matched = bool(ts.output.get("pass", False))

    if rust_matched != ts_matched:
        case["verdict"] = "FOUND_BUG"
        case["reason"] = "accept_reject_divergence"
        case["rust_matched_expectation"] = rust_matched
        case["ts_matched_expectation"] = ts_matched
        return case

    if rust_matched and ts_matched:
        case["verdict"] = "INTENTIONALLY_REJECTED"
        case["reason"] = "both_rejected"
        return case

    if not rust_matched and not ts_matched:
        case["verdict"] = "INTERESTING_ACCEPT"
        case["reason"] = "mutated_input_accepted_by_both"
        return case

    case["verdict"] = "FOUND_BUG"
    case["reason"] = "unexpected_mutation_state"
    return case



def run_attack_matrix(ctx: CampaignContext) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    rows: list[dict[str, Any]] = []
    findings: list[dict[str, Any]] = []

    for entry in ATTACK_CASES:
        vector = load_json(ROOT / entry["vector"])
        row: dict[str, Any] = {
            "id": entry["id"],
            "name": entry["name"],
            "kind": entry["kind"],
            "vector": entry["vector"],
            "expected": "vector_pass_true_and_runner_parity",
        }

        if entry["kind"] == "vector":
            rust = invoke_runner(ctx.rust_cmd, vector)
            ts = invoke_runner(ctx.ts_cmd, vector)
            row["observed"] = {
                "rust_pass": rust.output.get("pass"),
                "ts_pass": ts.output.get("pass"),
                "rust_diag": rust.output.get("diag", []),
                "ts_diag": ts.output.get("diag", []),
            }

            if rust.crash or ts.crash:
                row["verdict"] = "FOUND_BUG"
                row["reason"] = "runner_crash"
                findings.append({"id": entry["id"], "reason": "runner_crash", "vector": entry["vector"]})
            elif not (bool(rust.output.get("pass")) and bool(ts.output.get("pass"))):
                row["verdict"] = "FOUND_BUG"
                row["reason"] = "vector_expectation_failed"
                findings.append({"id": entry["id"], "reason": "vector_expectation_failed", "vector": entry["vector"]})
            elif stable(rust.output.get("out", {})) != stable(ts.output.get("out", {})):
                row["verdict"] = "FOUND_BUG"
                row["reason"] = "runner_output_divergence"
                findings.append({"id": entry["id"], "reason": "runner_output_divergence", "vector": entry["vector"]})
            else:
                row["verdict"] = "PASS"

        elif entry["kind"] == "replay":
            replays = int(entry.get("replays", 3))
            rust_runs: list[dict[str, Any]] = []
            ts_runs: list[dict[str, Any]] = []
            for _ in range(replays):
                rust = invoke_runner(ctx.rust_cmd, vector)
                ts = invoke_runner(ctx.ts_cmd, vector)
                rust_runs.append(rust.output)
                ts_runs.append(ts.output)
            row["observed"] = {
                "replays": replays,
                "rust_passes": [r.get("pass") for r in rust_runs],
                "ts_passes": [t.get("pass") for t in ts_runs],
            }
            rust_stable = len({stable(x) for x in rust_runs}) == 1
            ts_stable = len({stable(x) for x in ts_runs}) == 1
            parity = stable(rust_runs[0]) == stable(ts_runs[0])
            if rust_stable and ts_stable and parity and rust_runs[0].get("pass") and ts_runs[0].get("pass"):
                row["verdict"] = "PASS"
            else:
                row["verdict"] = "FOUND_BUG"
                row["reason"] = "replay_non_determinism_or_divergence"
                findings.append({"id": entry["id"], "reason": "replay_non_determinism_or_divergence", "vector": entry["vector"]})
        else:
            row["verdict"] = "INTENTIONALLY_REJECTED"

        rows.append(row)

    return rows, findings



def run_fuzz(ctx: CampaignContext, mode: str) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[Path]]:
    cases: list[dict[str, Any]] = []
    findings: list[dict[str, Any]] = []
    saved: list[Path] = []

    per_path = 3 if mode == "smoke" else 10

    for seed_path in FUZZ_SEED_VECTORS:
        base = load_json(ROOT / seed_path)
        paths = find_b64_paths(base.get("input", {}))
        if not paths:
            continue

        for pidx, p in enumerate(paths):
            raw = get_at_path(base["input"], p)
            if not isinstance(raw, str):
                continue
            try:
                original = base64.b64decode(raw, validate=True)
            except Exception:
                continue

            for midx in range(per_path):
                case_id = f"FZ-{Path(seed_path).stem}-{pidx:02d}-{midx:02d}"
                mutated = mutate_bytes(original, midx, ctx.rng)
                vector = build_fuzz_vector(base, p, mutated, case_id)
                result = evaluate_mutation_case(ctx, vector, case_id)
                result["seed_vector"] = seed_path
                result["mutated_path"] = ".".join(str(x) for x in p)
                result["mutated_size"] = len(mutated)
                cases.append(result)

                if result["verdict"] in {"FOUND_BUG", "INTERESTING_ACCEPT"}:
                    out = ctx.minimized_dir / f"{case_id}.json"
                    dump_json(out, vector)
                    saved.append(out)

                if result["verdict"] == "FOUND_BUG":
                    findings.append(result)

    return cases, findings, saved



def run_properties(out_dir: Path) -> dict[str, Any]:
    result: dict[str, Any] = {
        "rust_properties": {"pass": False, "command": "cargo test --manifest-path core/rust/Cargo.toml -p grain-core --test properties"},
        "ts_properties": {"pass": False, "command": "node --experimental-strip-types runner/typescript/scripts/properties-full.ts"},
    }

    if command_exists("cargo"):
        rust = run(
            [
                "cargo",
                "test",
                "--manifest-path",
                "core/rust/Cargo.toml",
                "-p",
                "grain-core",
                "--test",
                "properties",
            ],
            cwd=ROOT,
            timeout=600,
        )
    elif command_exists("docker"):
        result["rust_properties"]["command"] = (
            "docker run --rm -v <repo>:/work -w /work/core/rust rust:1.86 "
            "bash -lc 'cargo test --manifest-path /work/core/rust/Cargo.toml -p grain-core --test properties'"
        )
        rust = run(
            [
                "docker",
                "run",
                "--rm",
                "-v",
                f"{ROOT}:/work",
                "-w",
                "/work/core/rust",
                "rust:1.86",
                "bash",
                "-lc",
                "set -euo pipefail; export PATH=/usr/local/cargo/bin:$PATH; cargo test --manifest-path /work/core/rust/Cargo.toml -p grain-core --test properties",
            ],
            cwd=ROOT,
            timeout=900,
        )
    else:
        rust = subprocess.CompletedProcess(args=[], returncode=127, stdout="", stderr="cargo and docker unavailable")
    result["rust_properties"].update({"pass": rust.returncode == 0, "return_code": rust.returncode})

    ts = run(
        [
            "node",
            "--experimental-strip-types",
            "runner/typescript/scripts/properties-full.ts",
        ],
        cwd=ROOT,
        timeout=300,
    )
    result["ts_properties"].update({"pass": ts.returncode == 0, "return_code": ts.returncode})

    ts_json_path = ROOT / "runner/typescript/.properties-full.json"
    if ts_json_path.exists():
        result["ts_properties"]["summary"] = load_json(ts_json_path)

    (out_dir / "properties-report.md").write_text(
        textwrap.dedent(
            f"""
            # Property Checks

            - Rust properties: {'PASS' if result['rust_properties']['pass'] else 'FAIL'}
            - TS properties: {'PASS' if result['ts_properties']['pass'] else 'FAIL'}
            """
        ).strip()
        + "\n",
        encoding="utf-8",
    )

    return result


def run_repro_check(mode: str, out_dir: Path, baseline_tag: str, baseline_sha: str) -> dict[str, Any]:
    report = {
        "executed": mode == "deep",
        "baseline_tag": baseline_tag,
        "baseline_evidence_sha256": baseline_sha,
        "pass": False,
        "cleanup": {
            "status": "not_run",
            "root_path": None,
            "error_type": None,
            "errno": None,
        },
    }

    md_path = out_dir / "reproducibility-report.md"

    if mode != "deep":
        md_path.write_text(
            "# Reproducibility Report\n\nSkipped in smoke mode.\n",
            encoding="utf-8",
        )
        return report

    baseline_commit = git_commit_rev_parse(baseline_tag)
    report["baseline_commit"] = baseline_commit

    temp = Path(tempfile.mkdtemp(prefix="grain-rc-stab-repro-"))
    clone = temp / "clone"

    try:
        clone_cmd = ["git", "clone", "--quiet", str(ROOT), str(clone)]
        if run(clone_cmd, cwd=ROOT, timeout=120).returncode != 0:
            report["error"] = "clone_failed"
            md_path.write_text("# Reproducibility Report\n\nClone failed.\n", encoding="utf-8")
            return report

        if run(["git", "checkout", baseline_tag], cwd=clone, timeout=60).returncode != 0:
            report["error"] = "checkout_failed"
            md_path.write_text("# Reproducibility Report\n\nCheckout failed.\n", encoding="utf-8")
            return report

        repro_out = clone / "artifacts/interop-repro"
        cmd = [
            "tools/interop_certify.sh",
            "--out-dir",
            str(repro_out),
            "--commit-sha",
            baseline_commit,
        ]
        cert = run(cmd, cwd=clone, timeout=2400)
        report["interop_certify_return_code"] = cert.returncode

        if cert.returncode != 0:
            report["error"] = "interop_certify_failed"
            md_path.write_text(
                "# Reproducibility Report\n\n`tools/interop_certify.sh` failed in clean clone.\n",
                encoding="utf-8",
            )
            return report

        evidence_file = repro_out / "evidence.sha256"
        if not evidence_file.exists():
            report["error"] = "missing_evidence_sha"
            md_path.write_text(
                "# Reproducibility Report\n\nMissing evidence.sha256 in repro output.\n",
                encoding="utf-8",
            )
            return report

        line = evidence_file.read_text(encoding="utf-8").splitlines()[0].strip()
        parts = line.split()
        observed = parts[1] if len(parts) > 1 else ""

        inputs_hashes = repro_out / "inputs-hashes.json"
        if inputs_hashes.exists():
            inputs_data = load_json(inputs_hashes)
            report["observed_node_version"] = inputs_data.get("node_version")

        report["observed_evidence_sha256"] = observed
        report["pass"] = observed == baseline_sha

        md_path.write_text(
            textwrap.dedent(
                f"""
                # Reproducibility Report

                - Baseline tag: `{baseline_tag}`
                - Baseline commit: `{baseline_commit}`
                - Baseline evidence sha: `{baseline_sha}`
                - Observed evidence sha: `{observed}`
                - Observed node version: `{report.get('observed_node_version', 'unknown')}`
                - Verdict: {'PASS' if report['pass'] else 'FAIL'}
                """
            ).strip()
            + "\n",
            encoding="utf-8",
        )
    finally:
        cleanup = safe_rmtree(temp)
        report["cleanup"] = cleanup
        if cleanup["status"] == "failed":
            print(
                "STAB_CLEANUP_WARN: repro temp cleanup failed "
                f"(type={cleanup['error_type']} errno={cleanup['errno']} root={cleanup['root_path']})"
            )

    return report



def run_rollback_rehearsal(mode: str, out_dir: Path, baseline_tag: str, repo_slug: str) -> dict[str, Any]:
    report = {
        "executed": mode == "deep",
        "pass": False,
        "baseline_tag": baseline_tag,
        "rc2_tag_candidate": baseline_tag.replace("rc1", "rc2"),
        "repo": repo_slug,
    }
    md_path = out_dir / "rollback-rehearsal.md"

    if mode != "deep":
        md_path.write_text("# Rollback Rehearsal\n\nSkipped in smoke mode.\n", encoding="utf-8")
        return report

    tag_exists = run(["git", "tag", "--list", baseline_tag], cwd=ROOT).stdout.strip() == baseline_tag
    rc2_exists = bool(run(["git", "tag", "--list", report["rc2_tag_candidate"]], cwd=ROOT).stdout.strip())

    if run(["gh", "--version"], cwd=ROOT, timeout=30).returncode != 0:
        report["error"] = "gh_cli_missing"
        md_path.write_text("# Rollback Rehearsal\n\n`gh` CLI is required for deep rollback drill.\n", encoding="utf-8")
        return report

    rel = run(["gh", "api", f"repos/{repo_slug}/releases/tags/{baseline_tag}"], cwd=ROOT, timeout=120)

    release_ok = False
    prerelease = False
    assets: list[str] = []
    if rel.returncode == 0:
        payload = json.loads(rel.stdout)
        prerelease = bool(payload.get("prerelease", False))
        assets = [a.get("name", "") for a in payload.get("assets", [])]
        release_ok = any(name.startswith("evidence-") for name in assets) and any(name.startswith("interop-evidence-") for name in assets)

    report.update(
        {
            "tag_exists": tag_exists,
            "rc2_exists": rc2_exists,
            "release_lookup_ok": rel.returncode == 0,
            "release_prerelease": prerelease,
            "release_assets": assets,
            "release_assets_ok": release_ok,
        }
    )

    report["pass"] = tag_exists and not rc2_exists and rel.returncode == 0 and release_ok and prerelease

    body = textwrap.dedent(
        f"""
        # Rollback Rehearsal

        - Baseline RC tag exists: `{tag_exists}`
        - RC release lookup success: `{rel.returncode == 0}`
        - RC release prerelease=true: `{prerelease}`
        - RC release has evidence+interop assets: `{release_ok}`
        - RC2 tag currently absent (`{report['rc2_tag_candidate']}`): `{not rc2_exists}`
        - Drill verdict: {'PASS' if report['pass'] else 'FAIL'}

        ## Non-destructive rollback playbook (simulated)

        1. Publish revocation note under `spec/rc/REVOCATIONS/` for `{baseline_tag}`.
        2. Cut new signed tag `{report['rc2_tag_candidate']}` on blocker-fix commit.
        3. Push RC2 tag and verify `release-evidence` + `interop-certify` artifacts.
        4. Update claim references to RC2 evidence hash.
        """
    ).strip()
    md_path.write_text(body + "\n", encoding="utf-8")

    return report



def write_attack_markdown(path: Path, rows: list[dict[str, Any]]) -> None:
    lines = [
        "# Attack Matrix Results",
        "",
        "| ID | Scenario | Vector | Verdict |",
        "| --- | --- | --- | --- |",
    ]
    for r in rows:
        lines.append(f"| {r['id']} | {r['name']} | `{r['vector']}` | {r['verdict']} |")
    lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")



def write_fuzz_markdown(path: Path, cases: list[dict[str, Any]], findings: list[dict[str, Any]]) -> None:
    verdict_counts: dict[str, int] = {}
    for c in cases:
        verdict_counts[c["verdict"]] = verdict_counts.get(c["verdict"], 0) + 1

    lines = [
        "# Fuzz Report",
        "",
        f"Total cases: **{len(cases)}**",
        "",
        "## Verdict counts",
    ]
    for key in sorted(verdict_counts):
        lines.append(f"- {key}: {verdict_counts[key]}")

    lines.append("")
    lines.append("## Findings")
    if not findings:
        lines.append("- none")
    else:
        for f in findings[:50]:
            lines.append(f"- `{f['id']}`: {f.get('reason', 'unknown')}")

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")



def zip_and_hash(source_dir: Path, zip_path: Path, sha_path: Path) -> None:
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for file in sorted(source_dir.rglob("*")):
            if file.is_file():
                zf.write(file, file.relative_to(source_dir))

    digest = hashlib.sha256(zip_path.read_bytes()).hexdigest()
    sha_path.write_text(f"{digest}  {zip_path.name}\n", encoding="utf-8")



def main() -> int:
    parser = argparse.ArgumentParser(description="Run TOR-RC-STAB-A01 stabilization checks")
    parser.add_argument("--mode", choices=["smoke", "deep"], required=True)
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--baseline-tag", default=DEFAULT_BASELINE_TAG)
    parser.add_argument("--baseline-evidence-sha", default=DEFAULT_BASELINE_EVIDENCE_SHA)
    parser.add_argument(
        "--rust-runner-cmd",
        nargs="+",
        default=["core/rust/target/debug/grain-runner"],
    )
    parser.add_argument(
        "--ts-runner-cmd",
        nargs="+",
        default=["node", "--experimental-strip-types", "runner/typescript/src/cli.ts"],
    )
    parser.add_argument("--repo", default=detect_repo_slug())
    parser.add_argument("--seed", type=int, default=20260225)
    args = parser.parse_args()

    out_dir = (ROOT / args.out_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    minimized_dir = out_dir / "minimized-repros"
    minimized_dir.mkdir(parents=True, exist_ok=True)

    ctx = CampaignContext(
        rust_cmd=list(args.rust_runner_cmd),
        ts_cmd=list(args.ts_runner_cmd),
        out_dir=out_dir,
        minimized_dir=minimized_dir,
        rng=random.Random(args.seed),
    )

    started = time.time()
    baseline_commit = git_commit_rev_parse(args.baseline_tag)

    attack_rows, attack_findings = run_attack_matrix(ctx)
    write_attack_markdown(out_dir / "attack-matrix-results.md", attack_rows)
    dump_json(out_dir / "attack-matrix-results.json", attack_rows)

    fuzz_cases, fuzz_findings, saved_vectors = run_fuzz(ctx, args.mode)
    write_fuzz_markdown(out_dir / "fuzz-report.md", fuzz_cases, fuzz_findings)
    dump_json(out_dir / "fuzz-cases.json", fuzz_cases)

    properties = run_properties(out_dir)
    repro = run_repro_check(args.mode, out_dir, args.baseline_tag, args.baseline_evidence_sha)
    rollback = run_rollback_rehearsal(args.mode, out_dir, args.baseline_tag, args.repo)

    zip_path = out_dir / "minimized-repros.zip"
    sha_path = out_dir / "minimized-repros.sha256"
    zip_and_hash(minimized_dir, zip_path, sha_path)

    findings_total = len(attack_findings) + len(fuzz_findings)
    interesting_total = sum(1 for c in fuzz_cases if c["verdict"] == "INTERESTING_ACCEPT")
    properties_pass = bool(properties["rust_properties"]["pass"]) and bool(properties["ts_properties"]["pass"])

    gates = {
        "attack_matrix_pass": len(attack_findings) == 0,
        "fuzz_no_crash_or_divergence": len(fuzz_findings) == 0,
        "properties_pass": properties_pass,
        "repro_pass": True if args.mode == "smoke" else bool(repro.get("pass", False)),
        "rollback_rehearsal_pass": True if args.mode == "smoke" else bool(rollback.get("pass", False)),
    }

    protocol_verdict = "PASS" if all(gates.values()) else "FAIL"
    cleanup_report = repro.get("cleanup", {})
    cleanup_state = cleanup_report.get("status", "not_run")
    cleanup_failed = cleanup_state == "failed"
    cleanup_warnings = []
    if cleanup_failed:
        cleanup_warnings.append(
            {
                "code": "STAB_CLEANUP_WARN",
                "root_path": cleanup_report.get("root_path"),
                "error_type": cleanup_report.get("error_type"),
                "errno": cleanup_report.get("errno"),
            }
        )

    # INV-STAB-001:
    # Cleanup failures are recorded as warnings and MUST NOT flip protocol verdict.
    verdict = protocol_verdict

    evidence_core = {
        "tor": "TOR-RC-STAB-A01",
        "mode": args.mode,
        "verdict": verdict,
        "protocol_verdict": protocol_verdict,
        "repo_head": git_rev_parse("HEAD"),
        "repo": args.repo,
        "seed": args.seed,
        "baseline": {
            "tag": args.baseline_tag,
            "commit": baseline_commit,
            "evidence_sha256": args.baseline_evidence_sha,
        },
        "runs": {
            "attack_matrix_total": len(attack_rows),
            "fuzz_total": len(fuzz_cases),
            "fuzz_findings": len(fuzz_findings),
            "fuzz_interesting": interesting_total,
            "minimized_repros": len(saved_vectors),
        },
        "gates": gates,
        "cleanup": {
            "status": cleanup_state,
            "warnings": cleanup_warnings,
            "repro_temp_dir": cleanup_report.get("root_path"),
        },
        "artifacts": {
            "fuzz_report": str((out_dir / "fuzz-report.md").relative_to(ROOT)),
            "attack_matrix_report": str((out_dir / "attack-matrix-results.md").relative_to(ROOT)),
            "reproducibility_report": str((out_dir / "reproducibility-report.md").relative_to(ROOT)),
            "rollback_rehearsal": str((out_dir / "rollback-rehearsal.md").relative_to(ROOT)),
            "minimized_repros_zip": str(zip_path.relative_to(ROOT)),
            "minimized_repros_sha256": str(sha_path.relative_to(ROOT)),
        },
        "properties": properties,
        "reproducibility": repro,
        "rollback": rollback,
    }

    content_digest = hashlib.sha256(stable(evidence_core).encode("utf-8")).hexdigest()
    stabilization = {
        **evidence_core,
        "content_digest_sha256": content_digest,
        "started_at_epoch": int(started),
        "duration_seconds": int(time.time() - started),
    }

    dump_json(out_dir / "stabilization-evidence.json", stabilization)

    if findings_total > 0:
        dump_json(out_dir / "findings.json", {"attack": attack_findings, "fuzz": fuzz_findings})

    return 0 if protocol_verdict == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
