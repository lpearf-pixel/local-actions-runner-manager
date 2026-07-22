#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENTRYPOINT="${ROOT_DIR}/runner/entrypoint.sh"

if ! grep -Eq 'chmod[[:space:]]+g\+rw[[:space:]]+/var/run/docker\.sock|chmod[[:space:]]+660[[:space:]]+/var/run/docker\.sock' "$ENTRYPOINT"; then
  echo "Expected entrypoint to grant the socket group write access" >&2
  exit 1
fi

if ! grep -Fq 'gosu runner docker version' "$ENTRYPOINT"; then
  echo "Expected entrypoint to verify Docker API access as runner user" >&2
  exit 1
fi

if ! grep -Fq 'Docker socket is not writable by runner' "$ENTRYPOINT"; then
  echo "Expected a clear failure message when Docker socket access cannot be repaired" >&2
  exit 1
fi

echo "docker socket access contract test passed"
