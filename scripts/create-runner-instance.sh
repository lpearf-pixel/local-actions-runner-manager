#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <instance-name>" >&2
  echo "Example: $0 kanyu" >&2
  exit 1
fi

NAME="$1"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "$ROOT/instances"

if [[ -f "$ROOT/instances/$NAME.env" ]]; then
  echo "Already exists: instances/$NAME.env" >&2
  exit 1
fi

cat > "$ROOT/instances/$NAME.env" <<EOF
GITHUB_REPOSITORY=lpearf-pixel/$NAME
GITHUB_TOKEN=github_pat_replace_me

RUNNER_NAME=home-$NAME-runner
RUNNER_LABELS=lan,docker,home,$NAME
RUNNER_GROUP=Default
RUNNER_WORKDIR=_work
RUNNER_EPHEMERAL=false

HTTP_PROXY=http://192.168.2.28:8001
HTTPS_PROXY=http://192.168.2.28:8001
EOF

echo "Created instances/$NAME.env"
echo "Edit token/repository, then start with this configuration."
