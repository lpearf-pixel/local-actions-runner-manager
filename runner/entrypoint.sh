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
MANAGEMENT_GITHUB_TOKEN="${GITHUB_TOKEN}"
TOKEN_HEADER="Authorization: Bearer ${MANAGEMENT_GITHUB_TOKEN}"
API_HEADER="X-GitHub-Api-Version: 2022-11-28"

configure_docker_socket() {
  local socket=/var/run/docker.sock
  local socket_gid socket_group attempt ping_output

  [[ -S "$socket" ]] || return 0

  socket_gid="$(stat -c '%g' "$socket")"
  if ! getent group "$socket_gid" >/dev/null; then
    groupadd --gid "$socket_gid" docker-host
  fi

  socket_group="$(getent group "$socket_gid" | cut -d: -f1)"
  usermod -aG "$socket_group" runner

  # Docker Desktop may expose the bind-mounted socket as 0755. Group
  # membership alone is insufficient in that case, so repair the group
  # write bit every time the runner container starts. This intentionally
  # avoids world-writable chmod modes such as 666 or 777.
  if ! chmod g+rw "$socket"; then
    echo "ERROR: failed to grant group write access to Docker socket" >&2
    ls -ln "$socket" >&2 || true
    exit 1
  fi

  for attempt in 1 2 3 4 5; do
    if ping_output="$(gosu runner curl --silent --show-error --fail --max-time 5 --unix-socket "$socket" http://localhost/_ping 2>&1)" \
       && [[ "$ping_output" == "OK" ]]; then
      echo "Docker API ping succeeded through mounted socket."

      if gosu runner docker version >/dev/null 2>&1; then
        echo "Docker CLI can talk to daemon as runner user."
        return 0
      fi

      echo "ERROR: Docker CLI cannot talk to daemon even though Docker API ping succeeded." >&2
      echo "This usually means the runner image Docker CLI is incompatible with the host Docker Desktop daemon." >&2
      echo "Socket state:" >&2
      ls -ln "$socket" >&2 || true
      echo "Runner identity:" >&2
      id runner >&2 || true
      echo "Docker CLI diagnostic:" >&2
      gosu runner docker version >&2 || true
      exit 1
    fi

    sleep 2
  done

  echo "ERROR: Docker API is not reachable through mounted socket" >&2
  echo "Last /_ping output: ${ping_output:-<empty>}" >&2
  ls -ln "$socket" >&2 || true
  id runner >&2 || true
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

start_runner_without_management_credentials() {
  echo "Starting runner listener with management credentials removed from job environment."
  env \
    -u GITHUB_TOKEN \
    -u GH_TOKEN \
    -u RUNNER_TOKEN \
    -u REGISTRATION_TOKEN \
    -u REMOVE_TOKEN \
    -u MANAGEMENT_GITHUB_TOKEN \
    -u ACTIONS_RUNNER_INPUT_TOKEN \
    gosu runner ./run.sh &
  runner_pid=$!
}

start_runner_without_management_credentials
wait "$runner_pid"
