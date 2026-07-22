#!/usr/bin/env bash
set -Eeuo pipefail

required=(GITHUB_REPOSITORY GITHUB_TOKEN RUNNER_NAME)
for name in "${required[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    echo "ERROR: ${name} is required" >&2
    exit 1
  fi
done

if [[ ! "$GITHUB_REPOSITORY" =~ ^[^/]+/[^/]+$ ]]; then
  echo "ERROR: GITHUB_REPOSITORY must use owner/repository format" >&2
  exit 1
fi

RUNNER_LABELS="${RUNNER_LABELS:-lan,docker,home}"
RUNNER_GROUP="${RUNNER_GROUP:-Default}"
RUNNER_WORKDIR="${RUNNER_WORKDIR:-_work}"
RUNNER_EPHEMERAL="${RUNNER_EPHEMERAL:-false}"
API_URL="https://api.github.com/repos/${GITHUB_REPOSITORY}"
REPO_URL="https://github.com/${GITHUB_REPOSITORY}"
TOKEN_HEADER="Authorization: Bearer ${GITHUB_TOKEN}"
API_HEADER="X-GitHub-Api-Version: 2022-11-28"

configure_docker_socket() {
  local socket=/var/run/docker.sock
  local socket_gid socket_group attempt

  [[ -S "$socket" ]] || return 0

  socket_gid="$(stat -c '%g' "$socket")"
  if ! getent group "$socket_gid" >/dev/null; then
    groupadd --gid "$socket_gid" docker-host
  fi

  socket_group="$(getent group "$socket_gid" | cut -d: -f1)"
  usermod -aG "$socket_group" runner

  # Docker Desktop may expose the bind-mounted socket as 0755. Group
  # membership alone is insufficient in that case, so repair the group
  # write bit every time the runner container starts.
  if ! chmod g+rw "$socket"; then
    echo "ERROR: failed to grant group write access to Docker socket" >&2
    ls -ln "$socket" >&2 || true
    exit 1
  fi

  for attempt in 1 2 3 4 5; do
    if gosu runner docker version >/dev/null 2>&1; then
      echo "Docker API is available to runner user."
      return 0
    fi
    sleep 2
  done

  echo "ERROR: Docker socket is not writable by runner" >&2
  ls -ln "$socket" >&2 || true
  id runner >&2 || true
  gosu runner docker version >&2 || true
  exit 1
}

configure_docker_socket

mkdir -p "/runner/${RUNNER_WORKDIR}"
chown -R runner:runner "/runner/${RUNNER_WORKDIR}"

api_post() {
  local endpoint="$1"
  curl --silent --show-error --fail-with-body --request POST \
    --header "$TOKEN_HEADER" \
    --header "Accept: application/vnd.github+json" \
    --header "$API_HEADER" \
    "${API_URL}/${endpoint}"
}

configure_runner() {
  local registration_token
  local -a config_args

  if [[ -f .runner && -f .credentials ]]; then
    echo "Reusing existing runner configuration for ${RUNNER_NAME}."
    return 0
  fi

  if [[ -f .runner || -f .credentials ]]; then
    echo "ERROR: partial runner configuration detected in /runner" >&2
    echo "Remove the instance container and recreate it before retrying." >&2
    ls -la .runner .credentials 2>/dev/null || true
    exit 1
  fi

  registration_token="$(api_post actions/runners/registration-token | jq -er '.token')"

  config_args=(
    --unattended
    --replace
    --url "$REPO_URL"
    --token "$registration_token"
    --name "$RUNNER_NAME"
    --work "$RUNNER_WORKDIR"
    --labels "$RUNNER_LABELS"
    --runnergroup "$RUNNER_GROUP"
  )

  if [[ "$RUNNER_EPHEMERAL" == "true" ]]; then
    config_args+=(--ephemeral)
  fi

  gosu runner ./config.sh "${config_args[@]}"
}

configure_runner

cleanup() {
  local removal_token

  if [[ ! -f .runner || ! -f .credentials ]]; then
    return 0
  fi

  echo "Removing runner registration..."
  removal_token="$(api_post actions/runners/remove-token | jq -er '.token' || true)"
  if [[ -n "$removal_token" ]]; then
    gosu runner ./config.sh remove --unattended --token "$removal_token" || true
  fi
}

trap cleanup EXIT INT TERM

gosu runner ./run.sh &
runner_pid=$!
wait "$runner_pid"
