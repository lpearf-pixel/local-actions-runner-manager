# Local Actions Runner Manager

Docker Compose deployment for a repository-scoped GitHub Actions self-hosted runner on a home or office LAN computer.

> A runner inside Docker Desktop is a **Linux runner**, even when Docker Desktop runs on macOS. Do not label it as a macOS runner.

## Features

- Supports Docker hosts using `amd64` or `arm64`
- Downloads the matching current GitHub Actions runner during image build
- Requests a short-lived registration token at startup
- Unregisters the runner on graceful shutdown
- Persists the Actions work directory
- Supports Docker-based jobs through the host Docker socket
- Includes local validation and a manual smoke-test workflow

## 1. Requirements

Install Docker Desktop or Docker Engine on the computer that will execute jobs.

Create a GitHub token that can manage repository self-hosted runners. Store it only in `.env` and never commit it.

For a fine-grained personal access token, grant the target repository `Administration: Read and write`. For a classic token on a private repository, use the `repo` scope.

## 2. Configure

```bash
cp .env.example .env
```

Edit `.env`:

```dotenv
GITHUB_REPOSITORY=lpearf-pixel/example-repository
GITHUB_TOKEN=github_pat_xxx
RUNNER_NAME=home-runner-01
RUNNER_LABELS=lan,docker,home
RUNNER_GROUP=Default
```

`GITHUB_REPOSITORY` is the repository whose workflows will use this runner. It does not have to be this manager repository.

## 3. Start

```bash
./scripts/start.sh
```

Check it:

```bash
./scripts/status.sh
./scripts/logs.sh
```

GitHub displays the runner under `Repository → Settings → Actions → Runners`.

## 4. Use it from another LAN computer

Other computers do not connect directly to the runner. They only push code to GitHub. GitHub queues the workflow and the runner pulls the job over outbound HTTPS.

Use these labels in the target repository:

```yaml
jobs:
  test:
    runs-on: [self-hosted, Linux, ARM64, lan]
    steps:
      - uses: actions/checkout@v4
      - run: uname -a
      - run: docker version
```

On an Intel/AMD Docker host, replace `ARM64` with `X64`. GitHub adds the OS and architecture labels automatically.

## Commands

```bash
./scripts/start.sh
./scripts/status.sh
./scripts/logs.sh
./scripts/stop.sh
./scripts/validate.sh
```

## Multiple repositories

A repository-scoped runner serves one repository. For multiple repositories, create one Compose project and environment file per repository:

```bash
docker compose -p runner-kanyu --env-file env/kanyu.env up -d --build
docker compose -p runner-kaiyuan --env-file env/kaiyuan.env up -d --build
```

Use a unique `RUNNER_NAME` for each instance. Repository-level isolation is the safe default.

## Security

- Do not execute untrusted pull requests on a self-hosted runner.
- Never commit `.env` or GitHub tokens.
- Mounting `/var/run/docker.sock` gives jobs powerful access to the Docker host. Remove the mount when Docker is unnecessary.
- Prefer a dedicated computer or OS account.
- Restrict runner workflows to trusted branches and repositories.

## Network

No inbound port is required. The runner needs outbound HTTPS to GitHub and any package or container registries used by workflows. LAN computers only need normal Git/GitHub access.
