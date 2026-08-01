#!/usr/bin/env python3
"""Tests for the public-repository CI economy policy guard."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from tools.ci import check_ci_economy_policy as policy


GOOD_CI = """\
on:
  pull_request:
    types: [opened, reopened, synchronize]
  workflow_dispatch:
concurrency:
  group: ${{ github.event_name == 'pull_request' && format('ci-pr-{0}', github.event.pull_request.number) || format('ci-run-{0}', github.run_id) }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
permissions:
  pull-requests: read
env:
  CI_COMMIT_SHA: ${{ github.event_name == 'pull_request' && github.event.pull_request.head.sha || github.sha }}
jobs:
  scope:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@0000000000000000000000000000000000000000
        with:
          persist-credentials: false
      - env:
          GH_TOKEN: ${{ github.token }}
          PR_CHANGED_FILES: ${{ github.event.pull_request.changed_files }}
        run: |
          gh api --paginate --slurp endpoint
          python3 tools/ci/classify_ci_scope.py
          --expected-count "$PR_CHANGED_FILES"
          ruleset_token: ${{ github.token }}
  full-ci-approval:
    name: Approve full CI
    needs: [scope, python-tooling, capid-csprng-audit, rust-core, ts-c01, ts-full, wasm-smoke]
    if: >-
      always() &&
      github.event_name == 'pull_request' &&
      needs.scope.result == 'success' &&
      needs.scope.outputs.full_required == 'true' &&
      needs.python-tooling.result == 'success' &&
      needs.capid-csprng-audit.result == 'success' &&
      needs.rust-core.result == 'success' &&
      needs.ts-c01.result == 'success' &&
      needs.ts-full.result == 'success' &&
      needs.wasm-smoke.result == 'success'
    permissions: {}
    environment:
      name: full-ci
      deployment: false
    runs-on: ubuntu-latest
  sdk-platform:
    needs: [scope, full-ci-approval]
    if: >-
      always() &&
      needs.scope.result == 'success' &&
      (
        github.event_name != 'pull_request' ||
        (
          needs.scope.outputs.full_required == 'true' &&
          needs.full-ci-approval.result == 'success'
        )
      )
    runs-on: macos-15
  evidence-bundle:
    if: >-
      always() &&
      needs.sdk-platform.result == 'success'
    runs-on: ubuntu-latest
  fuzz-smoke:
    if: needs.scope.result == 'success' && github.event_name != 'pull_request'
    runs-on: ubuntu-latest
  verify-script-smoke:
    if: needs.scope.result == 'success' && github.event_name != 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@0000000000000000000000000000000000000000
        with:
          persist-credentials: false
  upload-proof:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/upload-artifact@0000000000000000000000000000000000000000
        with:
          path: proof
          retention-days: 14
  ci-gate:
    name: CI gate
    if: always()
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@0000000000000000000000000000000000000000
        with:
          persist-credentials: false
      - env:
          FULL_REQUIRED: ${{ needs.scope.outputs.full_required }}
        run: |
          python3 tools/ci/evaluate_ci_gate.py \\
            --full-required "${FULL_REQUIRED}" \\
            --job "full-ci-approval=${{ needs.full-ci-approval.result }}" \\
            --job "evidence-bundle=${{ needs.evidence-bundle.result }}"
"""


class CIEconomyPolicyTests(unittest.TestCase):
    def test_good_workflow_is_accepted(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "ci.yml"
            path.write_text(GOOD_CI, encoding="utf-8")
            self.assertEqual([], policy.check_ci_workflow(path))

    def test_live_gate_job_sets_match_the_evaluator(self) -> None:
        self.assertEqual(
            [],
            policy.check_ci_gate_job_parity(
                Path(".github/workflows/ci.yml"),
                Path("tools/ci/evaluate_ci_gate.py"),
            ),
        )

    def test_new_workflow_job_forgotten_by_gate_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "ci.yml"
            current = Path(".github/workflows/ci.yml").read_text(encoding="utf-8")
            path.write_text(
                current.replace(
                    "  ci-gate:\n",
                    "  future-unreviewed-job:\n    runs-on: ubuntu-latest\n\n  ci-gate:\n",
                    1,
                ),
                encoding="utf-8",
            )
            errors = policy.check_ci_gate_job_parity(
                path,
                Path("tools/ci/evaluate_ci_gate.py"),
            )
            self.assertTrue(any("workflow upstream jobs mismatch" in error for error in errors))

    def test_self_hosted_runner_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            workflow = root / "unsafe.yml"
            workflow.write_text("runs-on: [self-hosted, grain]\n", encoding="utf-8")
            self.assertTrue(policy.check_no_self_hosted(root))

    def test_custom_runner_label_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            workflow = root / "unsafe.yml"
            workflow.write_text("runs-on: grain-private-macos\n", encoding="utf-8")
            self.assertTrue(policy.check_no_self_hosted(root))

    def test_block_form_runner_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            workflow = root / "unsafe.yml"
            workflow.write_text(
                "runs-on:\n  group: private\n  labels: [self-hosted]\n",
                encoding="utf-8",
            )
            self.assertTrue(policy.check_no_self_hosted(root))

    def test_self_hosted_word_in_comment_does_not_create_a_false_positive(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            workflow = root / "renamed.yml"
            workflow.write_text(
                "# Never add self-hosted runners to this public workflow.\n"
                "runs-on: ubuntu-latest\n",
                encoding="utf-8",
            )
            self.assertEqual([], policy.check_no_self_hosted(root))

    def test_missing_concurrency_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "ci.yml"
            path.write_text(
                GOOD_CI.replace(
                    "  cancel-in-progress: ${{ github.event_name == 'pull_request' }}",
                    "  cancel-in-progress: false",
                ),
                encoding="utf-8",
            )
            self.assertTrue(any("cancel-in-progress" in error for error in policy.check_ci_workflow(path)))

    def test_shared_non_pr_concurrency_group_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "ci.yml"
            path.write_text(
                GOOD_CI.replace(
                    "format('ci-run-{0}', github.run_id)",
                    "format('ci-main-{0}', github.ref)",
                ),
                encoding="utf-8",
            )
            self.assertTrue(any("group:" in error for error in policy.check_ci_workflow(path)))

    def test_mac_job_without_explicit_approval_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "ci.yml"
            path.write_text(
                GOOD_CI.replace(
                    "          needs.full-ci-approval.result == 'success'\n",
                    "          true\n",
                    1,
                ),
                encoding="utf-8",
            )
            self.assertTrue(any("sdk-platform" in error for error in policy.check_ci_workflow(path)))

    def test_mac_job_without_automatic_non_pr_path_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "ci.yml"
            path.write_text(
                GOOD_CI.replace("        github.event_name != 'pull_request' ||\n", "", 1),
                encoding="utf-8",
            )
            self.assertTrue(any("sdk-platform" in error for error in policy.check_ci_workflow(path)))

    def test_approval_job_must_be_pr_only(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "ci.yml"
            path.write_text(
                GOOD_CI.replace("      github.event_name == 'pull_request' &&\n", "", 1),
                encoding="utf-8",
            )
            self.assertTrue(any("full-ci-approval" in error for error in policy.check_ci_workflow(path)))

    def test_missing_protected_environment_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "ci.yml"
            path.write_text(
                GOOD_CI.replace("    environment:\n      name: full-ci\n", "", 1),
                encoding="utf-8",
            )
            self.assertTrue(any("full-ci-approval" in error for error in policy.check_ci_workflow(path)))

    def test_approval_without_successful_base_graph_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "ci.yml"
            path.write_text(
                GOOD_CI.replace(
                    "    needs: [scope, python-tooling, capid-csprng-audit, rust-core, ts-c01, ts-full, wasm-smoke]\n",
                    "    needs: scope\n",
                    1,
                ),
                encoding="utf-8",
            )
            self.assertTrue(any("full-ci-approval" in error for error in policy.check_ci_workflow(path)))

    def test_approval_job_with_token_or_environment_data_access_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "ci.yml"
            path.write_text(
                GOOD_CI.replace(
                    "    permissions: {}\n",
                    "    permissions:\n      contents: read\n    steps:\n      - run: echo ${{ secrets.CI_SECRET }}\n",
                    1,
                ),
                encoding="utf-8",
            )
            errors = policy.check_ci_workflow(path)
            self.assertTrue(any("full-ci-approval" in error for error in errors))

    def test_gate_without_always_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "ci.yml"
            path.write_text(
                GOOD_CI.replace("  ci-gate:\n    name: CI gate\n    if: always()", "  ci-gate:\n    name: CI gate"),
                encoding="utf-8",
            )
            self.assertTrue(any("ci-gate" in error for error in policy.check_ci_workflow(path)))

    def test_new_read_only_checkouts_must_not_persist_credentials(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "ci.yml"
            path.write_text(
                GOOD_CI.replace("          persist-credentials: false\n", "", 1),
                encoding="utf-8",
            )
            self.assertTrue(
                any("credential persistence" in error for error in policy.check_ci_workflow(path))
            )

    def test_scope_output_must_reach_shell_through_environment(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "ci.yml"
            path.write_text(
                GOOD_CI.replace(
                    '--full-required "${FULL_REQUIRED}"',
                    '--full-required "${{ needs.scope.outputs.full_required }}"',
                    1,
                ),
                encoding="utf-8",
            )
            self.assertTrue(
                any("interpolated directly" in error for error in policy.check_ci_workflow(path))
            )

    def test_required_context_mismatch_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            files = {
                "action": "default: CI gate\n",
                "drift": 'default="CI gate"\n',
                "apply": '{"context": "old"}\n',
                "governance": "required check: `CI gate`\n",
                "settings": "require the single final check `CI gate`\n",
            }
            paths: dict[str, Path] = {}
            for name, text in files.items():
                paths[name] = root / name
                paths[name].write_text(text, encoding="utf-8")
            errors = policy.check_required_context(
                action=paths["action"],
                drift_checker=paths["drift"],
                apply_script=paths["apply"],
                governance=paths["governance"],
                settings_doc=paths["settings"],
            )
            self.assertTrue(any("apply" in error for error in errors))

    def test_obsolete_dependabot_token_is_rejected_for_ruleset_drift(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            action = root / "action.yml"
            ci = root / "ci.yml"
            action.write_text("ruleset_token:\nDEPENDABOT_AUTOMERGE_TOKEN\n", encoding="utf-8")
            ci.write_text("ruleset_token: ${{ github.token }}\n", encoding="utf-8")
            errors = policy.check_ruleset_token_contract(action, ci)
            self.assertTrue(any("obsolete privileged" in error for error in errors))

    def test_missing_ruleset_contract_file_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            missing_action = root / "missing-action.yml"
            ci = root / "ci.yml"
            ci.write_text("ruleset_token: ${{ github.token }}\n", encoding="utf-8")
            errors = policy.check_ruleset_token_contract(missing_action, ci)
            self.assertTrue(any("missing file" in error for error in errors))

    def test_owner_only_setting_drift_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            checker = root / "checker.py"
            apply_script = root / "apply.sh"
            settings = root / "settings.md"
            checker.write_text(
                "all_external_contributors --check-owner-only-settings "
                "fork-pr-contributor-approval /secrets /variables\n",
                encoding="utf-8",
            )
            apply_script.write_text(
                "approval_policy=first_time_contributors --check-owner-only-settings\n",
                encoding="utf-8",
            )
            settings.write_text(
                "fork PR workflow approval: `all_external_contributors`; every external contributor\n",
                encoding="utf-8",
            )
            errors = policy.check_owner_settings_contract(
                checker=checker,
                apply_script=apply_script,
                settings_doc=settings,
            )
            self.assertTrue(any("approval_policy=all_external_contributors" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
