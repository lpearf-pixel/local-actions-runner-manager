# Local Runner Operator Contract

This project runs GitHub Actions self-hosted runners on a local machine through Docker Compose. Treat it as a small local CI cluster, not as a drop-in replacement for GitHub-hosted runners.

## What callers must know first

- One runner process can execute only one GitHub Actions job at a time.
- More parallel jobs require more runner instances.
- A runner created by this manager is repository-scoped through `GITHUB_REPOSITORY`; it does not serve every repository automatically.
- A Docker Desktop based runner has more moving parts than `ubuntu-latest`: host Docker Desktop, Docker socket, runner container, Docker CLI compatibility, proxy, token permissions, and persistent runner state.
- Keep simple lint, typecheck, and unit tests on GitHub-hosted runners unless the job must use local Docker, LAN services, private models, local databases, or hardware.

## Instance model

Each `instances/<name>.env` file defines one independent runner instance.

```dotenv
GITHUB_REPOSITORY=lpearf-pixel/community-selection-miniapp
RUNNER_NAME=home-community-runner
RUNNER_LABELS=lan,docker,home,community
RUNNER_GROUP=Default
RUNNER_WORKDIR=_work
RUNNER_EPHEMERAL=false
```

Rules:

- `GITHUB_REPOSITORY` selects the GitHub repository that receives the runner.
- `RUNNER_NAME` must be unique across concurrently running instances.
- `RUNNER_LABELS` should include one shared project label, such as `community`, so workflows can target the pool.
- Extra per-instance labels, such as `community-w01`, are useful for debugging or pinning a workflow to a single runner.

## Scaling pattern

For two runners serving the same repository:

```text
instances/community.env
instances/community-w01.env
```

Use the same repository and shared label, but unique runner names.

```dotenv
# instances/community.env
GITHUB_REPOSITORY=lpearf-pixel/community-selection-miniapp
RUNNER_NAME=home-community-runner
RUNNER_LABELS=lan,docker,home,community
```

```dotenv
# instances/community-w01.env
GITHUB_REPOSITORY=lpearf-pixel/community-selection-miniapp
RUNNER_NAME=home-community-w01
RUNNER_LABELS=lan,docker,home,community,community-w01
```

A workflow can target the shared pool:

```yaml
runs-on: [self-hosted, Linux, community]
```

Or a specific runner during debugging:

```yaml
runs-on: [self-hosted, Linux, community-w01]
```

## Hosted runner vs local runner

Use GitHub-hosted runners for jobs that only need a clean Linux environment:

```yaml
runs-on: ubuntu-latest
```

Use local runners for jobs that require local capabilities:

```yaml
runs-on: [self-hosted, Linux, community]
```

Good local-runner use cases:

- Docker builds that must use the local Docker cache.
- Tests needing LAN-only services.
- Private models, local databases, mounted datasets, or hardware.
- Long-running or expensive workloads that are safe to run on trusted code.

Avoid local runners for untrusted pull requests. Mounting `/var/run/docker.sock` gives the job powerful access to the Docker host.

## Credential contract

Read [Management Credential Lifecycle](credential-lifecycle.md) before changing the runner entrypoint or Compose environment.

- The manager `.env` contains the management GitHub token used to register, remove, or inspect repository-scoped runners.
- The runner container receives that token only so `entrypoint.sh` can call GitHub's runner registration/removal APIs.
- After `config.sh` completes, `entrypoint.sh` starts `run.sh` with management-only token variables removed from the child environment.
- Jobs should rely on GitHub Actions' normal per-job `GITHUB_TOKEN` only when the workflow grants it.
- Logs, doctor output, JSON output, and tests must not print real tokens, registration tokens, cookies, private URLs, or secrets.

## Proxy and local-network contract

Compose passes both uppercase and lowercase proxy bypass variables:

```dotenv
NO_PROXY=localhost,127.0.0.1,host.docker.internal
no_proxy=localhost,127.0.0.1,host.docker.internal
```

Rules:

- Container runners usually reach host services through `host.docker.internal`.
- Physical-machine runners usually reach host services through `127.0.0.1`.
- Local Docker, local databases, local APIs, and health checks should not leave through an external proxy.
- User-specific proxy additions may be appended in `.env`; do not silently remove the default local bypass values.

## Pre-flight checks

Before relying on local runners:

```bash
bash ./runnerctl doctor-host
bash ./runnerctl status
bash ./runnerctl doctor <instance>
```

`doctor-host` checks the local Docker host. `doctor <instance>` checks a specific runner container and GitHub connectivity.

## Common failure meanings

| Symptom | Likely layer | First check |
| --- | --- | --- |
| `Cannot connect to the Docker daemon` | Host Docker Desktop stopped or crashed | `bash ./runnerctl doctor-host` |
| `API returned a 400 Bad Request` from container Docker CLI | Runner container Docker CLI is incompatible with host Docker daemon | Rebuild the runner image after pulling the pinned CLI fix |
| `Cannot configure the runner because it is already configured` | Runner state persisted across container restart | Pull latest manager; current entrypoint reuses existing `.runner/.credentials` |
| Only one job runs at a time | Only one runner instance exists for that repository | Add another `instances/<project>-w01.env` with the same shared label |
| Workflow never lands on the new instance | Labels do not match `runs-on` | Check `RUNNER_LABELS` in `bash ./runnerctl status` |
| Local database or API calls route through the proxy | Missing `NO_PROXY` / `no_proxy` local bypass | Check merged Compose config and runner container environment |
| Management PAT appears inside a job environment | Credential isolation regression | Stop using that image and inspect `runner/entrypoint.sh` before restarting runners |

## Resource guidance

A Docker Desktop host with about 4 CPUs and 8 GiB RAM should start conservatively:

```text
community + community-w01
chan-shuo + chan-shuo-w01
```

Avoid enabling many heavy local runners at once until Docker Desktop remains stable under load.

## Caller checklist

Before adding `runs-on: [self-hosted, ...]` to another repository, confirm:

- The job cannot be handled by `ubuntu-latest`.
- The target repository has an `instances/*.env` file.
- The shared project label in `RUNNER_LABELS` matches the workflow label.
- `RUNNER_NAME` is unique.
- `bash ./runnerctl doctor-host` passes.
- `bash ./runnerctl doctor <instance>` passes after the container starts.
- The workflow does not require untrusted pull request execution on a Docker-socket runner.
