#!/usr/bin/env python3
"""Check that public PR CI is explicit, cancellable, and fail-closed."""

from __future__ import annotations

import argparse
import ast
import re
import sys
from pathlib import Path


REQUIRED_CONTEXT = "CI gate"
ALLOWED_HOSTED_RUNNERS = {"ubuntu-latest", "macos-15"}
GATE_EVALUATOR_CONSTANTS = ("BASE_JOBS", "FULL_JOBS", "MAIN_JOBS", "APPROVAL_JOB")


def job_block(text: str, job_id: str) -> str:
    match = re.search(
        rf"(?ms)^  {re.escape(job_id)}:\s*$.*?(?=^  [A-Za-z0-9_-]+:\s*$|\Z)",
        text,
    )
    return match.group(0) if match else ""


def check_upload_retention(text: str) -> list[str]:
    lines = text.splitlines()
    errors: list[str] = []
    upload_count = 0
    for index, line in enumerate(lines):
        if "uses: actions/upload-artifact@" not in line:
            continue
        upload_count += 1
        window = "\n".join(lines[index + 1 : index + 9])
        if "retention-days:" not in window:
            errors.append(f"ci: upload-artifact at line {index + 1} needs retention-days")
    if upload_count == 0:
        errors.append("ci: expected at least one upload-artifact step")
    return errors


def check_ci_workflow(path: Path) -> list[str]:
    if not path.exists():
        return [f"ci: missing workflow {path}"]
    text = path.read_text(encoding="utf-8")
    errors: list[str] = []

    required_tokens = (
        "workflow_dispatch:",
        "types: [opened, reopened, synchronize]",
        "group: ${{ github.event_name == 'pull_request' && format('ci-pr-{0}', github.event.pull_request.number) || format('ci-run-{0}', github.run_id) }}",
        "cancel-in-progress: ${{ github.event_name == 'pull_request' }}",
        "pull-requests: read",
        "CI_COMMIT_SHA: ${{ github.event_name == 'pull_request' && github.event.pull_request.head.sha || github.sha }}",
        "GH_TOKEN: ${{ github.token }}",
        "PR_CHANGED_FILES: ${{ github.event.pull_request.changed_files }}",
        "gh api --paginate --slurp",
        "tools/ci/classify_ci_scope.py",
        '--expected-count "$PR_CHANGED_FILES"',
        "ruleset_token: ${{ github.token }}",
    )
    for token in required_tokens:
        if token not in text:
            errors.append(f"ci: missing token: {token}")

    for token in ("self-hosted", "pull_request_target:", "workflow_run:", "schedule:", "labeled"):
        if token in text:
            errors.append(f"ci: forbidden trigger or runner token present: {token}")

    if text.count("runs-on: macos-15") != 1:
        errors.append("ci: sdk-platform must be the only macOS job")

    sdk = job_block(text, "sdk-platform")
    for token in (
        "needs: [scope, full-ci-approval]",
        "always() &&",
        "needs.scope.result == 'success'",
        "github.event_name != 'pull_request'",
        "needs.scope.outputs.full_required == 'true'",
        "needs.full-ci-approval.result == 'success'",
        "runs-on: macos-15",
    ):
        if token not in sdk:
            errors.append(f"ci:sdk-platform: missing token: {token}")

    evidence = job_block(text, "evidence-bundle")
    for token in (
        "always() &&",
        "needs.sdk-platform.result == 'success'",
    ):
        if token not in evidence:
            errors.append(f"ci:evidence-bundle: missing token: {token}")

    approval = job_block(text, "full-ci-approval")
    for token in (
        "name: Approve full CI",
        "needs: [scope, python-tooling, capid-csprng-audit, rust-core, ts-c01, ts-full, wasm-smoke]",
        "always() &&",
        "github.event_name == 'pull_request'",
        "needs.scope.result == 'success'",
        "needs.scope.outputs.full_required == 'true'",
        "needs.python-tooling.result == 'success'",
        "needs.capid-csprng-audit.result == 'success'",
        "needs.rust-core.result == 'success'",
        "needs.ts-c01.result == 'success'",
        "needs.ts-full.result == 'success'",
        "needs.wasm-smoke.result == 'success'",
        "permissions: {}",
        "environment:",
        "name: full-ci",
        "deployment: false",
    ):
        if token not in approval:
            errors.append(f"ci:full-ci-approval: missing token: {token}")
    for token in ("uses:", "secrets.", "vars."):
        if token in approval:
            errors.append(f"ci:full-ci-approval: forbidden token: {token}")

    main_only_condition = "if: needs.scope.result == 'success' && github.event_name != 'pull_request'"
    for job_id in ("fuzz-smoke", "verify-script-smoke"):
        if main_only_condition not in job_block(text, job_id):
            errors.append(f"ci:{job_id}: missing main/manual-only condition")

    for job_id in ("scope", "verify-script-smoke"):
        if "persist-credentials: false" not in job_block(text, job_id):
            errors.append(f"ci:{job_id}: checkout must disable credential persistence")

    gate = job_block(text, "ci-gate")
    for token in (
        "name: CI gate",
        "if: always()",
        "persist-credentials: false",
        "FULL_REQUIRED: ${{ needs.scope.outputs.full_required }}",
        '--full-required "${FULL_REQUIRED}"',
        "tools/ci/evaluate_ci_gate.py",
        '--job "full-ci-approval=${{ needs.full-ci-approval.result }}"',
        '--job "evidence-bundle=${{ needs.evidence-bundle.result }}"',
    ):
        if token not in gate:
            errors.append(f"ci:ci-gate: missing token: {token}")
    if '--full-required "${{ needs.scope.outputs.full_required }}"' in gate:
        errors.append("ci:ci-gate: scope output must not be interpolated directly into shell")

    errors.extend(check_upload_retention(text))
    return errors


def evaluator_job_ids(path: Path) -> tuple[set[str], list[str]]:
    if not path.exists():
        return set(), [f"ci-gate-parity: missing evaluator {path}"]
    try:
        tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    except SyntaxError as exc:
        return set(), [f"ci-gate-parity: invalid evaluator syntax: {exc}"]

    values: dict[str, object] = {}
    for node in tree.body:
        if not isinstance(node, ast.Assign) or len(node.targets) != 1:
            continue
        target = node.targets[0]
        if not isinstance(target, ast.Name) or target.id not in GATE_EVALUATOR_CONSTANTS:
            continue
        try:
            values[target.id] = ast.literal_eval(node.value)
        except (TypeError, ValueError):
            return set(), [f"ci-gate-parity: evaluator constant is not literal: {target.id}"]

    missing = sorted(set(GATE_EVALUATOR_CONSTANTS) - values.keys())
    if missing:
        return set(), [f"ci-gate-parity: missing evaluator constants: {missing}"]

    for name in ("BASE_JOBS", "FULL_JOBS", "MAIN_JOBS"):
        if not isinstance(values[name], tuple):
            return set(), [f"ci-gate-parity: evaluator constant must be a tuple: {name}"]
    if not isinstance(values["APPROVAL_JOB"], str):
        return set(), ["ci-gate-parity: APPROVAL_JOB must be a string"]

    jobs = set(values["BASE_JOBS"] + values["FULL_JOBS"] + values["MAIN_JOBS"])
    jobs.add(values["APPROVAL_JOB"])
    if not all(isinstance(job, str) and job for job in jobs):
        return set(), ["ci-gate-parity: evaluator job names must be non-empty strings"]
    return jobs, []


def check_ci_gate_job_parity(ci: Path, evaluator: Path) -> list[str]:
    if not ci.exists():
        return [f"ci-gate-parity: missing workflow {ci}"]
    expected, errors = evaluator_job_ids(evaluator)
    if errors:
        return errors

    text = ci.read_text(encoding="utf-8")
    jobs_marker = re.search(r"(?m)^jobs:[ \t]*$", text)
    if not jobs_marker:
        return ["ci-gate-parity: workflow has no jobs mapping"]
    workflow_jobs = set(
        re.findall(
            r"(?m)^  ['\"]?([A-Za-z0-9_-]+)['\"]?:[ \t]*$",
            text[jobs_marker.end() :],
        )
    )
    upstream_jobs = workflow_jobs - {"ci-gate"}
    gate = job_block(text, "ci-gate")
    gate_needs = set(re.findall(r"(?m)^      - ([A-Za-z0-9_-]+)[ \t]*$", gate))
    gate_arguments = set(re.findall(r'--job "([A-Za-z0-9_-]+)=', gate))

    comparisons = (
        ("workflow upstream jobs", upstream_jobs),
        ("ci-gate needs", gate_needs),
        ("ci-gate --job arguments", gate_arguments),
    )
    parity_errors: list[str] = []
    for label, actual in comparisons:
        if actual != expected:
            parity_errors.append(
                f"ci-gate-parity: {label} mismatch: "
                f"missing={sorted(expected - actual)} extra={sorted(actual - expected)}"
            )
    if "ci-gate" not in workflow_jobs:
        parity_errors.append("ci-gate-parity: workflow is missing ci-gate")
    return parity_errors


def check_no_self_hosted(workflows_dir: Path) -> list[str]:
    errors: list[str] = []
    for workflow in sorted(workflows_dir.glob("*.y*ml")):
        text = workflow.read_text(encoding="utf-8")
        for match in re.finditer(r"(?m)^[ \t]*runs-on:[ \t]*(.*?)[ \t]*$", text):
            runner = match.group(1).strip('"\'')
            if runner not in ALLOWED_HOSTED_RUNNERS:
                errors.append(
                    "workflow: public repository runner is not in the hosted allowlist: "
                    f"{workflow}: {runner}"
                )
    return errors


def check_required_context(
    *,
    action: Path,
    drift_checker: Path,
    apply_script: Path,
    governance: Path,
    settings_doc: Path,
) -> list[str]:
    checks = (
        (action, "default: CI gate"),
        (drift_checker, 'default="CI gate"'),
        (apply_script, '{"context": "CI gate"}'),
        (governance, "required check: `CI gate`"),
        (settings_doc, "require the single final check `CI gate`"),
    )
    errors: list[str] = []
    for path, token in checks:
        if not path.exists():
            errors.append(f"context: missing file {path}")
            continue
        if token not in path.read_text(encoding="utf-8"):
            errors.append(f"context: {path} missing token: {token}")
    return errors


def check_ruleset_token_contract(action: Path, ci: Path) -> list[str]:
    errors: list[str] = []
    for path in (action, ci):
        if not path.exists():
            errors.append(f"ruleset-token: missing file {path}")
    if errors:
        return errors

    action_text = action.read_text(encoding="utf-8")
    ci_text = ci.read_text(encoding="utf-8")
    for token in (
        "ruleset_token:",
        "RULESET_DRIFT_ERR_TOKEN_MISSING",
        "inputs.run_main_ruleset_drift == 'true' && inputs.ruleset_token == ''",
        "GH_TOKEN: ${{ inputs.ruleset_token }}",
        "tools/ci/check_full_ci_environment.py",
        '--environment full-ci',
    ):
        if token not in action_text:
            errors.append(f"ruleset-token: action missing token: {token}")
    if "ruleset_token: ${{ github.token }}" not in ci_text:
        errors.append("ruleset-token: CI must use the built-in read token")
    if "DEPENDABOT_AUTOMERGE_TOKEN" in action_text or "DEPENDABOT_AUTOMERGE_TOKEN" in ci_text:
        errors.append("ruleset-token: obsolete privileged Dependabot token is forbidden")
    return errors


def check_owner_settings_contract(
    *,
    checker: Path,
    apply_script: Path,
    settings_doc: Path,
) -> list[str]:
    checks = (
        (
            checker,
            (
                "all_external_contributors",
                "--check-owner-only-settings",
                "fork-pr-contributor-approval",
                "/secrets",
                "/variables",
            ),
        ),
        (
            apply_script,
            (
                "approval_policy=all_external_contributors",
                "--check-owner-only-settings",
            ),
        ),
        (
            settings_doc,
            (
                "fork PR workflow approval: `all_external_contributors`",
                "every external contributor",
            ),
        ),
    )
    errors: list[str] = []
    for path, tokens in checks:
        if not path.exists():
            errors.append(f"owner-settings: missing file {path}")
            continue
        text = path.read_text(encoding="utf-8")
        for token in tokens:
            if token not in text:
                errors.append(f"owner-settings: {path} missing token: {token}")
    return errors


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--ci", default=".github/workflows/ci.yml")
    parser.add_argument("--gate-evaluator", default="tools/ci/evaluate_ci_gate.py")
    parser.add_argument("--workflows-dir", default=".github/workflows")
    parser.add_argument("--action", default=".github/actions/python-policy-checks/action.yml")
    parser.add_argument("--drift-checker", default="tools/ci/check_branch_protection_drift.py")
    parser.add_argument("--apply-script", default="tools/github/apply_branch_protection.sh")
    parser.add_argument("--full-ci-checker", default="tools/ci/check_full_ci_environment.py")
    parser.add_argument(
        "--full-ci-apply-script",
        default="tools/github/apply_full_ci_environment.sh",
    )
    parser.add_argument("--governance", default="GOVERNANCE.md")
    parser.add_argument("--settings-doc", default="docs/human/repository-settings.md")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    errors = [
        *check_ci_workflow(Path(args.ci)),
        *check_ci_gate_job_parity(Path(args.ci), Path(args.gate_evaluator)),
        *check_no_self_hosted(Path(args.workflows_dir)),
        *check_ruleset_token_contract(Path(args.action), Path(args.ci)),
        *check_owner_settings_contract(
            checker=Path(args.full_ci_checker),
            apply_script=Path(args.full_ci_apply_script),
            settings_doc=Path(args.settings_doc),
        ),
        *check_required_context(
            action=Path(args.action),
            drift_checker=Path(args.drift_checker),
            apply_script=Path(args.apply_script),
            governance=Path(args.governance),
            settings_doc=Path(args.settings_doc),
        ),
    ]
    if errors:
        print("CI economy policy check failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("CI economy policy check: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
