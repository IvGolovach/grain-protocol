#!/usr/bin/env python3
"""Check Dependabot auto-merge workflow and docs policy consistency."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

REQUIRED_WORKFLOW_TOKENS = (
    "pull_request_target",
    "dependabot[bot]",
    "app/dependabot",
    ".github/workflows/*",
    ".github/dependabot.yml",
    ".github/ISSUE_TEMPLATE/*",
    ".github/actions/*",
    "spec/*|conformance/*|core/*|runner/*|docs/llm/*|tools/*",
    "DEPENDABOT_AUTOMERGE_TOKEN",
    "GH_BOT_TOKEN: ${{ secrets.DEPENDABOT_AUTOMERGE_TOKEN }}",
    "GH_FALLBACK_TOKEN: ${{ github.token }}",
    'export GH_TOKEN="${GH_BOT_TOKEN:-$GH_FALLBACK_TOKEN}"',
    "@dependabot rebase",
    "gh pr merge",
    "--auto --rebase",
    "Verify auto-merge gate for safe lane",
)

REQUIRED_DOC_TOKENS = (
    "allowlist",
    ".github/workflows/**",
    ".github/dependabot.yml",
    "manual",
    "spec/**",
    "conformance/**",
    "core/**",
    "runner/**",
    "docs/llm/**",
    "tools/**",
    "Workflows: Read and Write",
    "repo`, `workflow`",
    "fails fast with explicit diagnostics",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--workflow", default=".github/workflows/dependabot-automerge.yml")
    parser.add_argument("--policy-doc", default="docs/human/dependencies-policy.md")
    return parser.parse_args()


def require_tokens(path: Path, tokens: tuple[str, ...], label: str) -> list[str]:
    if not path.exists():
        return [f"{label}: missing file {path}"]
    text = path.read_text(encoding="utf-8")
    missing: list[str] = []
    for token in tokens:
        if token not in text:
            missing.append(f"{label}: missing token: {token}")
    return missing


def main() -> int:
    args = parse_args()
    workflow = Path(args.workflow)
    policy_doc = Path(args.policy_doc)

    errors: list[str] = []
    errors.extend(require_tokens(workflow, REQUIRED_WORKFLOW_TOKENS, "workflow"))
    errors.extend(require_tokens(policy_doc, REQUIRED_DOC_TOKENS, "policy-doc"))
    if workflow.exists():
        wf_text = workflow.read_text(encoding="utf-8")
        if '${GH_FALLBACK_TOKEN:-$GH_BOT_TOKEN}' in wf_text:
            errors.append(
                "workflow: fallback token is configured as primary; expected bot token primary."
            )

    if errors:
        print("Dependabot policy check failed:", file=sys.stderr)
        for err in errors:
            print(f"- {err}", file=sys.stderr)
        return 1

    print("Dependabot policy check: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
