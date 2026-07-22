#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKERFILE="${ROOT_DIR}/runner/Dockerfile"

if grep -Eq 'apt-get install[^\n]*docker\.io|[[:space:]]docker\.io([[:space:]]|$)' "$DOCKERFILE"; then
  echo "Expected runner image not to install Ubuntu docker.io, which may drift past the host Docker Desktop daemon API" >&2
  exit 1
fi

if ! grep -Fq 'ARG DOCKER_CLI_VERSION=20.10.24' "$DOCKERFILE"; then
  echo "Expected Docker CLI to be pinned to a Docker Desktop 20.10-compatible version" >&2
  exit 1
fi

if ! grep -Fq 'download.docker.com/linux/static/stable' "$DOCKERFILE"; then
  echo "Expected Docker CLI to be installed from Docker static binaries instead of distro docker.io" >&2
  exit 1
fi

if ! grep -Fq 'ARG DOCKER_COMPOSE_VERSION=2.3.3' "$DOCKERFILE"; then
  echo "Expected Docker Compose plugin to be pinned near the host Docker Desktop generation" >&2
  exit 1
fi

echo "docker cli version contract test passed"
