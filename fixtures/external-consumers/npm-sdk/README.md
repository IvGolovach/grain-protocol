# External npm Consumer Fixture

This fixture models a separate Node/TypeScript consumer that imports Grain only
through public package exports.

It is not published and does not use registry credentials.
The repo dry-run checker validates the fixture shape and, when requested,
builds/packs the local TypeScript packages without publishing them.

## Check

```bash
python3 tools/ci/check_npm_release_dry_run.py --fixture fixtures/external-consumers/npm-sdk
```

Release dry-run mode runs the same checker with `--build`.
