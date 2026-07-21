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

if [[ -S /var/run/docker.sock ]]; then
  socket_gid="$(stat -c '%g' /var/run/docker.sock)"
  if ! getent group "$socket_gid" >/dev/null; then
    groupadd --gid "$socket_gid" docker-host
  fi
  socket_group="$(getent group "$socket_gid" | cut -d: -f1)"
  usermod -aG "$socket_group" runner
fi

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

cleanup() {
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
