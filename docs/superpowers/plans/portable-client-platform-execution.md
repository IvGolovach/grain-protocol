# Portable Client Platform Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Grain as a portable client platform where iOS, Android, WASM, glasses, robots, and future devices use generated SDKs over one strict Rust client core.

**Architecture:** Protocol semantics stay in `core/rust/grain-core`. Developer-facing workflows live in `core/rust/grain-client-core`. Generated Swift, Kotlin, WASM, and future device SDKs bind workflow APIs, while reference apps stay thin and never own QR, COSE, CBOR, trust, or persistence correctness.

**Tech Stack:** Rust, UniFFI-compatible FFI surfaces, Swift Package Manager, Kotlin/JVM or Android Gradle smoke harness, WASM/mobile-web bindings, existing Grain protocol conformance vectors, SDK workflow fixtures, GitHub PR/CI/review gates.

---

## Non-Negotiable Rules

- Work in a fresh branch or worktree from current `origin/main` for every PR.
- Before editing, run `git status --porcelain=v1 --untracked-files=all`.
- Before every PR, re-open this file and confirm the next unchecked item.
- After every PR merge, update this file in the next PR with PR URL, merge SHA, local validation, remote CI result, review result, and any split decisions.
- Fix actionable CI/review feedback in the same PR when it belongs to that PR scope.
- Split an extra PR whenever one PR would mix generated-code churn, runtime logic, platform package work, CI/evidence policy, or protocol-visible semantics.
- Do not merge until required GitHub CI is green and required review conversations are resolved.
- Keep every PR narrow enough that `main` is green after merge.

## Baseline Already Completed

| Item | Evidence |
| --- | --- |
| Portable Rust client-core exists | PR #25 |
| `scan_preview(qr_string, trust_pub_b64)` exists | `core/rust/grain-client-core/src/lib.rs` |
| Preview statuses are implemented | `Verified`, `Untrusted`, `Rejected` |
| Explicit trust and diagnostics are documented | ADR 0004, SDK docs |
| PR #25 post-merge CI passed | `origin/main` `4502264f2e6bef377e1660acf675814a35d556ac` |

## Seven Product Phases

| Phase | Product Outcome | Planned PRs |
| --- | --- | --- |
| 1 | Generated SDK boundary direction is executable | PR 1, PR 2, PR 5, PR 6, PR 7, PR 8 |
| 2 | Client workflow conformance exists | PR 1, PR 2, PR 6, PR 7, PR 8 |
| 3 | `scan_accept` and atomic local store exist | PR 3a, PR 3b |
| 4 | Platform storage and trust adapters are defined | PR 4 |
| 5 | Reference scanner clients exist | PR 9a, PR 9b |
| 6 | Pairing, identity, sync, device lifecycle exist | PR 10 |
| 7 | Developer experience and release packaging are complete | PR 11 |

## PR Tracking Table

| Order | PR Scope | Status | Branch | PR | Merge SHA | Local Validation | Remote CI / Review |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | Persistent execution tracker | Merged | `codex/portable-client-platform-plan` | #26 | `e010d9a1349498a70a2ae02e2519d0b0e502e28a` | `python3 tools/check_llm_docs.py`; `python3 tools/ci/check_docs_links.py`; `python3 tools/ci/check_docs_flow.py`; `git diff --check`; `git diff --cached --check`; `scripts/ledger/check`; `scripts/ledger/check --history --base origin/main` | PR CI passed on final SHA `437890e5b792098fbe770d22c57a5680f577936f`; Greptile safe to merge; CodeRabbit PASS; post-merge `main` CI run `25360950306` passed |
| 1 | Client workflow contract and scan-preview fixtures | Merged | `codex/client-workflow-contract-fixtures` | #27 | `f3d68bcd872ac8468b303ffcdf57544f0b80e61e` | `workflow fixture refs`; `python3 tools/check_llm_docs.py`; `python3 tools/check_spec_drift.py`; `python3 tools/ci/check_docs_links.py`; `python3 tools/ci/check_docs_flow.py`; `python3 tools/ci/check_codeowners_coverage.py`; `git diff --check`; `git diff --cached --check`; `scripts/ledger/check`; `scripts/ledger/check --history --base origin/main` | PR CI passed on final SHA `58ab443674548abe0f6ca3a8341825a140107e69`; Greptile final review safe to merge; CodeRabbit SUCCESS; post-merge `main` CI run `25362169893` passed |
| 2 | Rust client workflow fixture runner | Merged | `codex/client-workflow-fixture-runner` | #28 | `71d9b3197bb048ff089bc69cbb2f43fc2411d43f` | `python3 tools/ci/check_client_workflow_fixtures.py`; `cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core`; `python3 tools/check_llm_docs.py`; `python3 tools/check_spec_drift.py`; `python3 tools/ci/check_docs_links.py`; `python3 tools/ci/check_docs_flow.py`; `python3 tools/ci/check_codeowners_coverage.py`; `git diff --check`; `git diff --cached --check`; `scripts/ledger/check`; `scripts/ledger/check --history --base origin/main` | PR CI passed on final SHA `6ab18cd6e90004563f39ad5e8ae3405c6b0d9ce3`; Greptile final review safe to merge; CodeRabbit SUCCESS; post-merge `main` CI run `25364160258` passed |
| 3a | `scan_accept_prepare`, deterministic ID, module boundaries | Merged | `codex/scan-accept-prepare` | #29 | `1f7c6debca15daea89d40b47ac5977a221cc8081` | `cargo fmt --manifest-path core/rust/Cargo.toml -p grain-client-core --check`; `cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core`; `cargo test --manifest-path core/rust/Cargo.toml --workspace`; `python3 tools/ci/check_client_workflow_fixtures.py`; `python3 tools/check_llm_docs.py`; `python3 tools/check_spec_drift.py`; `python3 tools/ci/check_docs_links.py`; `python3 tools/ci/check_docs_flow.py`; `python3 tools/ci/check_codeowners_coverage.py`; `python3 tools/ci/check_sdk_no_network.py`; `git diff --check`; `git diff --cached --check`; `scripts/ledger/check`; `scripts/ledger/check --history --base origin/main` | PR CI passed on final SHA `aecb4b68012322ccc1edf867170aa31273035940`; Greptile P2 findings fixed and threads resolved, rerun skipped by org usage limit; CodeRabbit PASS; post-merge `main` CI run `25365199685` passed |
| 3b | `scan_accept`, atomic store abstraction, memory store | Merged | `codex/scan-accept-store` | #30 | `952df09380851508c93f0ca9194885bb688af44a` | `cargo fmt --manifest-path core/rust/Cargo.toml -p grain-client-core --check`; `cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core`; `cargo test --manifest-path core/rust/Cargo.toml --workspace`; `python3 tools/ci/check_client_workflow_fixtures.py`; `python3 tools/check_llm_docs.py`; `python3 tools/check_spec_drift.py`; `python3 tools/ci/check_docs_links.py`; `python3 tools/ci/check_docs_flow.py`; `python3 tools/ci/check_codeowners_coverage.py`; `python3 tools/ci/check_sdk_no_network.py`; `git diff --check`; `git diff --cached --check`; `scripts/ledger/check`; `scripts/ledger/check --history --base origin/main` | PR CI passed on final SHA `1e2a029bc6fffe4555405a20d6e906cd44e480e1`; CodeRabbit status SUCCESS but generated review was rate-limited/skipped; Greptile was manually requested and did not return a review; post-merge `main` CI run `25366301749` passed |
| 4 | Storage/trust adapter contracts and FFI-safe DTO boundaries | Merged | `codex/platform-adapter-contracts` | #31 | `3a06ff93cf55e8bf1f72ed3d335edb9077fcda67` | Initial: `cargo fmt --manifest-path core/rust/Cargo.toml -p grain-client-core --check`; `cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core`; `cargo test --manifest-path core/rust/Cargo.toml --workspace`; `python3 tools/ci/check_client_workflow_fixtures.py`; docs/spec/codeowners/no-network checks; diff/ledger checks. Final correction: `cargo fmt --manifest-path core/rust/Cargo.toml -p grain-client-core --check`; `cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core`; `python3 tools/ci/check_client_workflow_fixtures.py`; diff/ledger checks | PR CI passed on final SHA `a1a7e3b41945ff92f917aa0eac7fc49e9f6df4e0`; CodeRabbit empty-anchor finding fixed and thread resolved; CodeRabbit final status SUCCESS/review skipped on amended SHA; Greptile manually requested and did not return a review before merge readiness; post-merge `main` CI run `25368105295` passed |
| 5 | UniFFI/generation harness over stable client-core facade | Merged | `codex/uniffi-binding-harness` | #32 | `0d1817e6c26690f0ba2ba16029abe32c15241b67` | `cargo fmt --manifest-path core/rust/Cargo.toml -p grain-client-core -p uniffi-bindgen --check`; `cargo build --manifest-path core/rust/Cargo.toml -p grain-client-core`; `cargo build --manifest-path core/rust/Cargo.toml -p uniffi-bindgen`; `cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core`; `cargo test --manifest-path core/rust/Cargo.toml --workspace`; `scripts/sdk/check_generated_bindings.sh`; `python3 tools/ci/check_client_workflow_fixtures.py`; docs/spec/codeowners/no-network checks; `git diff --check`; `git diff --cached --check`; `scripts/ledger/check`; `scripts/ledger/check --history --base origin/main` | PR CI passed on final SHA `5430a975e310e63b3575e8406202b2859749de51`; CodeRabbit status SUCCESS but generated review was rate-limited/skipped; Greptile was manually requested and did not return a review/comment before merge readiness; post-merge `main` CI run `25369151339` passed |
| 6 | Swift package over generated client workflow API | Merged | `codex/swift-generated-client-sdk` | #33 | `ef01e4cc22cca169bf5cdf921cdfe1f3a390e15e` | `scripts/sdk/check_swift_package.sh`; `cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core`; `scripts/sdk/check_generated_bindings.sh`; `python3 tools/ci/check_client_workflow_fixtures.py`; docs/spec/codeowners/no-network checks; `git diff --check`; `git diff --cached --check`; `scripts/ledger/check`; `scripts/ledger/check --history --base origin/main` | Required PR checks passed on final SHA `b14feb81272b541f94660cbeb1b60758b70ee07a`; observed non-required `ts-c01`, `ts-full`, and `wasm-smoke` passed; CodeRabbit stayed pending/non-required with no review threads; Greptile was manually requested and did not return a review/comment before merge readiness; post-merge `main` CI run `25370425567` passed |
| 7 | Kotlin package over generated client workflow API | Merged | `codex/kotlin-generated-client-sdk` | #34 | `eb1bed9615006c82f179ed46b8ee1400a0673275` | `JAVA_HOME`/`PATH` set to an arm64 JDK with `SDK_KOTLIN_GRADLE_OFFLINE=1 scripts/sdk/check_kotlin_package.sh`; `cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core`; `scripts/sdk/check_generated_bindings.sh`; `python3 tools/ci/check_client_workflow_fixtures.py`; docs/spec/codeowners/no-network checks; `git diff --check`; `git diff --cached --check`; `scripts/ledger/check`; `scripts/ledger/check --history --base origin/main` | PR CI run `25372064355` passed on final SHA `07f93c3449b6d9675df1ffa2af3bdbe8f193649c`; CodeRabbit context SUCCESS but generated review was rate-limited; Greptile was manually requested and did not return a review/comment before merge readiness; post-merge `main` CI run `25372380102` passed |
| 8 | WASM/mobile-web client workflow binding | Merged | `codex/wasm-client-workflow-sdk` | #35 | `1507e25869a6e9911fda4925696478c028c94892` | Initial local proof plus CI correction: `cargo fmt --manifest-path core/rust/Cargo.toml -p grain-client-core -p grain-client-wasm --check`; `cargo check --manifest-path core/rust/Cargo.toml -p grain-client-core --no-default-features`; `cargo check --manifest-path core/rust/Cargo.toml -p grain-client-wasm`; `cargo tree --manifest-path core/rust/Cargo.toml -p grain-client-wasm --target wasm32-wasip1 -e normal`; `npm --prefix sdk/wasm run check`; `cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core`; `cargo test --manifest-path core/rust/Cargo.toml --workspace`; `scripts/sdk/check_generated_bindings.sh`; fixture/docs/spec/workflow/codeowners/no-network checks; `git diff --check`; `scripts/ledger/check`; `scripts/ledger/check --history --base origin/main`. Full `scripts/sdk/check_wasm_package.sh` requires `wasm32-wasip1` locally and was proven by required remote `wasm-smoke`. | PR CI run `25374354540` passed on final SHA `3022577dccc24c78586fd4df570314376dec868c`; CodeRabbit findings fixed and threads resolved/outdated; Greptile was manually requested and did not return a review/comment before merge readiness; post-merge `main` CI run `25374545310` passed |
| 9a | Reference scanner shells | Merged | `codex/reference-scanner-shells` | #36 | `f45bd494652e9fc65da69d455ed43865f5b3bfac` | `scripts/sdk/check_scanner_examples.sh`; `scripts/sdk/check_swift_package.sh`; `scripts/sdk/check_kotlin_package.sh`; `npm --prefix sdk/wasm run check`; `cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core`; `scripts/sdk/check_generated_bindings.sh`; fixture/docs/spec/workflow/codeowners/no-network checks; `git diff --check`; `git diff --cached --check`; `scripts/ledger/check`; `scripts/ledger/check --history --base origin/main` | PR CI run `25375665431` passed on final SHA `cca5fd1b0608f2a6e3ec562c2b163288559f1975`; CodeRabbit status SUCCESS but generated review was rate-limited with no actionable threads; Greptile was manually requested and did not return a review/comment before merge readiness; post-merge `main` CI run `25375922032` passed |
| 9b | Camera adapters for scanner shells | Merged | `codex/scanner-camera-adapters` | #37 | `465e0a3fcca54a3fd6a691f2b1c2cb95b674ef54` | `scripts/sdk/check_scanner_examples.sh` with arm64 JDK and `SDK_KOTLIN_GRADLE_OFFLINE=1`; fixture/docs/spec/workflow/codeowners/no-network checks; `git diff --check`; `git diff --cached --check`; `scripts/ledger/check`; `scripts/ledger/check --history --base origin/main` | PR CI run `25376799674` passed on final SHA `4f727b225a607cec2a74e0c6d76c50c547f073c0`; CodeRabbit final-SHA status SUCCESS after rate-limit/no actionable threads; Greptile was manually requested twice and did not return a review/comment before merge readiness; post-merge `main` CI run `25377111364` passed |
| 10 | Pairing, identity, sync, and device lifecycle | In progress | `codex/pairing-sync-lifecycle` | #38 |  | `cargo fmt --manifest-path core/rust/Cargo.toml -p grain-client-core -p grain-client-wasm --check`; `cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core`; `cargo test --manifest-path core/rust/Cargo.toml --workspace`; `scripts/sdk/check_generated_bindings.sh`; `scripts/sdk/check_swift_package.sh`; `scripts/sdk/check_kotlin_package.sh`; `scripts/sdk/check_scanner_examples.sh`; `npm --prefix sdk/wasm run check`; fixture/docs/spec/codeowners/no-network checks; `git diff --check`; `scripts/ledger/check`; `scripts/ledger/check --history --base origin/main` | PR #38 CI passed on initial SHA; CodeRabbit review correction in progress; Greptile manually requested |
| 11 | Developer experience, version matrix, release packaging, final certification | Pending |  |  |  |  |  |

### PR Dependencies

- PR 0 through PR 2 are sequential because the tracker, workflow contract, and fixture runner establish the contract surface for every later PR.
- PR 3a depends on PR 2. PR 3b depends on PR 3a because persistence must build on the accepted-scan prepare result.
- PR 4 depends on PR 3b because platform storage and trust contracts need the accepted record and store semantics to be stable.
- PR 5 depends on PR 4 because generated bindings should wrap binding-safe DTOs and adapter contracts, not raw Rust internals.
- PR 6, PR 7, and PR 8 all depend on PR 5 and are independent of each other; they can run in parallel and merge in any order once their shared generated API is stable.
- PR 9a depends on PR 6, PR 7, and PR 8 so the reference scanner shells prove all published SDK lanes.
- PR 9b depends on PR 9a because camera adapters should be thin producers of GR1 strings over already-reviewed shell workflows.
- PR 10 depends on PR 5 and PR 9a because its generated-workflow updates need the binding harness and its `examples/` updates need the scanner shells. It can begin development alongside PR 9b when review capacity allows, but it must not merge before PR 9a is on `main`.
- PR 11 depends on every earlier PR and is the final release/readiness pass.

## Review Log

| PR | Reviewer / Tool | Finding | Decision | Fix / Follow-Up |
| --- | --- | --- | --- | --- |
| #26 | Greptile | Kotlin PR 7 and WASM PR 8 were missing from the Seven Product Phases mapping. | Fix in PR #26. | Added PR 7 and PR 8 to Phase 1 and Phase 2 mapping. |
| #26 | CodeRabbit | PR dependencies were implicit and PR 3 mixed scan workflow logic with store infrastructure. | Fix in PR #26. | Added PR dependency section and split PR 3 into PR 3a and PR 3b. |
| #26 | Greptile | PR 10 file list used prose instead of structured file entries. | Fix in PR #26. | Replaced PR 10 prose with explicit `Create` / `Modify` entries. |
| #26 | Greptile | Split Log missed the PR 3a / PR 3b split and PR 10 dependency on PR 9 was understated. | Fix in PR #26. | Added Split Log row and made PR 10's PR 9 dependency explicit. |
| #26 | Greptile | Split Log insertion point should be PR 3a rather than PR 2. | Fix in PR #26. | Corrected the Split Log row before merge. |
| #27 | Greptile | Workflow `ref` pattern and runner guidance allowed path traversal risk. | Fix in PR #27. | Restricted refs to `conformance/vectors/**` and documented canonicalization / bound-checking. |
| #27 | Greptile | Malformed QR fixture used exact `diag` while source protocol vector uses `diag_contains`. | Fix in PR #27. | Added `diag_contains` workflow expectation and updated fixture `SDK-WF-SCAN-PREVIEW-0003`. |
| #27 | Greptile | `store_mutation` enum needed a planned-extension note. | Fix in PR #27. | Added schema `$comment` explaining the v1 `scan_preview` single-value enum. |
| #27 | Greptile | `cose_b64: present` semantics were unclear for rejected scans. | Fix in PR #27. | Clarified that `present` means QR COSE decode succeeded, not trust verification. |
| #28 | Greptile | Fixture runner should not enforce an exact fixture count. | Fix in PR #28. | Required a non-empty fixture set instead of exact cardinality. |
| #28 | Greptile | Fixture schema should reject unknown object fields. | Fix in PR #28. | Added strict `deny_unknown_fields` parsing for Rust fixture structs. |
| #28 | CodeRabbit | Python fixture checker needed hardened unreadable/invalid JSON and bad-reference diagnostics. | Fix in PR #28. | Added read/parse guards, non-string ref checks, and empty `diag_contains` rejection. |
| #28 | CodeRabbit | Python 3.9-only path helper could break older local lanes. | Fix in PR #28. | Replaced `Path.is_relative_to()` with Python 3.8-compatible parent checks. |
| #29 | Greptile | `ScanAcceptRequest.trust_pub_b64` was optional even though accept preparation requires trust. | Fix in PR #29. | Made the request DTO field non-optional while preserving `scan_accept_prepare(..., Option<&str>)` reject behavior for callers that do not use the DTO. |
| #29 | Greptile | `ScanAcceptStatus::AlreadyAccepted` was public before any producing store path existed. | Fix in PR #29. | Deferred `AlreadyAccepted` until PR 3b adds `scan_accept` and store idempotency. |
| #29 | CodeRabbit | Empty trust strings decoded to empty bytes before COSE verification. | Fix in PR #29. | Rejected empty trust input in `decode_trust_pub_b64` and added preview / accept-prepare tests. |
| #31 | CodeRabbit | Empty trust-anchor input needed explicit adapter coverage. | Fix in PR #31. | Added an empty-anchor contract test and resolved the review thread. |
| #31 | CodeRabbit | Fixture paths and preview DTO intent could be clearer. | Low-risk cleanup in PR #31. | Switched tests to manifest-rooted fixture paths and documented `FfiScanPreviewRequest` intent. |
| #32 | CodeRabbit | Generated review was rate-limited/skipped although status completed successfully. | No code change. | Relied on local proof, required CI, and manual Greptile request before merge. |
| #32 | Greptile | Manual review request did not return a review/comment before merge readiness. | No code change. | Required CI passed on final SHA; post-merge `main` CI passed. |
| #33 | CodeRabbit | GitHub status stayed pending/non-required with no review threads; local CLI review could not run because the API key was invalid or expired. | No code change. | Relied on local proof, required CI, and manual Greptile request before merge. |
| #33 | Greptile | Manual review request did not return a review/comment before merge readiness. | No code change. | Required CI passed on final SHA; post-merge `main` CI passed. |
| #34 | CodeRabbit | Status context succeeded, but generated review comment reported rate limiting. | No code change. | No actionable review threads were present; required CI and post-merge main CI passed. |
| #34 | Greptile | Manual review request did not return a review/comment before merge readiness. | No code change. | Required CI passed on final SHA; post-merge `main` CI passed. |
| #35 | GitHub CI | Initial `wasm-smoke` failed because `grain-client-wasm` compiled `grain-client-core` with the target-side UniFFI runtime, and `uniffi_core` failed under `wasm32-wasip1`. | Fix in PR #35. | Added a default `bindings` feature to `grain-client-core`, gated UniFFI modules/scaffolding behind it, and made `grain-client-wasm` depend on `grain-client-core` with default features disabled. |
| #35 | CodeRabbit | WASM store handles used raw heap pointers, raw-API grep missed snake_case names, response parsing was too permissive, Node loader destructured before validation, and JSON Pointer array indices used permissive `parseInt`. | Fix in PR #35. | Added opaque generated store handles, expanded the raw API guard, made WASM response parsing strict, made `createNodeGrainClient()` validate omitted options, and required strict array-index tokens. |
| #36 | CodeRabbit | Generated review comment was rate-limited although the status context succeeded. | No code change. | No actionable review threads were present; required CI and post-merge `main` CI passed. |
| #36 | Greptile | Manual review request did not return a review/comment before merge readiness. | No code change. | Required CI passed on final SHA; post-merge `main` CI passed. |
| #37 | CodeRabbit | Final-SHA review request was rate-limited, but the CodeRabbit status context completed successfully and no review threads were present. | No code change. | Required CI and post-merge `main` CI passed. |
| #37 | Greptile | Manual review was requested twice and did not return a review/comment before merge readiness. | No code change. | Required CI and post-merge `main` CI passed. |

## Split Log

| Inserted After | Extra PR Scope | Reason | Dependency | Status |
| --- | --- | --- | --- | --- |
| PR 3a | PR 3b: `scan_accept`, atomic store abstraction, memory store | PR 3 mixed scan-workflow logic with store infrastructure in the original plan. | PR 3b depends on PR 3a. | Merged in PR #30 (`952df09380851508c93f0ca9194885bb688af44a`) |
| PR 9a | PR 9b: camera adapters for scanner shells | Camera capture brings AVFoundation, CameraX, browser permissions, QR decoder dependency choice, and device/browser test concerns that should not obscure shell parity review. | PR 9b depends on PR 9a. | Merged in PR #37 (`465e0a3fcca54a3fd6a691f2b1c2cb95b674ef54`) |

---

## PR 0: Persistent Execution Tracker

**Files:**
- Create: `docs/superpowers/plans/portable-client-platform-execution.md`

- [x] **Step 1: Create this tracker**

Write the execution tracker with seven product phases, planned PR splits, update rules, validation rules, review log, and split log.

- [x] **Step 2: Validate tracker-only change**

Run:

```bash
python3 tools/check_llm_docs.py
python3 tools/ci/check_docs_links.py
python3 tools/ci/check_docs_flow.py
git diff --check
scripts/ledger/check
scripts/ledger/check --history --base origin/main
```

Expected: all commands pass.

- [x] **Step 3: Open, review, merge**

Open a PR for the tracker, wait for required CI and review feedback, fix actionable comments, merge, fetch `origin/main`, then start PR 1 from current `origin/main`.

---

## PR 1: Client Workflow Contract And Scan-Preview Fixtures

**Files:**
- Create: `sdk/workflows/README.md`
- Create: `sdk/workflows/contract/client_workflow_v1.md`
- Create: `sdk/workflows/contract/client_workflow_v1.schema.json`
- Create: `sdk/workflows/fixtures/scan-preview/SDK-WF-SCAN-PREVIEW-0001.json`
- Create: `sdk/workflows/fixtures/scan-preview/SDK-WF-SCAN-PREVIEW-0002.json`
- Create: `sdk/workflows/fixtures/scan-preview/SDK-WF-SCAN-PREVIEW-0003.json`
- Create: `sdk/workflows/fixtures/scan-preview/SDK-WF-SCAN-PREVIEW-0004.json`
- Create: `sdk/workflows/fixtures/scan-preview/SDK-WF-SCAN-PREVIEW-0005.json`
- Modify: `docs/llm/SDK_CONFORMANCE.md`
- Modify: `docs/llm/SDK_EDGE_CASES.md`
- Modify: `docs/llm/SDK_FILE_MAP.md`
- Modify: `docs/human/sdk/portable-client-sdk.md`
- Modify: `CHANGELOG.md`
- Modify: this tracker file with PR 0 evidence

- [x] **Step 1: Define the fixture schema**

The schema must distinguish client workflow conformance from protocol conformance. Protocol conformance answers whether bytes and diagnostics obey Grain protocol. Client workflow conformance answers whether generated SDKs expose the same safe app workflow.

Example fixture:

```json
{
  "fixture_id": "SDK-WF-SCAN-PREVIEW-0001",
  "workflow": "scan_preview",
  "strict": true,
  "input": {
    "qr_string_ref": "conformance/vectors/qr/POS-QR-001.json#/input/qr_string",
    "trust_pub_b64_ref": "conformance/vectors/cose/POS-COSE-001.json#/input/pub_b64"
  },
  "expect": {
    "status": "Verified",
    "diag": [],
    "store_mutation": "none"
  },
  "meta": {
    "desc": "Valid scan with explicit trusted public key verifies without mutating client storage."
  }
}
```

- [x] **Step 2: Add five scan-preview fixtures**

Fixtures:

- `SDK-WF-SCAN-PREVIEW-0001`: valid QR + valid trust -> `Verified`, no diagnostics, no store mutation.
- `SDK-WF-SCAN-PREVIEW-0002`: valid QR + no trust -> `Untrusted`, no diagnostics, no store mutation.
- `SDK-WF-SCAN-PREVIEW-0003`: malformed QR -> `Rejected`, `GRAIN_ERR_SCHEMA`, no store mutation.
- `SDK-WF-SCAN-PREVIEW-0004`: valid QR + malformed trust -> `Rejected`, `SDK_ERR_TRANSPORT_VERIFY_TRUST_INVALID`, no store mutation.
- `SDK-WF-SCAN-PREVIEW-0005`: valid QR + wrong trust key -> `Rejected`, `GRAIN_ERR_COSE_PROFILE`, no store mutation.

- [x] **Step 3: Update docs**

Update SDK conformance docs to state that `sdk/workflows/**` is client workflow conformance, not protocol conformance. Do not call Swift/Kotlin protocol-conformant merely because they bind Rust.

- [x] **Step 4: Validate and PR**

Run:

```bash
python3 tools/check_llm_docs.py
python3 tools/check_spec_drift.py
python3 tools/ci/check_docs_links.py
python3 tools/ci/check_docs_flow.py
python3 tools/ci/check_codeowners_coverage.py
git diff --check
scripts/ledger/check
scripts/ledger/check --history --base origin/main
```

---

## PR 2: Rust Client Workflow Fixture Runner

**Files:**
- Create: `core/rust/grain-client-core/tests/client_workflow_fixtures.rs`
- Create: `core/rust/grain-client-core/tests/support/workflow_fixture.rs`
- No change needed: `core/rust/grain-client-core/Cargo.toml` already exposes the required `serde` / `serde_json` dev-dependencies
- Create: `tools/ci/check_client_workflow_fixtures.py`
- Modify: `docs/llm/SDK_CONFORMANCE.md`
- Modify: `docs/llm/SDK_EDGE_CASES.md`
- Modify: `CHANGELOG.md`
- Modify: this tracker file with PR 1 evidence

- [x] **Step 1: Write failing Rust fixture-runner test**

Add a test that loads every `sdk/workflows/fixtures/scan-preview/*.json` file and compares expected status and diagnostics with `grain_client_core::scan_preview()`.

- [x] **Step 2: Implement fixture reference resolver**

Support local JSON pointer references such as:

```text
conformance/vectors/qr/POS-QR-001.json#/input/qr_string
conformance/vectors/cose/POS-COSE-001.json#/input/pub_b64
```

- [x] **Step 3: Add Python fixture lint**

Add `tools/ci/check_client_workflow_fixtures.py` to validate IDs, workflow names, status names, references, and no accidental protocol-runner top-level shape.

- [x] **Step 4: Validate and PR**

Run:

```bash
python3 tools/ci/check_client_workflow_fixtures.py
cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core
python3 tools/check_llm_docs.py
python3 tools/ci/check_docs_links.py
git diff --check
scripts/ledger/check
scripts/ledger/check --history --base origin/main
```

---

## PR 3a: `scan_accept_prepare`, Deterministic ID, Module Boundaries

**Files:**
- Modify: `core/rust/Cargo.lock`
- Modify: `core/rust/grain-client-core/Cargo.toml`
- Modify: `core/rust/grain-client-core/src/lib.rs`
- Create: `core/rust/grain-client-core/src/scan.rs`
- Create: `core/rust/grain-client-core/src/types.rs`
- Create: `core/rust/grain-client-core/src/trust.rs`
- Create: `core/rust/grain-client-core/src/diag.rs`
- Create: `core/rust/grain-client-core/tests/scan_accept_prepare.rs`
- Modify: `core/rust/grain-client-core/tests/scan_preview.rs`
- Modify: `docs/llm/SDK_INVARIANTS.md`
- Modify: `docs/llm/SDK_EDGE_CASES.md`
- Modify: `docs/llm/SDK_CONFORMANCE.md`
- Modify: `docs/llm/SDK_FILE_MAP.md`
- Modify: `docs/human/sdk/architecture.md`
- Modify: `docs/human/sdk/portable-client-sdk.md`
- Modify: `CHANGELOG.md`
- Modify: this tracker file with PR 2 evidence

- [x] **Step 1: Normalize module boundaries**

Move implementation out of `lib.rs` while preserving public API:

```rust
pub use scan::{scan_accept_prepare, scan_preview};
pub use types::{
    AcceptedScan, ScanAccept, ScanAcceptRequest, ScanAcceptStatus, ScanPreview,
    ScanPreviewStatus,
};
```

- [x] **Step 2: Write failing tests for `scan_accept_prepare`**

Required behavior:

- valid QR + valid trust returns `Accepted`.
- accepted record has deterministic `scan_id`.
- `scan_id` is a hash over verified COSE bytes, not a fake CID.
- missing trust rejects with `SDK_ERR_SCAN_ACCEPT_TRUST_REQUIRED`.
- malformed trust rejects with `SDK_ERR_TRANSPORT_VERIFY_TRUST_INVALID`.
- wrong trust rejects with `GRAIN_ERR_COSE_PROFILE`.
- repeated prepare returns the same accepted record.

- [x] **Step 3: Implement `scan_accept_prepare`**

Proposed public shape:

```rust
pub struct ScanAcceptRequest {
    pub qr_string: String,
    pub trust_pub_b64: String,
}

pub enum ScanAcceptStatus {
    Accepted,
    Rejected,
}

pub struct AcceptedScan {
    pub scan_id: String,
    pub cose_b64: String,
    pub trust_pub_b64: String,
}

pub struct ScanAccept {
    pub status: ScanAcceptStatus,
    pub diag: Vec<String>,
    pub accepted: Option<AcceptedScan>,
}
```

`ScanAcceptRequest.trust_pub_b64` is intentionally non-optional for generated DTOs. The function-level `scan_accept_prepare(_, Option<&str>)` remains optional so non-DTO callers can receive the deterministic `SDK_ERR_SCAN_ACCEPT_TRUST_REQUIRED` rejection path described in the #29 Review Log entry and implemented in `core/rust/grain-client-core/src/types.rs`.

- [x] **Step 4: Validate and PR**

Run:

```bash
cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core
python3 tools/check_llm_docs.py
python3 tools/ci/check_sdk_no_network.py
git diff --check
scripts/ledger/check
scripts/ledger/check --history --base origin/main
```

Run `cargo test --manifest-path core/rust/Cargo.toml --workspace` if the module reorganization affects workspace-visible APIs beyond `grain-client-core`.

---

## PR 3b: `scan_accept`, Atomic Store Abstraction, Memory Store

**Files:**
- Modify: `core/rust/grain-client-core/src/diag.rs`
- Modify: `core/rust/grain-client-core/src/lib.rs`
- Modify: `core/rust/grain-client-core/src/scan.rs`
- Modify: `core/rust/grain-client-core/src/types.rs`
- Create: `core/rust/grain-client-core/src/store.rs`
- Create: `core/rust/grain-client-core/src/memory_store.rs`
- Modify: `core/rust/grain-client-core/tests/client_workflow_fixtures.rs`
- Modify: `core/rust/grain-client-core/tests/support/workflow_fixture.rs`
- Create: `core/rust/grain-client-core/tests/scan_accept.rs`
- Create: `core/rust/grain-client-core/tests/store_atomic.rs`
- Modify: `sdk/workflows/README.md`
- Modify: `sdk/workflows/contract/client_workflow_v1.md`
- Modify: `sdk/workflows/contract/client_workflow_v1.schema.json`
- Create: `sdk/workflows/fixtures/scan-accept/SDK-WF-SCAN-ACCEPT-0001.json`
- Create: `sdk/workflows/fixtures/scan-accept/SDK-WF-SCAN-ACCEPT-0002.json`
- Modify: `tools/ci/check_client_workflow_fixtures.py`
- Modify: `docs/llm/SDK_INVARIANTS.md`
- Modify: `docs/llm/SDK_EDGE_CASES.md`
- Modify: `docs/llm/SDK_CONFORMANCE.md`
- Modify: `docs/llm/SDK_FILE_MAP.md`
- Modify: `docs/human/sdk/architecture.md`
- Modify: `docs/human/sdk/portable-client-sdk.md`
- Modify: `CHANGELOG.md`
- Modify: this tracker file with PR 3a evidence

- [x] **Step 1: Write failing atomic-store tests**

Required behavior:

- accepted scan persists and is listable.
- rejected scan writes nothing.
- duplicate same scan is idempotent.
- injected mid-mutation failure rolls back all writes.
- nested atomic calls are rejected or explicitly prevented.

- [x] **Step 2: Implement store and `scan_accept`**

Add `ClientStore`, `MemoryClientStore`, `AcceptedScanRecord`, and store diagnostics under `SDK_ERR_STORE_*`. Mutate only inside `store.atomic(...)`.

- [x] **Step 3: Add scan-accept workflow fixtures**

Fixtures:

- `SDK-WF-SCAN-ACCEPT-0001`: valid QR + valid trust -> `Accepted`, exactly one accepted record persisted.
- `SDK-WF-SCAN-ACCEPT-0002`: rejected scan -> `Rejected`, no store mutation.
- `SDK-WF-SCAN-ACCEPT-0003`: repeated valid QR + valid trust -> `AlreadyAccepted`, still exactly one accepted record.

- [x] **Step 4: Validate and PR**

Run:

```bash
cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core
cargo test --manifest-path core/rust/Cargo.toml --workspace
python3 tools/ci/check_client_workflow_fixtures.py
python3 tools/check_llm_docs.py
python3 tools/ci/check_sdk_no_network.py
git diff --check
scripts/ledger/check
scripts/ledger/check --history --base origin/main
```

Run `./scripts/verify --out-dir artifacts/dev-verify-scan-accept` if the diff touches shared CI/docs/runtime paths beyond `grain-client-core`.

---

## PR 4: Storage / Trust Adapter Contracts And FFI-Safe DTOs

**Files:**
- Create: `core/rust/grain-client-core/src/platform/mod.rs`
- Create: `core/rust/grain-client-core/src/platform/storage.rs`
- Create: `core/rust/grain-client-core/src/platform/trust.rs`
- Create: `core/rust/grain-client-core/src/ffi_types.rs`
- Modify: `core/rust/grain-client-core/src/diag.rs`
- Modify: `core/rust/grain-client-core/src/lib.rs`
- Modify: `core/rust/grain-client-core/src/store.rs`
- Create: `core/rust/grain-client-core/tests/storage_contract.rs`
- Create: `core/rust/grain-client-core/tests/trust_adapter_contract.rs`
- Create: `core/rust/grain-client-core/tests/platform_scan_accept.rs`
- Modify: `core/rust/grain-client-core/README.md`
- Modify: `docs/human/sdk/portable-client-sdk.md`
- Modify: `docs/human/sdk/cross-lang-bridge.md`
- Modify: `docs/human/sdk/architecture.md`
- Modify: `docs/llm/SDK_FILE_MAP.md`
- Modify: `docs/llm/SDK_CONFORMANCE.md`
- Modify: `docs/llm/SDK_INVARIANTS.md`
- Modify: `docs/llm/SDK_EDGE_CASES.md`
- Modify: `docs/llm/CHANGE_POLICY.md`
- Modify: `CHANGELOG.md`
- Modify: this tracker file with PR 3b evidence

- [x] **Step 1: Define platform-neutral storage and trust traits**

Rules:

- no hidden trust fallback;
- no network trust lookup in core;
- no platform Keychain, Keystore, SQLite, or IndexedDB APIs in Rust core;
- trust provider returns explicit material or none.

- [x] **Step 2: Add reusable adapter contract tests**

Test deterministic ordering, idempotent re-put, rollback at repository boundary, no anchor, malformed anchor, and valid anchor.

- [x] **Step 3: Add binding-safe DTO types**

Keep binding-facing values boring: strings, vectors of strings, optional strings, and no Rust generics or borrowed lifetimes in DTOs.

- [x] **Step 4: Validate and PR**

Run focused Rust tests, docs checks, ledger checks, and `git diff --check`.

---

## PR 5: UniFFI / Generated Binding Harness

**Files:**
- Modify: `core/rust/grain-client-core/Cargo.toml`
- Create: `core/rust/grain-client-core/build.rs`
- Create: `core/rust/grain-client-core/src/grain_client_core.udl`
- Create: `core/rust/uniffi-bindgen/Cargo.toml`
- Create: `core/rust/uniffi-bindgen/src/main.rs`
- Modify: `core/rust/Cargo.toml`
- Create: `scripts/sdk/generate_client_bindings.sh`
- Create: `scripts/sdk/check_generated_bindings.sh`
- Create: `sdk/generated/README.md`
- Modify: `core/rust/grain-client-core/src/lib.rs`
- Create: `core/rust/grain-client-core/src/binding_api.rs`
- Create: `core/rust/grain-client-core/tests/binding_api.rs`
- Modify: `core/rust/Cargo.lock`
- Modify: `core/rust/README.md`
- Modify: `core/rust/grain-client-core/README.md`
- Modify: `sdk/README.md`
- Modify: `docs/human/sdk/cross-lang-bridge.md`
- Modify: `docs/human/sdk/architecture.md`
- Modify: `docs/llm/SDK_CONFORMANCE.md`
- Modify: `docs/llm/SDK_INVARIANTS.md`
- Modify: `docs/llm/SDK_EDGE_CASES.md`
- Modify: `docs/llm/SDK_FILE_MAP.md`
- Modify: `docs/llm/CHANGE_POLICY.md`
- Modify: `docs/human/sdk/portable-client-sdk.md`
- Modify: `CHANGELOG.md`
- Modify: this tracker file with PR 4 evidence

- [x] **Step 1: Add FFI-shape and wrapper tests**

Test binding-safe scan preview, scan accept preparation, rejected record shape, and reference memory-store idempotency through the wrapper surface.

- [x] **Step 2: Add UniFFI-compatible wrapper**

Expose workflow APIs only:

- top-level `scan_preview`
- top-level `scan_accept_prepare`
- reference memory-store `scan_accept`
- reference memory-store `list_accepted_scans`
- later `export_bundle`

Do not expose raw `qr_decode_gr1`, `cose_verify`, `dagcbor_validate`, or protocol runner operations as app APIs.

- [x] **Step 3: Add deterministic generation scripts**

Generation must be reproducible and must not leave untracked generated junk after checks.

- [x] **Step 4: Validate and PR**

Run:

```bash
cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core
cargo build --manifest-path core/rust/Cargo.toml -p grain-client-core
scripts/sdk/check_generated_bindings.sh
python3 tools/check_llm_docs.py
git diff --check
scripts/ledger/check
scripts/ledger/check --history --base origin/main
```

---

## PR 6: Swift Package Over Generated Client Workflow API

**Files:**
- Modify: `.gitignore`
- Create: `scripts/sdk/sync_swift_bindings.sh`
- Create: `scripts/sdk/check_swift_package.sh`
- Create: `sdk/swift/Package.swift`
- Create: `sdk/swift/Sources/GrainClient/GrainClient.swift`
- Create: `sdk/swift/Sources/GrainClientFFI/grain_client_core.swift`
- Create: `sdk/swift/Sources/grain_client_coreFFI/include/grain_client_coreFFI.h`
- Create: `sdk/swift/Sources/grain_client_coreFFI/shim.c`
- Create: `sdk/swift/Sources/GrainClientFixtureRunner/main.swift`
- Create: `sdk/swift/README.md`
- Modify: `sdk/README.md`
- Modify: `adr/sdk/0004-portable-client-core-generated-platform-sdks.md`
- Modify: `docs/human/sdk/architecture.md`
- Modify: `docs/human/sdk/cross-lang-bridge.md`
- Modify: `docs/human/sdk/portable-client-sdk.md`
- Modify: `docs/llm/SDK_CONFORMANCE.md`
- Modify: `docs/llm/SDK_EDGE_CASES.md`
- Modify: `docs/llm/SDK_FILE_MAP.md`
- Modify: `docs/llm/SDK_INVARIANTS.md`
- Modify: `CHANGELOG.md`
- Modify: this tracker file with PR 5 evidence

- [x] **Step 1: Add Swift smoke tests against client workflow fixtures**

Swift package verification must call generated workflow APIs and pass the same `sdk/workflows` fixtures as Rust. In the current local Swift toolchain, `XCTest` and Swift Testing are unavailable, so this PR uses the `GrainClientFixtureRunner` executable as the deterministic package test harness.

- [x] **Step 2: Add copy-paste Swift example**

Example must show preview and accept, not QR/COSE internals.

- [x] **Step 3: Validate and PR**

Run:

```bash
scripts/sdk/check_swift_package.sh
cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core
scripts/sdk/check_generated_bindings.sh
python3 tools/ci/check_client_workflow_fixtures.py
python3 tools/check_llm_docs.py
python3 tools/check_spec_drift.py
python3 tools/ci/check_docs_links.py
python3 tools/ci/check_docs_flow.py
python3 tools/ci/check_codeowners_coverage.py
python3 tools/ci/check_sdk_no_network.py
git diff --check
scripts/ledger/check
scripts/ledger/check --history --base origin/main
```

If SwiftPM is unavailable locally, add and run the strongest deterministic source/generation check, then rely on required CI when configured.

---

## PR 7: Kotlin Package Over Generated Client Workflow API

**Files:**
- Create: `sdk/kotlin/settings.gradle.kts`
- Create: `sdk/kotlin/build.gradle.kts`
- Create: `scripts/sdk/sync_kotlin_bindings.sh`
- Create: `scripts/sdk/check_kotlin_package.sh`
- Create: `sdk/kotlin/gradlew`
- Create: `sdk/kotlin/src/main/kotlin/dev/grain/GrainClient.kt`
- Create: `sdk/kotlin/src/main/kotlin/uniffi/grain_client_core/grain_client_core.kt`
- Create: `sdk/kotlin/src/test/kotlin/dev/grain/fixture/GrainClientFixtureRunner.kt`
- Create: `sdk/kotlin/README.md`
- Modify: `.gitignore`
- Modify: `sdk/README.md`
- Modify: `adr/sdk/0004-portable-client-core-generated-platform-sdks.md`
- Modify: `docs/human/sdk/architecture.md`
- Modify: `docs/human/sdk/cross-lang-bridge.md`
- Modify: `docs/human/sdk/portable-client-sdk.md`
- Modify: `docs/llm/SDK_CONFORMANCE.md`
- Modify: `docs/llm/SDK_EDGE_CASES.md`
- Modify: `docs/llm/SDK_FILE_MAP.md`
- Modify: `docs/llm/SDK_INVARIANTS.md`
- Modify: `CHANGELOG.md`
- Modify: this tracker file with PR 6 evidence

- [x] **Step 1: Add Kotlin/JVM smoke tests against client workflow fixtures**

Kotlin tests must call generated workflow APIs and pass the same `sdk/workflows` fixtures as Rust and Swift.

- [x] **Step 2: Add copy-paste Kotlin example**

Example must show preview and accept, not protocol internals.

- [x] **Step 3: Validate and PR**

Run:

```bash
scripts/sdk/check_kotlin_package.sh
cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core
scripts/sdk/check_generated_bindings.sh
python3 tools/ci/check_client_workflow_fixtures.py
python3 tools/check_llm_docs.py
python3 tools/check_spec_drift.py
python3 tools/ci/check_docs_links.py
python3 tools/ci/check_docs_flow.py
python3 tools/ci/check_codeowners_coverage.py
python3 tools/ci/check_sdk_no_network.py
git diff --check
scripts/ledger/check
scripts/ledger/check --history --base origin/main
```

If Gradle tooling is introduced, make the wrapper reproducible and avoid committing generated dependency caches.

---

## PR 8: WASM / Mobile-Web Client Workflow Binding

**Files:**
- Modify: `.github/workflows/ci.yml`
- Modify: `.gitignore`
- Modify: `core/rust/Cargo.toml`
- Modify: `core/rust/Cargo.lock`
- Create: `core/rust/grain-client-wasm/Cargo.toml`
- Create: `core/rust/grain-client-wasm/README.md`
- Create: `core/rust/grain-client-wasm/src/lib.rs`
- Create: `scripts/sdk/check_wasm_package.sh`
- Create: `sdk/wasm/`
- Create: `sdk/wasm/README.md`
- Create: `sdk/wasm/tests/`
- Modify: `sdk/README.md`
- Modify: `core/rust/README.md`
- Modify: `adr/sdk/0004-portable-client-core-generated-platform-sdks.md`
- Modify: `docs/human/sdk/architecture.md`
- Modify: `docs/human/sdk/cross-lang-bridge.md`
- Modify: `docs/human/sdk/portable-client-sdk.md`
- Modify: `docs/llm/SDK_CONFORMANCE.md`
- Modify: `docs/llm/SDK_EDGE_CASES.md`
- Modify: `docs/llm/SDK_FILE_MAP.md`
- Modify: `docs/llm/SDK_INVARIANTS.md`
- Modify: `CHANGELOG.md`
- Modify: this tracker file with PR 7 evidence

- [x] **Step 1: Add client-workflow WASM binding**

Do not reuse `grain-core-wasm` as the product SDK without a clear workflow wrapper. `grain-core-wasm` is a protocol/vector portability lane; this PR needs a client workflow lane.

- [x] **Step 2: Add Node or browser-like smoke test**

Test preview and accept against the shared workflow fixtures.

- [x] **Step 3: Validate and PR**

Run:

```bash
scripts/sdk/check_wasm_package.sh
cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core
scripts/sdk/check_generated_bindings.sh
python3 tools/ci/check_client_workflow_fixtures.py
python3 tools/check_llm_docs.py
python3 tools/check_spec_drift.py
python3 tools/ci/check_docs_links.py
python3 tools/ci/check_docs_flow.py
python3 tools/ci/check_codeowners_coverage.py
python3 tools/ci/check_sdk_no_network.py
git diff --check
scripts/ledger/check
scripts/ledger/check --history --base origin/main
```

If the local machine lacks `wasm32-wasip1` target installation, run the strongest local source/native checks and rely on mandatory remote `wasm-smoke` for the full WASM build and fixture proof on the final SHA.

---

## PR 9a: Reference Scanner Shells

**Files:**
- Create: `examples/ios-scanner/`
- Create: `examples/android-scanner/`
- Create: `examples/wasm-scanner/`
- Create: `examples/README.md`
- Create: `scripts/sdk/check_scanner_examples.sh`
- Modify: `docs/human/sdk/portable-client-sdk.md`
- Modify: `docs/human/sdk/start-here.md`
- Modify: `sdk/README.md`
- Modify: `CHANGELOG.md`
- Modify: this tracker file with PR 8 evidence

- [x] **Step 1: Add minimal scanner shells**

Start with paste/string scan input. Show status, diagnostics, and accept enabled only when verified.

- [x] **Step 2: Split camera adapters after shell parity**

Keep iOS camera, Android CameraX, and browser camera decoding as adapters in PR 9b. Grain receives a GR1 string and owns validation after that.

- [ ] **Step 3: Validate and PR**

Run:

```bash
scripts/sdk/check_scanner_examples.sh
scripts/sdk/check_swift_package.sh
scripts/sdk/check_kotlin_package.sh
npm --prefix sdk/wasm run check
cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core
scripts/sdk/check_generated_bindings.sh
python3 tools/ci/check_client_workflow_fixtures.py
python3 tools/check_llm_docs.py
python3 tools/check_spec_drift.py
python3 tools/ci/check_docs_links.py
python3 tools/ci/check_docs_flow.py
python3 tools/ci/check_codeowners_coverage.py
python3 tools/ci/check_sdk_no_network.py
git diff --check
scripts/ledger/check
scripts/ledger/check --history --base origin/main
```

## PR 9b: Camera Adapters For Scanner Shells

**Files:**
- Modify: `examples/ios-scanner/`
- Modify: `examples/android-scanner/`
- Modify: `examples/wasm-scanner/`
- Modify: `docs/human/sdk/portable-client-sdk.md`
- Modify: `CHANGELOG.md`
- Modify: this tracker file with PR 9a evidence

- [x] **Step 1: Add camera adapter boundaries**

Add adapters that produce GR1 strings and feed the existing scanner-shell workflows. Do not move QR, COSE, DAG-CBOR, trust, or persistence semantics into the app layer.

- [x] **Step 2: Add platform-specific capture adapters**

Add iOS capture, Android CameraX, and browser camera capture as thin adapters with deterministic non-camera tests where device/browser automation is unavailable.

- [x] **Step 3: Validate and PR**

Run available platform app checks, scanner example checks, SDK tests, docs checks, ledger checks, and `git diff --check`.

---

## PR 10: Pairing, Identity, Sync, Device Lifecycle

**Files:**
- Create: `core/rust/grain-client-core/src/identity.rs`
- Create: `core/rust/grain-client-core/src/pairing.rs`
- Create: `core/rust/grain-client-core/src/sync.rs`
- Create: `core/rust/grain-client-core/src/device.rs`
- Create: `sdk/workflows/fixtures/pairing/`
- Create: `sdk/workflows/fixtures/device-lifecycle/`
- Create: `sdk/workflows/fixtures/sync-bundle/`
- Create: `docs/human/rationale/TOR-PAIRING-A01.md`
- Modify: `sdk/swift/`
- Modify: `sdk/kotlin/`
- Modify: `sdk/wasm/`
- Modify: `examples/ios-scanner/`
- Modify: `examples/android-scanner/`
- Modify: `examples/wasm-scanner/`
- Modify: `docs/llm/SDK_INVARIANTS.md`
- Modify: `docs/llm/SDK_EDGE_CASES.md`
- Modify: `docs/llm/SDK_CONFORMANCE.md`
- Modify: `docs/human/sdk/portable-client-sdk.md`
- Modify: `CHANGELOG.md`
- Modify: this tracker file with PR 9 evidence

- [x] **Step 1: Add pairing ADR before implementation**

Define what pairing transfers, what expires, how replay is rejected, and whether pairing transfers `sync_secret`, a wrapped device grant, or a constrained invite.

- [x] **Step 2: Add pure pairing preview**

Parse and validate pairing intent without storing secrets.

- [x] **Step 3: Add explicit pairing accept**

Persist identity/trust material atomically. Reject replay and revoked-device paths.

- [x] **Step 4: Add device lifecycle workflows**

Add create root, export/import identity bundle, add device, revoke device, active-device state, and sync metadata.

- [x] **Step 5: Add sync bundle workflows**

Add export/import sync bundle, list saved objects, export evidence. Treat server sync as dumb transport: no server truth and no hidden trust.

- [ ] **Step 6: Validate and PR**

Run targeted client-core tests, generated binding checks, client workflow suites, docs checks, ledger checks, and broader repo verification.

---

## PR 11: Developer Experience, Version Matrix, Release Packaging

**Files:**
- Modify: `sdk/README.md`
- Modify: `sdk/swift/README.md`
- Modify: `sdk/kotlin/README.md`
- Modify: `sdk/wasm/README.md`
- Create: `docs/human/sdk/version-matrix.md`
- Create: `docs/llm/SDK_GENERATED_VERIFICATION.md`
- Create: `scripts/sdk/verify_all_sdks.sh`
- Create: `scripts/sdk/package_client_sdks.sh`
- Modify: `CHANGELOG.md`
- Modify: this tracker with PR 10 evidence

- [ ] **Step 1: Add version matrix**

Document protocol version, Rust core version, client-core version, Swift binding version, Kotlin binding version, WASM binding version, and compatibility rules.

- [ ] **Step 2: Add one-command SDK verification**

Provide one command that checks generated bindings, client scenarios, Rust tests, and available platform smoke builds.

- [ ] **Step 3: Add copy-paste examples**

Examples must cover preview, accept, list saved scans, export evidence, and trust setup.

- [ ] **Step 4: Add release packaging path**

Add scripts or docs for producing SDK release artifacts without committing build caches or accidental generated junk.

- [ ] **Step 5: Run final verification**

Run:

```bash
./scripts/verify --out-dir artifacts/dev-verify-portable-client-platform-final
```

Use `./scripts/certify` or mandatory CI evidence-bundle proof before calling the whole initiative complete.

---

## Completion Definition

The initiative is complete only when:

- [x] PR 1 is merged and post-merge `main` CI passes.
- [x] PR 2 is merged and post-merge `main` CI passes.
- [x] PR 3a is merged and post-merge `main` CI passes.
- [x] PR 3b is merged and post-merge `main` CI passes.
- [x] PR 4 is merged and post-merge `main` CI passes.
- [x] PR 5 is merged and post-merge `main` CI passes.
- [x] PR 6 is merged and post-merge `main` CI passes.
- [x] PR 7 is merged and post-merge `main` CI passes.
- [x] PR 8 is merged and post-merge `main` CI passes.
- [x] PR 9a is merged and post-merge `main` CI passes.
- [x] PR 9b is merged and post-merge `main` CI passes.
- [ ] PR 10 is merged and post-merge `main` CI passes.
- [ ] PR 11 is merged and post-merge `main` CI passes.
- [ ] This tracker records every PR number, merge SHA, validation result, remote CI result, review result, and split decision.

## Stop Conditions

Stop and report only if:

- A required GitHub permission, secret, platform signing credential, review gate, or protected-branch rule blocks progress.
- A required reviewer or bot leaves feedback requiring a product decision.
- A platform toolchain is unavailable and no deterministic substitute check can honestly prove the PR.
- The next step would require weakening protocol, SDK, CI, ledger, governance, or security gates.
