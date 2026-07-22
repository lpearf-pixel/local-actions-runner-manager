#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <instance-name>" >&2
  echo "Example: $0 kanyu" >&2
  exit 1
fi

NAME="$1"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT/instances/$NAME.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE" >&2
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

export COMPOSE_PROJECT_NAME="runner-$NAME"
export ENV_FILE

docker compose --env-file "$ENV_FILE" up -d --build

echo "Started runner instance: $NAME"
docker compose --env-file "$ENV_FILE" ps
