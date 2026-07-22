#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENTRYPOINT="${ROOT_DIR}/runner/entrypoint.sh"
COMPOSE_FILE="${ROOT_DIR}/compose.yaml"
DOCKERFILE="${ROOT_DIR}/runner/Dockerfile"

if ! grep -Fq '[[ -f .runner && -f .credentials ]]' "$ENTRYPOINT"; then
  echo "Expected entrypoint to detect an existing runner configuration" >&2
  exit 1
fi

if ! grep -Fq 'Reusing existing runner configuration' "$ENTRYPOINT"; then
  echo "Expected entrypoint to announce configuration reuse" >&2
  exit 1
fi

if grep -Eq '^[[:space:]]*init:[[:space:]]*true[[:space:]]*$' "$COMPOSE_FILE"; then
  echo "Compose must not inject a second init process when the image already owns Tini" >&2
  exit 1
fi

if ! grep -Fq 'ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/runner-entrypoint"]' "$DOCKERFILE"; then
  echo "Expected the image entrypoint to keep Tini as PID 1" >&2
  exit 1
fi

echo "runner restart idempotency contract test passed"
