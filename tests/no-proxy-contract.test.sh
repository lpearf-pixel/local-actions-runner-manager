#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${ROOT_DIR}/compose.yaml"

for key in NO_PROXY no_proxy; do
  if ! grep -Fq "${key}:" "$COMPOSE_FILE"; then
    echo "Expected compose.yaml to pass ${key} into the runner container" >&2
    exit 1
  fi
done

for host in localhost 127.0.0.1 host.docker.internal; do
  if ! grep -Fq "$host" "$COMPOSE_FILE"; then
    echo "Expected default NO_PROXY list to include ${host}" >&2
    exit 1
  fi
done

if grep -Fq 'NO_PROXY:' "$COMPOSE_FILE" && ! grep -Fq '${NO_PROXY:-localhost,127.0.0.1,host.docker.internal}' "$COMPOSE_FILE"; then
  echo "Expected user supplied NO_PROXY to be preserved when set, with safe defaults otherwise" >&2
  exit 1
fi

echo "no-proxy contract test passed"
