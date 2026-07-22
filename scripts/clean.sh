#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

name="${1:-}"

cleanup_tmp() {
  echo "Cleaning runner temporary env files..."
  find "${TMPDIR:-/tmp}" -name 'runner-*.env' -type f -delete 2>/dev/null || true
}

cleanup_instances() {
  if [[ -n "$name" ]]; then
    echo "Cleaning instance: $name"
    docker compose --project-name "runner-${name}" -f "${ROOT_DIR}/compose.yaml" down --remove-orphans || true
  else
    echo "Cleaning all runner temporary resources..."
    docker ps -a --filter name=runner- --format '{{.Names}}' | xargs -r docker rm -f || true
  fi
}

cleanup_tmp
cleanup_instances

echo "Cleanup completed."
