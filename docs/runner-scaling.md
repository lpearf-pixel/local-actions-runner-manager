# Safe Runner Scaling Guide

This guide covers P1-A scaling commands. Scaling creates or removes runner instance configuration; it does not change GitHub workflow files or business repositories.

## Key idea

One `instances/*.env` file defines one runner instance. One runner instance can execute one GitHub Actions job at a time. More parallel jobs require more instances.

## Create an isolated worker

Use an isolated worker first for complex or heavy jobs:

```bash
bash ./runnerctl add-worker community w01 --start
```

This creates:

```text
instances/community-w01.env
```

Default labels stay isolated:

```dotenv
RUNNER_LABELS=lan,docker,home,community-w01
```

A workflow must target the worker label explicitly:

```yaml
runs-on: [self-hosted, Linux, community-w01]
```

## Join a shared pool

Only join the shared pool after the worker is verified:

```bash
bash ./runnerctl pool-join community-w01 community
bash ./runnerctl restart community-w01
```

Or create the worker already joined:

```bash
bash ./runnerctl add-worker community w01 --join-pool --start
```

Shared-pool labels look like:

```dotenv
RUNNER_LABELS=lan,docker,home,community,community-w01
```

A workflow targeting the shared label can then land on either runner:

```yaml
runs-on: [self-hosted, Linux, community]
```

## Scale configured workers

Create missing worker env files up to a total pool size, including the base instance:

```bash
bash ./runnerctl scale community 3
```

This ensures:

```text
community
community-w01
community-w02
```

Existing worker files are not mutated. Add `--join-pool` only when new workers should receive the base shared label. Add `--start` only when new workers should be started immediately.

## Downscale safely

Temporary shrink while keeping config:

```bash
bash ./runnerctl downscale community 1 --stop-only
```

Permanent shrink after verification:

```bash
bash ./runnerctl downscale community 1 --remove-config --force
```

Rules:

- The base instance is never stopped or removed.
- Workers are selected from highest suffix down, such as `w03`, then `w02`, then `w01`.
- `--stop-only` preserves `instances/*.env` for later restart.
- `--remove-config` deletes only exact worker env files selected for downscale.
- Unrelated instances are never selected.

## List workers

```bash
bash ./runnerctl workers community
```

Example output:

```text
community
community-w01
community-w02
```

## Complex work guidance

Heavy E2E jobs that use fixed ports, shared Docker resources, or local databases should stay on isolated labels until the workflow has run-specific names and ports. Use shared-pool labels only for jobs that are safe to run concurrently.
