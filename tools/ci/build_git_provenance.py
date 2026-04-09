#!/usr/bin/env python3
"""Build git/GitHub provenance snapshot for TOR-GH-CLEAN-A01 reports."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
from pathlib import Path


def run(cmd: list[str]) -> str:
    return subprocess.check_output(cmd, text=True).strip()


def maybe_json(cmd: list[str]) -> dict | list | None:
    try:
        raw = subprocess.check_output(cmd, text=True).strip()
    except Exception:
        return None
    if not raw:
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return None


def detect_repo_slug() -> str:
    env_repo = os.environ.get("GITHUB_REPOSITORY", "").strip()
    if env_repo and "/" in env_repo:
        return env_repo

    try:
        remote = subprocess.check_output(
            ["git", "config", "--get", "remote.origin.url"], text=True
        ).strip()
    except Exception:
        return "<owner>/<repo>"

    slug = ""
    if remote.startswith("git@github.com:"):
        slug = remote.split("git@github.com:", 1)[1]
    elif "github.com/" in remote:
        slug = remote.split("github.com/", 1)[1]

    if slug.endswith(".git"):
        slug = slug[:-4]
    slug = slug.strip("/")
    if "/" not in slug:
        return "<owner>/<repo>"
    return slug


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(allow_abbrev=False)
    p.add_argument("--repo", default=detect_repo_slug())
    p.add_argument("--out", required=True)
    return p.parse_args()


def main() -> int:
    args = parse_args()

    head = run(["git", "rev-parse", "HEAD"])
    head_tree = run(["git", "rev-parse", "HEAD^{tree}"])
    origin_main = run(["git", "rev-parse", "origin/main"])
    origin_main_tree = run(["git", "rev-parse", "origin/main^{tree}"])
    branch = run(["git", "rev-parse", "--abbrev-ref", "HEAD"])
    ahead_behind = run(["git", "rev-list", "--left-right", "--count", "origin/main...HEAD"])
    status_porcelain = run(["git", "status", "--porcelain=v1"]) if True else ""

    protection = maybe_json(["gh", "api", f"repos/{args.repo}/rules/branches/main"])
    ci_runs = maybe_json(
        [
            "gh",
            "run",
            "list",
            "--workflow",
            "ci.yml",
            "--branch",
            "main",
            "--limit",
            "5",
            "--json",
            "databaseId,headSha,status,conclusion,createdAt,updatedAt,displayTitle",
        ]
    )
    release_runs = maybe_json(
        [
            "gh",
            "run",
            "list",
            "--workflow",
            "release-evidence.yml",
            "--limit",
            "5",
            "--json",
            "databaseId,headSha,status,conclusion,createdAt,updatedAt,displayTitle,event",
        ]
    )
    interop_runs = maybe_json(
        [
            "gh",
            "run",
            "list",
            "--workflow",
            "interop-certify.yml",
            "--limit",
            "5",
            "--json",
            "databaseId,headSha,status,conclusion,createdAt,updatedAt,displayTitle,event",
        ]
    )

    data = {
        "branch": branch,
        "head": head,
        "head_tree": head_tree,
        "origin_main": origin_main,
        "origin_main_tree": origin_main_tree,
        "ahead_behind": ahead_behind,
        "worktree_clean": status_porcelain == "",
        "protection": protection,
        "recent_ci_runs": ci_runs,
        "recent_release_evidence_runs": release_runs,
        "recent_interop_certify_runs": interop_runs,
    }

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(data, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
    print("git provenance snapshot: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
