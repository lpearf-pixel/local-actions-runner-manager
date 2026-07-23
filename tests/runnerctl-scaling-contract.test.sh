#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/runnerctl-scaling.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

cp "$ROOT_DIR/runnerctl" "$TMP_ROOT/runnerctl"
cp "$ROOT_DIR/compose.yaml" "$TMP_ROOT/compose.yaml"
mkdir -p "$TMP_ROOT/instances" "$TMP_ROOT/bin"

cat > "$TMP_ROOT/.env" <<'EOF'
GITHUB_TOKEN=test-token
HTTP_PROXY=http://127.0.0.1:8001
HTTPS_PROXY=http://127.0.0.1:8001
NO_PROXY=localhost,127.0.0.1,host.docker.internal
EOF

cat > "$TMP_ROOT/instances/community.env" <<'EOF'
GITHUB_REPOSITORY=lpearf-pixel/community-selection-miniapp
RUNNER_NAME=home-community-runner
RUNNER_LABELS=lan,docker,home,community
RUNNER_GROUP=Default
RUNNER_WORKDIR=_work
RUNNER_EPHEMERAL=false
EOF

cat > "$TMP_ROOT/bin/docker" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
log="${RUNNERCTL_TEST_DOCKER_LOG:?missing RUNNERCTL_TEST_DOCKER_LOG}"
printf '%s\n' "$*" >> "$log"
if [[ "${1:-}" == "inspect" ]]; then
  if [[ "${2:-}" == "-f" || "${2:-}" == "--format" ]]; then
    case "${3:-}" in
      *'.State.Status'*) echo exited ;;
      *'.State.Running'*) echo false ;;
      *'.State.Health'*) echo healthy ;;
      *) echo exited ;;
    esac
  fi
  exit 0
fi
if [[ "${1:-}" == "info" ]]; then exit 0; fi
if [[ "${1:-}" == "compose" ]]; then exit 0; fi
exit 0
EOF
chmod +x "$TMP_ROOT/bin/docker"
export RUNNERCTL_TEST_DOCKER_LOG="$TMP_ROOT/docker.log"

run_ctl() {
  (cd "$TMP_ROOT" && PATH="$TMP_ROOT/bin:$PATH" bash ./runnerctl "$@")
}

assert_file_contains() {
  local file="$1" expected="$2"
  if ! grep -Fq "$expected" "$file"; then
    echo "Expected $file to contain: $expected" >&2
    cat "$file" >&2
    exit 1
  fi
}

run_ctl add-worker community w01
assert_file_contains "$TMP_ROOT/instances/community-w01.env" 'GITHUB_REPOSITORY=lpearf-pixel/community-selection-miniapp'
assert_file_contains "$TMP_ROOT/instances/community-w01.env" 'RUNNER_NAME=home-community-w01-runner'
assert_file_contains "$TMP_ROOT/instances/community-w01.env" 'RUNNER_LABELS=lan,docker,home,community-w01'
if grep -Fq 'RUNNER_LABELS=lan,docker,home,community,community-w01' "$TMP_ROOT/instances/community-w01.env"; then
  echo "add-worker must keep workers isolated by default" >&2
  exit 1
fi

run_ctl add-worker community w02 --join-pool
assert_file_contains "$TMP_ROOT/instances/community-w02.env" 'RUNNER_LABELS=lan,docker,home,community,community-w02'

run_ctl scale community 4 --join-pool
assert_file_contains "$TMP_ROOT/instances/community-w03.env" 'RUNNER_LABELS=lan,docker,home,community,community-w03'
if ! grep -Fq 'RUNNER_LABELS=lan,docker,home,community-w01' "$TMP_ROOT/instances/community-w01.env"; then
  echo "scale must not mutate existing workers" >&2
  exit 1
fi

run_ctl workers community > "$TMP_ROOT/workers.out"
assert_file_contains "$TMP_ROOT/workers.out" 'community'
assert_file_contains "$TMP_ROOT/workers.out" 'community-w01'
assert_file_contains "$TMP_ROOT/workers.out" 'community-w02'
assert_file_contains "$TMP_ROOT/workers.out" 'community-w03'

: > "$RUNNERCTL_TEST_DOCKER_LOG"
run_ctl downscale community 2 --stop-only
[[ -f "$TMP_ROOT/instances/community-w03.env" ]] || { echo "stop-only must keep community-w03 env" >&2; exit 1; }
[[ -f "$TMP_ROOT/instances/community-w02.env" ]] || { echo "stop-only must keep community-w02 env" >&2; exit 1; }
assert_file_contains "$RUNNERCTL_TEST_DOCKER_LOG" 'compose --project-name runner-community-w03'
assert_file_contains "$RUNNERCTL_TEST_DOCKER_LOG" 'compose --project-name runner-community-w02'

run_ctl pool-leave community-w02 community
assert_file_contains "$TMP_ROOT/instances/community-w02.env" 'RUNNER_LABELS=lan,docker,home,community-w02'
run_ctl pool-join community-w02 community
assert_file_contains "$TMP_ROOT/instances/community-w02.env" 'RUNNER_LABELS=lan,docker,home,community-w02,community'

run_ctl downscale community 1 --remove-config --force
[[ -f "$TMP_ROOT/instances/community.env" ]] || { echo "downscale must never remove base env" >&2; exit 1; }
[[ ! -f "$TMP_ROOT/instances/community-w01.env" ]] || { echo "remove-config force should remove community-w01 env" >&2; exit 1; }
[[ ! -f "$TMP_ROOT/instances/community-w02.env" ]] || { echo "remove-config force should remove community-w02 env" >&2; exit 1; }
[[ ! -f "$TMP_ROOT/instances/community-w03.env" ]] || { echo "remove-config force should remove community-w03 env" >&2; exit 1; }

if run_ctl add-worker community w01 2>/dev/null; then
  :
else
  echo "worker suffix should be reusable after remove-config" >&2
  exit 1
fi

if run_ctl scale community 0 2>/dev/null; then
  echo "scale must reject count lower than one" >&2
  exit 1
fi

if run_ctl downscale community 0 2>/dev/null; then
  echo "downscale must reject count lower than one" >&2
  exit 1
fi

echo "runnerctl scaling contract test passed"
