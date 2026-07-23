#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow="${ROOT_DIR}/.github/workflows/normalize-script-modes.yml"

if grep -Eq 'uses:[[:space:]]+actions/checkout@v[1-5]([^0-9]|$)' "$workflow"; then
  echo "workflow must not use old checkout action major versions" >&2
  exit 1
fi

if ! grep -Fq 'uses: actions/checkout@v6.0.2' "$workflow"; then
  echo "workflow should use the currently verified actions/checkout v6.0.2 tag" >&2
  exit 1
fi

if grep -Eq 'uses:[[:space:]]+actions/setup-node@v[1-5]([^0-9]|$)' "$workflow"; then
  echo "workflow must not use old setup-node action major versions" >&2
  exit 1
fi

if ! grep -Fq "github.event_name == 'push' && github.ref_name == 'main'" "$workflow"; then
  echo "workflow normalization push step must be restricted to main push events" >&2
  exit 1
fi

echo "workflow actions contract test passed"
