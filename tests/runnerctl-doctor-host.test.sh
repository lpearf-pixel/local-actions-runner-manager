#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNERCTL="${ROOT_DIR}/runnerctl"

if ! grep -Fq 'bash ./runnerctl doctor-host' "$RUNNERCTL"; then
  echo "Expected usage to document doctor-host" >&2
  exit 1
fi

if ! grep -Fq 'doctor-host) doctor_host ;;' "$RUNNERCTL"; then
  echo "Expected command dispatch for doctor-host" >&2
  exit 1
fi

if ! grep -Fq 'docker info' "$RUNNERCTL"; then
  echo "Expected doctor-host to check docker info" >&2
  exit 1
fi

if ! grep -Fq 'docker version' "$RUNNERCTL"; then
  echo "Expected doctor-host to report docker version" >&2
  exit 1
fi

if ! grep -Eq '/var/run/docker\.sock|HOME/.docker/run/docker\.sock' "$RUNNERCTL"; then
  echo "Expected doctor-host to inspect Docker socket paths" >&2
  exit 1
fi

if grep -Fq 'down --volumes' <(sed -n '/doctor_host()/,/^}/p' "$RUNNERCTL"); then
  echo "doctor-host must not remove Docker volumes" >&2
  exit 1
fi

echo "runnerctl doctor-host contract test passed"
