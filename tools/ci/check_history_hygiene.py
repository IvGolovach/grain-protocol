#!/usr/bin/env python3
"""Fail when repository history or tracked files contain publication-hygiene leaks."""

from __future__ import annotations

import argparse
import io
import re
import subprocess
import sys
from pathlib import Path

CYRILLIC_RE = re.compile(r"[\u0400-\u04FF]")


def literal(*parts: str, flags: int = 0) -> re.Pattern[str]:
    return re.compile(re.escape("".join(parts)), flags)


PATTERNS: tuple[tuple[str, re.Pattern[str]], ...] = (
    (
        "personal-email",
        literal("funtland@", "icloud.com", flags=re.IGNORECASE),
    ),
    (
        "private-slug",
        re.compile(
            "|".join(
                (
                    re.escape("IvGolovach/" + "grain-protocol-" + "private"),
                    re.escape("grain-protocol-" + "private"),
                )
            )
        ),
    ),
    (
        "macos-home-path",
        re.compile(re.escape("/" + "Users" + "/") + r"[^/\s]+(?:/[^\s\"']+)+"),
    ),
    (
        "unix-home-path",
        re.compile(re.escape("/" + "home" + "/") + r"[^/\s]+(?:/[^\s\"']+)+"),
    ),
    (
        "private-tmp-path",
        re.compile(re.escape("/" + "private" + "/tmp") + r"(?:/[^\s\"']+)?"),
    ),
    (
        "codex-fingerprint",
        re.compile(
            r"(?<![A-Za-z0-9_])" + re.escape("." + "codex") + r"(?![A-Za-z0-9_])"
        ),
    ),
    ("tok-scale-fingerprint", literal("tok", "scale", flags=re.IGNORECASE)),
    ("little-snitch-fingerprint", literal("Little", " Snitch", flags=re.IGNORECASE)),
    (
        "publication-prep-marker",
        re.compile(
            r"\b"
            + re.escape("de-" + "private")
            + r"\b|\b"
            + re.escape("public-" + "mirror")
            + r"\b",
            re.IGNORECASE,
        ),
    ),
    ("migration-marker", literal("PUBLIC-", "MIGRATION-", "A01")),
)

TEXT_EXT_ALLOWLIST = {
    ".md",
    ".txt",
    ".json",
    ".yml",
    ".yaml",
    ".toml",
    ".py",
    ".sh",
    ".ts",
    ".tsx",
    ".js",
    ".cjs",
    ".mjs",
    ".rs",
    ".cddl",
}

MAX_FINDINGS = 50


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--root", default=".")
    return parser.parse_args()


def git(root: Path, *args: str, input_text: str | None = None) -> str:
    proc = subprocess.run(
        ["git", *args],
        cwd=root,
        input=input_text,
        text=True,
        capture_output=True,
        check=True,
    )
    return proc.stdout


def git_bytes(root: Path, *args: str, input_bytes: bytes | None = None) -> bytes:
    proc = subprocess.run(
        ["git", *args],
        cwd=root,
        input=input_bytes,
        capture_output=True,
        check=True,
    )
    return proc.stdout


def is_binary(path: Path, data: bytes) -> bool:
    if b"\x00" in data[:8192]:
        return True
    if not path.suffix:
        return False
    return path.suffix.lower() not in TEXT_EXT_ALLOWLIST and path.suffix.lower() in {
        ".png",
        ".jpg",
        ".jpeg",
        ".gif",
        ".pdf",
        ".zip",
        ".gz",
        ".tgz",
        ".tar",
        ".wasm",
        ".ico",
        ".bin",
    }


def record_findings(text: str, scope: str, findings: list[str]) -> None:
    if CYRILLIC_RE.search(text):
        findings.append(f"{scope}: Cyrillic text detected")
    for label, pattern in PATTERNS:
        if pattern.search(text):
            findings.append(f"{scope}: matched {label}")


def tracked_files(root: Path) -> list[Path]:
    out = git(root, "ls-files", "-z")
    return [root / rel for rel in out.split("\x00") if rel]


def scan_tracked_files(root: Path, findings: list[str]) -> None:
    for path in tracked_files(root):
        rel = str(path.relative_to(root))
        record_findings(rel, f"path:{rel}", findings)
        if len(findings) >= MAX_FINDINGS:
            return
        data = path.read_bytes()
        if is_binary(path, data):
            continue
        record_findings(data.decode("utf-8", errors="ignore"), f"file:{rel}", findings)
        if len(findings) >= MAX_FINDINGS:
            return


def reachable_blob_paths(root: Path) -> dict[str, str]:
    mapping: dict[str, str] = {}
    for line in git(root, "rev-list", "--objects", "--all").splitlines():
        if " " not in line:
            continue
        oid, path = line.split(" ", 1)
        mapping.setdefault(oid, path)
    return mapping


def blob_object_ids(root: Path, path_by_oid: dict[str, str]) -> list[str]:
    if not path_by_oid:
        return []
    batch_input = "".join(f"{oid}\n" for oid in path_by_oid).encode("utf-8")
    out = git_bytes(
        root,
        "cat-file",
        "--batch-check=%(objectname) %(objecttype) %(objectsize)",
        input_bytes=batch_input,
    ).decode("utf-8")
    blob_ids: list[str] = []
    for line in out.splitlines():
        oid, obj_type, _size = line.split()
        if obj_type == "blob":
            blob_ids.append(oid)
    return blob_ids


def scan_history_blobs(root: Path, findings: list[str]) -> None:
    path_by_oid = reachable_blob_paths(root)
    blob_ids = blob_object_ids(root, path_by_oid)
    if not blob_ids:
        return

    batch_input = "".join(f"{oid}\n" for oid in blob_ids).encode("utf-8")
    stream = io.BytesIO(git_bytes(root, "cat-file", "--batch", input_bytes=batch_input))

    while True:
        header = stream.readline()
        if not header:
            break
        oid, obj_type, size_str = header.rstrip(b"\n").decode("utf-8").split()
        size = int(size_str)
        data = stream.read(size)
        stream.read(1)
        if obj_type != "blob":
            continue
        rel = path_by_oid.get(oid, "<unknown>")
        if is_binary(Path(rel), data):
            continue
        record_findings(
            data.decode("utf-8", errors="ignore"),
            f"history-blob:{rel}@{oid[:12]}",
            findings,
        )
        if len(findings) >= MAX_FINDINGS:
            return


def scan_commits(root: Path, findings: list[str]) -> None:
    for commit in git(root, "rev-list", "--all").splitlines():
        meta = git(
            root,
            "show",
            "-s",
            "--format=%ae%x00%ce%x00%B",
            commit,
        )
        author_email, committer_email, message = meta.split("\x00", 2)
        for email_scope, email in (
            (f"commit-author:{commit[:12]}", author_email),
            (f"commit-committer:{commit[:12]}", committer_email),
        ):
            record_findings(email, email_scope, findings)
            if len(findings) >= MAX_FINDINGS:
                return
        record_findings(message, f"commit-message:{commit[:12]}", findings)
        if len(findings) >= MAX_FINDINGS:
            return


def scan_tags(root: Path, findings: list[str]) -> None:
    tag_names = [line for line in git(root, "tag", "--list").splitlines() if line]
    for tag in tag_names:
        contents = git(
            root,
            "for-each-ref",
            f"refs/tags/{tag}",
            "--format=%(taggeremail)%00%(contents)",
        )
        if not contents:
            continue
        tagger_email, message = contents.split("\x00", 1)
        record_findings(tagger_email, f"tagger:{tag}", findings)
        if len(findings) >= MAX_FINDINGS:
            return
        record_findings(message, f"tag-message:{tag}", findings)
        if len(findings) >= MAX_FINDINGS:
            return


def main() -> int:
    args = parse_args()
    root = Path(args.root).resolve()
    findings: list[str] = []

    scan_tracked_files(root, findings)
    if len(findings) < MAX_FINDINGS:
        scan_history_blobs(root, findings)
    if len(findings) < MAX_FINDINGS:
        scan_commits(root, findings)
    if len(findings) < MAX_FINDINGS:
        scan_tags(root, findings)

    if findings:
        print("Repository history hygiene check failed:", file=sys.stderr)
        for finding in findings[:MAX_FINDINGS]:
            print(f"- {finding}", file=sys.stderr)
        if len(findings) > MAX_FINDINGS:
            print(f"- ... and {len(findings) - MAX_FINDINGS} more", file=sys.stderr)
        return 1

    print("Repository history hygiene check: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
