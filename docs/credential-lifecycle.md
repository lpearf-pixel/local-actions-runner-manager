# Management Credential Lifecycle

This repository uses a management GitHub token only to register, remove, or inspect repository-scoped self-hosted runners.

## Rules

- Store the management token only in the manager `.env` file.
- Do not commit tokens, runner registration tokens, cookies, private URLs, or machine-specific secrets.
- The runner container receives `GITHUB_TOKEN` at startup because GitHub registration requires it.
- After `config.sh` completes, `runner/entrypoint.sh` starts `run.sh` with management-only variables removed from the child environment.
- Jobs should use the normal GitHub Actions-provided per-job `GITHUB_TOKEN` when a workflow explicitly grants it, not the manager PAT.

## Variables removed before `run.sh`

The entrypoint removes at least:

```text
GITHUB_TOKEN
GH_TOKEN
RUNNER_TOKEN
REGISTRATION_TOKEN
REMOVE_TOKEN
MANAGEMENT_GITHUB_TOKEN
ACTIONS_RUNNER_INPUT_TOKEN
```

The parent entrypoint process keeps a derived authorization header only for cleanup while the listener is running. That value must not be printed in logs, doctor output, JSON, or test fixtures.

## Future work

A GitHub App or repository-specific credential split may further reduce the blast radius. That is tracked as P2 work and is not implemented in P0.
