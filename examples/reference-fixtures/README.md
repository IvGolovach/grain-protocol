# Reference Fixtures

This directory contains small repo-native examples that a developer can inspect
without running a phone, camera, registry, or external application.

`catalog.v1.json` is the machine-readable entry point. It links:
- happy-path conformance vectors
- negative security vectors
- profile sample events for Food, Inventory, and Audit Artifact adapters

These fixtures are examples and guardrails. Protocol conformance still lives in
`conformance/vectors/`.

## Check

```bash
python3 tools/ci/check_repo_native_developer_platform.py
```
