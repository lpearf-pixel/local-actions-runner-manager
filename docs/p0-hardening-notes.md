# P0 Runner Manager Hardening Notes

This document records the P0 scope implemented on `codex/runner-manager-p0-hardening`.

## Confirmed changes

- `runnerctl` remains the only formal management entrypoint.
- Legacy entrypoints, if present, are required by test to delegate to `runnerctl` rather than keeping independent Docker or runner orchestration logic.
- `compose.yaml` now forwards both `NO_PROXY` and `no_proxy` to runner containers, with default local bypass entries.
- `runner/entrypoint.sh` starts `run.sh` with management-only credentials removed from the child environment.
- Docker socket contract tests accept the safe quoted `chmod g+rw "$socket"` form and reject broad world-writable chmod modes.

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

## P2 backlog not implemented in P0

- GitHub App based credential split.
- Ephemeral runner migration.
- Docker socket proxy redesign.
- Rootless Docker or dedicated VM migration.
- Automatic scaling.
