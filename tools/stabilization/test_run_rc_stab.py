#!/usr/bin/env python3
"""Tests for TOR-RC-STAB-A01 runner infrastructure behavior."""

from __future__ import annotations

import argparse
import importlib.util
import subprocess
import shutil
import stat
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


MODULE_PATH = Path(__file__).resolve().parent / "run_rc_stab.py"
SPEC = importlib.util.spec_from_file_location("run_rc_stab", MODULE_PATH)
assert SPEC and SPEC.loader
run_rc_stab = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = run_rc_stab
SPEC.loader.exec_module(run_rc_stab)


class StabilizationRunnerTests(unittest.TestCase):
    def test_safe_rmtree_handles_read_only_tree(self) -> None:
        root = Path(tempfile.mkdtemp(prefix="rc-stab-safe-rmtree-"))
        nested = root / "nested"
        nested.mkdir(parents=True, exist_ok=True)
        payload = nested / "payload.bin"
        payload.write_bytes(b"ok")
        nested.chmod(stat.S_IRUSR | stat.S_IXUSR)
        try:
            report = run_rc_stab.safe_rmtree(root)
            self.assertIn(report["status"], {"ok", "failed"})
            self.assertEqual(report["root_path"], str(root))
        finally:
            nested.chmod(stat.S_IRWXU)
            shutil.rmtree(root, ignore_errors=True)

    def test_cleanup_failure_does_not_flip_protocol_pass(self) -> None:
        out_dir = run_rc_stab.ROOT / "artifacts" / "test-rc-stab-a02"
        if out_dir.exists():
            shutil.rmtree(out_dir, ignore_errors=True)

        args = argparse.Namespace(
            mode="deep",
            out_dir=str(out_dir.relative_to(run_rc_stab.ROOT)),
            baseline_tag="repo-rc-v0.4.0-rc1",
            baseline_evidence_sha="deadbeef",
            rust_runner_cmd=["core/rust/target/debug/grain-runner"],
            ts_runner_cmd=["node", "runner/typescript/dist/src/cli.js"],
            repo="acme/grain",
            seed=20260225,
        )

        with (
            mock.patch.object(argparse.ArgumentParser, "parse_args", return_value=args),
            mock.patch.object(
                run_rc_stab,
                "git_rev_parse",
                side_effect=lambda ref: "baseline" if ref == f"{args.baseline_tag}^{{commit}}" else "head",
            ),
            mock.patch.object(run_rc_stab, "run_attack_matrix", return_value=([], [])),
            mock.patch.object(run_rc_stab, "write_attack_markdown"),
            mock.patch.object(run_rc_stab, "run_fuzz", return_value=([], [], [])),
            mock.patch.object(run_rc_stab, "write_fuzz_markdown"),
            mock.patch.object(run_rc_stab, "run_properties", return_value={"rust_properties": {"pass": True}, "ts_properties": {"pass": True}}),
            mock.patch.object(run_rc_stab, "run_repro_check", return_value={"pass": True, "cleanup": {"status": "failed", "root_path": "/tmp/mock", "error_type": "PermissionError", "errno": 1}}),
            mock.patch.object(run_rc_stab, "run_rollback_rehearsal", return_value={"pass": True}),
            mock.patch.object(run_rc_stab, "run", return_value=subprocess.CompletedProcess(args=[], returncode=0, stdout="", stderr="")),
        ):
            exit_code = run_rc_stab.main()

        self.assertEqual(exit_code, 0)
        evidence_path = out_dir / "stabilization-evidence.json"
        self.assertTrue(evidence_path.exists())
        evidence = run_rc_stab.load_json(evidence_path)
        self.assertEqual(evidence["protocol_verdict"], "PASS")
        self.assertEqual(evidence["verdict"], "PASS")
        self.assertEqual(evidence["cleanup"]["status"], "failed")
        self.assertEqual(evidence["cleanup"]["warnings"][0]["code"], "STAB_CLEANUP_WARN")

        shutil.rmtree(out_dir, ignore_errors=True)

    def test_run_repro_check_uses_peeled_commit_for_annotated_tag(self) -> None:
        out_dir = Path(tempfile.mkdtemp(prefix="rc-stab-repro-out-"))
        baseline_tag = "repo-rc-v0.4.0-rc1"
        baseline_sha = "deadbeef"
        captured_commit_sha: list[str] = []

        def fake_run(cmd: list[str], *, cwd: Path, timeout: int = 120) -> subprocess.CompletedProcess[str]:
            if cmd[:3] == ["git", "clone", "--quiet"]:
                Path(cmd[3]).mkdir(parents=True, exist_ok=True)
                return subprocess.CompletedProcess(cmd, 0, "", "")
            if cmd[:2] == ["git", "checkout"]:
                return subprocess.CompletedProcess(cmd, 0, "", "")
            if cmd and cmd[0] == "tools/interop_certify.sh":
                commit_idx = cmd.index("--commit-sha") + 1
                captured_commit_sha.append(cmd[commit_idx])
                repro_out = Path(cmd[cmd.index("--out-dir") + 1])
                repro_out.mkdir(parents=True, exist_ok=True)
                (repro_out / "evidence.sha256").write_text(f"evidence_sha256 {baseline_sha}\n", encoding="utf-8")
                return subprocess.CompletedProcess(cmd, 0, "", "")
            return subprocess.CompletedProcess(cmd, 0, "", "")

        with (
            mock.patch.object(
                run_rc_stab,
                "git_commit_rev_parse",
                return_value="3232e43b54c57205ebda242be16b964a85c125f8",
            ),
            mock.patch.object(run_rc_stab, "run", side_effect=fake_run),
            mock.patch.object(
                run_rc_stab,
                "safe_rmtree",
                return_value={"status": "ok", "root_path": "/tmp/mock", "error_type": None, "errno": None},
            ),
        ):
            report = run_rc_stab.run_repro_check("deep", out_dir, baseline_tag, baseline_sha)

        self.assertTrue(report["pass"])
        self.assertEqual(report["baseline_commit"], "3232e43b54c57205ebda242be16b964a85c125f8")
        self.assertEqual(captured_commit_sha, ["3232e43b54c57205ebda242be16b964a85c125f8"])

        shutil.rmtree(out_dir, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
