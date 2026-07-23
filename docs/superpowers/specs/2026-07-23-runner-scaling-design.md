# Runner Scaling Design

## Goal

Add safe one-command scaling helpers for complex local self-hosted runner workloads while keeping manual control, predictable labels, and safe downscaling behavior.

## Scope

This P1-A slice implements deterministic instance-file management commands only. It does not implement queue-driven autoscaling, GitHub API busy detection, job hooks, dynamic port allocation, or cross-repository workflow changes.

## Commands

### `add-worker <base> <worker-id> [--start] [--join-pool]`

Creates `instances/<base>-<worker-id>.env` from `instances/<base>.env`.

Rules:

- The base instance must exist and be readable.
- The worker instance must not already exist.
- `GITHUB_REPOSITORY` is copied from the base.
- `RUNNER_GROUP`, `RUNNER_WORKDIR`, and `RUNNER_EPHEMERAL` are copied from the base when present.
- `RUNNER_NAME` is `home-<base>-<worker-id>-runner`.
- Default labels are `lan,docker,home,<base>-<worker-id>`.
- With `--join-pool`, labels are `lan,docker,home,<base>,<base>-<worker-id>`.
- `--start` starts the worker after creating the file.

### `scale <base> <count> [--start] [--join-pool]`

Ensures exactly `count` configured instances for a base pool including the base instance.

Rules:

- `count` must be at least `1`.
- `count=1` only ensures the base exists; it does not stop or remove workers.
- Missing workers are created as `<base>-w01`, `<base>-w02`, ... up to `count - 1`.
- Existing worker files are left unchanged.
- With `--start`, newly-created workers are started.
- With `--join-pool`, newly-created workers are created with the base shared label.

### `downscale <base> <count> [--stop-only|--remove-config] [--force]`

Reduces a pool to `count` configured/running instances including the base.

Rules:

- `count` must be at least `1`; the base instance is never stopped or removed.
- Workers above the desired count are selected in descending worker suffix order.
- Default mode is `--stop-only`: stop selected workers but keep env files.
- `--remove-config` removes selected workers only when the container is not running unless `--force` is passed.
- `--force` allows removing config after stopping a running worker.
- No command deletes unrelated instances.

### `workers <base>`

Lists base and workers that match `<base>-wNN`.

### `pool-join <worker> <shared-label>` / `pool-leave <worker> <shared-label>`

Adds or removes one shared label in an instance env file without touching other labels.

## Safety Constraints

- No token values are printed.
- No command touches `.env` secrets.
- No command modifies Docker socket permissions.
- No command calls `docker system prune`.
- No command deletes any instance that is not an exact base worker match.
- Heavy E2E workloads should remain on isolated worker labels until their resource and port isolation is verified.

## Testing

Add contract tests covering:

- `add-worker` creates an isolated worker by default.
- `add-worker --join-pool` includes both shared and worker labels.
- `scale` creates missing workers without modifying existing workers.
- `downscale --stop-only` stops only selected workers and preserves env files.
- `downscale --remove-config --force` removes only selected worker env files.
- `pool-join` and `pool-leave` edit labels idempotently.
- Commands reject invalid counts, missing base instances, and existing target workers.
