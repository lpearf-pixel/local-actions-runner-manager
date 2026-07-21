#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

command -v docker >/dev/null || { echo "ERROR: docker is not installed" >&2; exit 1; }
docker compose version >/dev/null || { echo "ERROR: Docker Compose v2 is required" >&2; exit 1; }

if [[ ! -f .env ]]; then
  echo "ERROR: .env is missing. Run: cp .env.example .env" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

[[ "${GITHUB_REPOSITORY:-}" =~ ^[^/]+/[^/]+$ ]] || {
  echo "ERROR: GITHUB_REPOSITORY must use owner/repository format" >&2
  exit 1
}

[[ -n "${GITHUB_TOKEN:-}" && "$GITHUB_TOKEN" != "github_pat_replace_me" ]] || {
  echo "ERROR: set a real GITHUB_TOKEN in .env" >&2
  exit 1
}

[[ -n "${RUNNER_NAME:-}" ]] || { echo "ERROR: RUNNER_NAME is required" >&2; exit 1; }

docker compose config --quiet

echo "Configuration is valid."
