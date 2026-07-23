#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNERCTL="${ROOT_DIR}/runnerctl"

if ! grep -Fq 'INSTANCE REPOSITORY RUNNER_NAME LABELS STATUS' "$RUNNERCTL"; then
  echo "Expected status header to include runner identity columns" >&2
  exit 1
fi

if ! grep -Fq 'runner_name="$(env_value "$file" RUNNER_NAME)"' "$RUNNERCTL"; then
  echo "Expected status to read RUNNER_NAME from instance file" >&2
  exit 1
fi

if ! grep -Fq 'labels="$(env_value "$file" RUNNER_LABELS)"' "$RUNNERCTL"; then
  echo "Expected status to read RUNNER_LABELS from instance file" >&2
  exit 1
fi

if ! grep -Fq 'permission-denied' "$RUNNERCTL"; then
  echo "Expected status to handle unreadable instance files" >&2
  exit 1
fi

echo "runnerctl status contract test passed"
