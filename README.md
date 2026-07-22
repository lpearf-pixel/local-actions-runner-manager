# Local Actions Runner Manager

Docker Compose manager for multiple repository-scoped GitHub Actions self-hosted runners on one home or office computer.

> A runner inside Docker Desktop is a Linux runner, even when Docker Desktop runs on macOS.

## Features

- One isolated Compose project per GitHub repository
- One shared root `.env` for GitHub token and proxy settings
- One `instances/<name>.env` file per repository
- `amd64` and `arm64` runner images
- Automatic runner registration and graceful unregistration
- Docker socket support for workflows that build containers
- macOS-compatible temporary-file handling
- `clean` and `doctor` diagnostics
- Makefile commands that do not depend on executable file permissions

## Requirements

Install Docker Desktop or Docker Engine on the computer that will execute jobs.

Create a GitHub token that can manage repository self-hosted runners. Store it only in `.env` and never commit it.

For a fine-grained personal access token, grant each target repository `Administration: Read and write`. For a classic token on a private repository, use the `repo` scope.

## Configure shared settings

```bash
cp .env.example .env
```

Edit the root `.env`:

```dotenv
GITHUB_TOKEN=github_pat_xxx

HTTP_PROXY=http://192.168.2.28:8001
HTTPS_PROXY=http://192.168.2.28:8001
NO_PROXY=localhost,127.0.0.1,host.docker.internal

RUNNER_GROUP=Default
RUNNER_WORKDIR=_work
RUNNER_EPHEMERAL=false
RUNNER_LABELS=lan,docker,home
```

The token and proxy are shared by all configured runner instances.

## Recommended command interface

Use `make` commands. They invoke `bash ./runnerctl` internally, so no `chmod` is required after cloning or pulling.

One-time setup for an existing checkout:

```bash
git config core.fileMode false
git restore runnerctl scripts runner 2>/dev/null || true
git pull --ff-only
make setup
```

Create and start a runner:

```bash
make create NAME=chan-shuo REPO=lpearf-pixel/chan-shuo
make start NAME=chan-shuo
```

Check it:

```bash
make status NAME=chan-shuo
make doctor NAME=chan-shuo
make logs NAME=chan-shuo
```

GitHub displays the runner under:

```text
Repository → Settings → Actions → Runners
```

## Multiple repositories

Create one instance for each repository:

```bash
make create NAME=kanyu REPO=lpearf-pixel/kanyu-spatial-engine
make create NAME=community REPO=lpearf-pixel/community-selection-miniapp
```

This creates:

```text
instances/chan-shuo.env
instances/kanyu.env
instances/community.env
```

Each instance file contains repository-specific values only:

```dotenv
GITHUB_REPOSITORY=lpearf-pixel/chan-shuo
RUNNER_NAME=home-chan-shuo-runner
RUNNER_LABELS=lan,docker,home,chan-shuo
RUNNER_GROUP=Default
RUNNER_WORKDIR=_work
RUNNER_EPHEMERAL=false
```

Start or stop all configured runners:

```bash
make start-all
make stop-all
```

List all instances:

```bash
make status
```

## Cleanup and diagnostics

Clean stale temporary files only:

```bash
make clean
```

Clean temporary files and remove the selected instance container/network while preserving its configuration and work volume:

```bash
make clean NAME=chan-shuo
```

Run end-to-end diagnostics:

```bash
make doctor NAME=chan-shuo
```

The doctor checks Docker, shared token configuration, merged Compose configuration, container state, proxy propagation, `Runner.Listener`, and GitHub API connectivity.

## Other commands

```bash
make restart NAME=chan-shuo
make stop NAME=chan-shuo
make remove NAME=chan-shuo
make list
make help
```

Direct invocation also works without executable permission:

```bash
bash ./runnerctl start chan-shuo
bash ./scripts/clean.sh chan-shuo
```

## Workflow labels

Use the repository-specific label generated for the instance:

```yaml
jobs:
  test:
    runs-on: [self-hosted, Linux, chan-shuo]
    steps:
      - uses: actions/checkout@v4
      - run: uname -a
      - run: docker version
```

GitHub adds the operating-system and architecture labels automatically.

## Script permissions

The repository contains a small workflow that normalizes command scripts to Git mode `100755`. The Makefile remains the supported fallback on filesystems or sync tools that do not preserve Unix executable bits.

Do not repeatedly run local `chmod` as part of normal operation. Local permission changes can appear as Git modifications and block pulling on some machines.

## Security

- Do not execute untrusted pull requests on a self-hosted runner.
- Never commit `.env`, instance secrets, or GitHub tokens.
- Mounting `/var/run/docker.sock` gives jobs powerful access to the Docker host.
- Prefer a dedicated computer or OS account.
- Restrict runner workflows to trusted branches and repositories.

## Network

No inbound port is required. The runner needs outbound HTTPS to GitHub and any package or container registries used by workflows. Other LAN computers only push code to GitHub; they do not connect directly to the runner.
