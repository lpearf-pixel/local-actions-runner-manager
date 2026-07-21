#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

docker ps --filter "name=home-" --format 'table {{.Names}}\t{{.Status}}'
