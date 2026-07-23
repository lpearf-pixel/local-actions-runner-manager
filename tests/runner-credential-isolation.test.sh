#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENTRYPOINT="${ROOT_DIR}/runner/entrypoint.sh"

if ! grep -Fq 'start_runner_without_management_credentials' "$ENTRYPOINT"; then
  echo "Expected a dedicated runner start function that strips management credentials" >&2
  exit 1
fi

for secret_name in GITHUB_TOKEN GH_TOKEN RUNNER_TOKEN REGISTRATION_TOKEN REMOVE_TOKEN MANAGEMENT_GITHUB_TOKEN ACTIONS_RUNNER_INPUT_TOKEN; do
  if ! grep -Fq -- "-u ${secret_name}" "$ENTRYPOINT"; then
    echo "Expected ${secret_name} to be removed from the run.sh environment" >&2
    exit 1
  fi
done

if grep -Eq 'echo .*(GITHUB_TOKEN|GH_TOKEN|MANAGEMENT_GITHUB_TOKEN|TOKEN_HEADER|registration_token|removal_token)' "$ENTRYPOINT"; then
  echo "Entrypoint must not echo management credentials or derived token headers" >&2
  exit 1
fi

if ! grep -Fq 'TOKEN_HEADER="Authorization: Bearer ${MANAGEMENT_GITHUB_TOKEN}"' "$ENTRYPOINT"; then
  echo "Expected management token to be captured only for API token exchange before run.sh starts" >&2
  exit 1
fi

echo "runner credential isolation contract test passed"
