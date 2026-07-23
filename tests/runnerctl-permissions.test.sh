#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNERCTL_SOURCE="${ROOT_DIR}/runnerctl"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/runnerctl-permissions.XXXXXX")"
trap 'chmod -R u+rwX "$TMP_ROOT" 2>/dev/null || true; rm -rf "$TMP_ROOT"' EXIT

if ! grep -Fq 'if [[ ! -r "$file" ]]' "$RUNNERCTL_SOURCE"; then
  echo "Expected status to check unreadable instance files before reading them" >&2
  exit 1
fi

if ! grep -Fq 'repo="permission-denied"' "$RUNNERCTL_SOURCE"; then
  echo "Expected status to report permission-denied for unreadable instance files" >&2
  exit 1
fi

cp "$RUNNERCTL_SOURCE" "$TMP_ROOT/runnerctl"
cp "$ROOT_DIR/compose.yaml" "$TMP_ROOT/compose.yaml"
mkdir -p "$TMP_ROOT/instances"

cat > "$TMP_ROOT/.env" <<'EOF'
GITHUB_TOKEN=test-token
HTTP_PROXY=http://127.0.0.1:8001
HTTPS_PROXY=http://127.0.0.1:8001
EOF

cat > "$TMP_ROOT/instances/kanyu.env" <<'EOF'
GITHUB_REPOSITORY=lpearf-pixel/kanyu-spatial-engine
RUNNER_NAME=home-kanyu-runner
RUNNER_LABELS=lan,docker,home,kanyu
EOF

chmod 644 "$TMP_ROOT/instances/kanyu.env"
(cd "$TMP_ROOT" && bash ./runnerctl repair-permissions)

mode="$(stat -f '%Lp' "$TMP_ROOT/instances/kanyu.env" 2>/dev/null || stat -c '%a' "$TMP_ROOT/instances/kanyu.env")"
if [[ "$mode" != "600" ]]; then
  echo "Expected instance env mode 600, got $mode" >&2
  exit 1
fi

echo "runnerctl permission recovery test passed"
