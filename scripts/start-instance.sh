#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <instance-name>" >&2
  echo "Example: $0 kanyu" >&2
  echo "Equivalent: bash ./runnerctl start <instance-name>" >&2
  exit 1
fi

exec bash ./runnerctl start "$@"
