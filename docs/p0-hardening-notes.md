# P0 Runner Manager Hardening Notes

This document records the P0 scope implemented on `codex/runner-manager-p0-hardening`.

## Confirmed changes

- `runnerctl` remains the only formal management entrypoint.
- Legacy entrypoints, if present, are required by test to delegate to `runnerctl` rather than keeping independent Docker or runner orchestration logic.
- `compose.yaml` forwards both `NO_PROXY` and `no_proxy` to runner containers, with default local bypass entries.
- `runner/entrypoint.sh` starts `run.sh` with management-only credentials removed from the child environment.
- Docker socket contract tests accept the safe quoted `chmod g+rw "$socket"` form and reject broad world-writable chmod modes.
- The manager validation workflow now runs on pull requests and main pushes, and uses the currently verified official `actions/checkout@v6.0.2` tag.

## Verified host context

The operator reported `bash ./runnerctl doctor-host` output showing:

```text
Docker context: desktop-linux
Docker client version: 29.6.1
Docker server version: 29.6.1
Docker CPUs: 16
Docker memory bytes: 8320479232
```

At the same time, existing `home-kanyu-runner` and `home-community-runner` containers were already healthy. P0 code changes do not require an immediate restart; rebuild/restart should happen only during an idle maintenance window.

## Security model

Management credentials are for runner registration, removal and future status queries only. They must not be visible to workflow jobs through the persistent runner process environment.

The P0 entrypoint removes these variables before starting `run.sh`:

```text
GITHUB_TOKEN
GH_TOKEN
RUNNER_TOKEN
REGISTRATION_TOKEN
REMOVE_TOKEN
MANAGEMENT_GITHUB_TOKEN
ACTIONS_RUNNER_INPUT_TOKEN
```

## Proxy model

Local traffic should bypass external proxies. The default bypass list is:

```text
localhost,127.0.0.1,host.docker.internal
```

Container runners usually use `host.docker.internal` for host services. Physical runners usually use `127.0.0.1`.

## Current compatibility note

The runner image still pins Docker CLI `20.10.24` and Compose plugin `2.3.3`. This was introduced to support older Docker Desktop daemons and avoid CLI/daemon API mismatches. The host currently reports Docker `29.6.1`; do not upgrade the in-image client in P0 without a real Docker socket smoke test. P1 should add the compatibility matrix and smoke evidence before changing client versions.

## P1 / P2 backlog not implemented in P0

- Instance-level mutual exclusion.
- Precise cleanup failure propagation.
- Job start/completed hooks.
- `doctor --json` and GitHub remote runner status checks.
- Docker log rotation and disk protection.
- Docker client compatibility matrix and upgrade policy.
- Heavy E2E isolation template and dynamic resource naming.
- GitHub App based credential split.
- Ephemeral runner migration.
- Docker socket proxy redesign.
- Rootless Docker or dedicated VM migration.
- Automatic scaling.
