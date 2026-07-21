#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [[ ! -d instances ]]; then
  echo "No instances directory found"
  exit 0
fi

for file in instances/*.env; do
  [[ -e "$file" ]] || continue
  name="$(basename "$file" .env)"
  echo "Starting runner instance: $name"
  ./scripts/start-instance.sh "$name"
done
