#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BROKER_DIRS=(
  "apps/food-analysis-broker"
  "apps/food-wallet-broker"
  "services/food-analysis-broker"
  "services/food-wallet-broker"
  "backend/food-analysis-broker"
)

existing_dirs=()
for dir in "${BROKER_DIRS[@]}"; do
  if [[ -d "$dir" ]]; then
    existing_dirs+=("$dir")
  fi
done

if [[ "${#existing_dirs[@]}" -eq 0 ]]; then
  echo "Food analysis broker check: PASS (no backend broker directory present)"
  exit 0
fi

if python3 tools/ci/find_regex_match.py --ignore-case \
  '(writeFile|appendFile|createWriteStream|FileManager|createFile|copyFile|rename)\s*\([^)]*(photo|image|bytes_b64|media_b64|base64)' \
  "${existing_dirs[@]}" >/dev/null; then
  echo "SDK_FOOD_ANALYSIS_BROKER_ERR_RAW_IMAGE_PERSISTENCE: broker must not persist raw image request material" >&2
  exit 1
fi

if python3 tools/ci/find_regex_match.py --ignore-case \
  '(console\.(log|debug|info|warn|error)|print|debugPrint|NSLog|os_log|Logger\.[A-Za-z]+|logger\.(debug|info|warn|error))\s*\([^)]*(request|body|photo|image|bytes_b64|media_b64|base64)' \
  "${existing_dirs[@]}" >/dev/null; then
  echo "SDK_FOOD_ANALYSIS_BROKER_ERR_RAW_IMAGE_LOGGING: broker must not log raw image request material" >&2
  exit 1
fi

set +e
python3 tools/ci/find_regex_match.py --ignore-case \
  'api\.openai\.com|OPENAI_API_KEY|USDA_API_KEY|FOODDATA_CENTRAL|FDC_API_KEY|api\.nal\.usda\.gov|api\.data\.gov' \
  "${existing_dirs[@]}" >/dev/null
provider_status=$?
set -e
if [[ "$provider_status" -eq 1 ]]; then
  echo "SDK_FOOD_ANALYSIS_BROKER_ERR_MISSING_PROVIDER_BOUNDARY: broker should own OpenAI/USDA provider configuration" >&2
  exit 1
fi
if [[ "$provider_status" -ne 0 ]]; then
  exit "$provider_status"
fi

echo "Food analysis broker check: PASS"
