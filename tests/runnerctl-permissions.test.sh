#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/runnerctl-permissions.XXXXXX")"
trap 'chmod -R u+rwX "$TMP_ROOT" 2>/dev/null || true; rm -rf "$TMP_ROOT"' EXIT

cp "$ROOT_DIR/runnerctl" "$TMP_ROOT/runnerctl"
cp "$ROOT_DIR/compose.yaml" "$TMP_ROOT/compose.yaml"
mkdir -p "$TMP_ROOT/instances" "$TMP_ROOT/bin"

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

cat > "$TMP_ROOT/bin/docker" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
if [[ "${1:-}" == "inspect" ]]; then
  if [[ "${2:-}" == "-f" || "${2:-}" == "--format" ]]; then
    echo running
  else
    exit 0
  fi
  exit 0
fi
if [[ "${1:-}" == "info" ]]; then
  exit 0
fi
if [[ "${1:-}" == "compose" ]]; then
  exit 0
fi
exit 0
EOF
chmod +x "$TMP_ROOT/bin/docker"

chmod 000 "$TMP_ROOT/instances/kanyu.env"

status_output="$(cd "$TMP_ROOT" && PATH="$TMP_ROOT/bin:$PATH" bash ./runnerctl status 2>&1)"
if ! grep -q 'permission-denied' <<<"$status_output"; then
  echo "Expected status to report permission-denied without aborting" >&2
  echo "$status_output" >&2
  exit 1
fi

(cd "$TMP_ROOT" && PATH="$TMP_ROOT/bin:$PATH" bash ./runnerctl repair-permissions)

if [[ ! -r "$TMP_ROOT/instances/kanyu.env" ]]; then
  echo "Expected repair-permissions to restore readability" >&2
  exit 1
fi

mode="$(stat -f '%Lp' "$TMP_ROOT/instances/kanyu.env" 2>/dev/null || stat -c '%a' "$TMP_ROOT/instances/kanyu.env")"
if [[ "$mode" != "600" ]]; then
  echo "Expected instance env mode 600, got $mode" >&2
  exit 1
fi

echo "runnerctl permission recovery test passed"
