#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENTRYPOINT="${ROOT_DIR}/runner/entrypoint.sh"

if ! grep -Eq 'chmod[[:space:]]+g\+rw[[:space:]]+\$socket|chmod[[:space:]]+g\+rw[[:space:]]+/var/run/docker\.sock|chmod[[:space:]]+660[[:space:]]+\$socket|chmod[[:space:]]+660[[:space:]]+/var/run/docker\.sock' "$ENTRYPOINT"; then
  echo "Expected entrypoint to grant the socket group write access" >&2
  exit 1
fi

if ! grep -Fq 'curl --silent --show-error --fail --max-time 5 --unix-socket "$socket" http://localhost/_ping' "$ENTRYPOINT"; then
  echo "Expected entrypoint to verify raw Docker API socket access as runner user" >&2
  exit 1
fi

if ! grep -Fq 'Docker API ping succeeded through mounted socket.' "$ENTRYPOINT"; then
  echo "Expected a clear success message for raw Docker API access" >&2
  exit 1
fi

if ! grep -Fq 'Docker CLI cannot talk to daemon' "$ENTRYPOINT"; then
  echo "Expected a clear failure message for Docker CLI/daemon compatibility errors" >&2
  exit 1
fi

if ! grep -Fq 'Docker API is not reachable through mounted socket' "$ENTRYPOINT"; then
  echo "Expected a clear failure message when the mounted Docker socket cannot reach the API" >&2
  exit 1
fi

echo "docker socket access contract test passed"
