#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

docker compose ps

echo
if docker compose exec -T runner pgrep -af Runner.Listener >/dev/null 2>&1; then
  echo "Runner listener: running"
else
  echo "Runner listener: not running"
  exit 1
fi
