#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

./scripts/validate.sh

docker compose up --detach --build

echo
echo "Runner started. Check GitHub: Settings -> Actions -> Runners"
docker compose ps
