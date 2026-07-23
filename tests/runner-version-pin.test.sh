#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKERFILE="${ROOT_DIR}/runner/Dockerfile"

if ! grep -Fq 'ARG RUNNER_VERSION=2.336.0' "$DOCKERFILE"; then
  echo "Expected Dockerfile to pin RUNNER_VERSION=2.336.0 by default" >&2
  exit 1
fi

if grep -Fq 'api.github.com/repos/actions/runner/releases/latest' "$DOCKERFILE"; then
  echo "Dockerfile must not call the GitHub latest-release API during normal builds" >&2
  exit 1
fi

echo "runner version pin contract test passed"
