#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

git config core.hooksPath .githooks
chmod +x .githooks/pre-commit .githooks/commit-msg .githooks/pre-push
echo "Local hygiene hooks enabled via core.hooksPath=.githooks"
echo "Hooks:"
echo "- pre-commit: scans staged paths and staged file contents"
echo "- commit-msg: scans proposed commit messages"
echo "- pre-push: scans tracked files and reachable history"
