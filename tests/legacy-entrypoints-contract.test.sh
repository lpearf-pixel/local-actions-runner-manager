#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
legacy_paths=(
  "start.sh"
  "validate.sh"
  "start-instance.sh"
  "scripts/start.sh"
  "scripts/validate.sh"
  "scripts/start-instance.sh"
)

for rel in "${legacy_paths[@]}"; do
  path="${ROOT_DIR}/${rel}"
  [[ -e "$path" ]] || continue

  if ! grep -Eq 'runnerctl|bash[[:space:]]+\.\/runnerctl|bash[[:space:]]+.*runnerctl' "$path"; then
    echo "Legacy entrypoint ${rel} must delegate to runnerctl instead of implementing a second control path" >&2
    exit 1
  fi

  if grep -Eq 'docker[[:space:]]+compose|docker-compose|config\.sh|run\.sh' "$path" \
     && ! grep -Fq 'runnerctl' "$path"; then
    echo "Legacy entrypoint ${rel} appears to contain independent runner orchestration" >&2
    exit 1
  fi
done

echo "legacy entrypoints contract test passed"
