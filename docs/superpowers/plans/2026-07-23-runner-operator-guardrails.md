# Runner Operator Guardrails Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make self-hosted runner limits and local-environment risks visible to every caller before they rely on a local runner.

**Architecture:** Add a concise operator contract document for workflow authors, expose host health through `runnerctl doctor-host`, and improve `runnerctl status` so instance identity is explicit. Keep the existing bash-only workflow and avoid Make/Xcode/Homebrew requirements.

**Tech Stack:** Bash, Docker CLI, Docker Compose v2, Markdown, shell contract tests.

## Global Constraints

- Invoke through `bash ./runnerctl`; executable permissions must not be required.
- Do not require Homebrew, Xcode, or host-level package installation.
- One repository-scoped runner process can execute only one GitHub Actions job at a time.
- Multiple instances for the same repository must use unique `RUNNER_NAME` values and shared project labels.
- Do not delete Docker volumes or runner work directories as part of diagnostics.

---

### Task 1: Operator Contract Documentation

**Files:**
- Create: `docs/runner-operator-contract.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: existing `instances/*.env` model.
- Produces: caller-facing contract explaining local runner limits and when to use hosted vs local runners.

- [ ] **Step 1: Add the operator contract document**

Create `docs/runner-operator-contract.md` with sections covering runner model, differences from GitHub hosted runners, safe workflow labels, concurrency, diagnostics, and failure triage.

- [ ] **Step 2: Link the contract from README**

Add a short "Before using local runners" section near the top of README linking to `docs/runner-operator-contract.md`.

- [ ] **Step 3: Commit**

```bash
git add README.md docs/runner-operator-contract.md
git commit -m "docs: add local runner operator contract"
```

### Task 2: Host Doctor Command

**Files:**
- Modify: `runnerctl`
- Create or modify: `tests/runnerctl-doctor-host.test.sh`

**Interfaces:**
- Produces command: `bash ./runnerctl doctor-host`
- Produces output fields: Docker CLI installed, Docker daemon reachable, Docker context, Docker client/server versions, socket path, CPU/memory hint when available.

- [ ] **Step 1: Write the contract test**

Add a shell test that verifies `runnerctl` usage contains `doctor-host`, the dispatch case includes it, and the implementation checks `docker info`, `docker version`, and `/var/run/docker.sock` or `$HOME/.docker/run/docker.sock`.

- [ ] **Step 2: Implement `doctor-host`**

Add a `doctor_host` function that prints readable checks without mutating Docker state.

- [ ] **Step 3: Commit**

```bash
git add runnerctl tests/runnerctl-doctor-host.test.sh
git commit -m "feat: add host doctor for local runners"
```

### Task 3: Clear Instance Identity in Status

**Files:**
- Modify: `runnerctl`
- Create or modify: `tests/runnerctl-status-contract.test.sh`

**Interfaces:**
- Existing command remains: `bash ./runnerctl status [name]`
- Status table gains explicit `RUNNER_NAME` and `LABELS` columns.

- [ ] **Step 1: Write the status contract test**

Verify that `status_all` reads `RUNNER_NAME` and `RUNNER_LABELS`, and that the header includes `INSTANCE`, `REPOSITORY`, `RUNNER_NAME`, `LABELS`, and `STATUS`.

- [ ] **Step 2: Implement richer status output**

Update `status_all` to display instance name, repository, configured GitHub runner name, labels, and Docker status.

- [ ] **Step 3: Commit**

```bash
git add runnerctl tests/runnerctl-status-contract.test.sh
git commit -m "feat: show runner identity in status"
```

### Task 4: Validation

**Files:**
- Existing tests under `tests/*.test.sh`

**Interfaces:**
- Command: `find tests -name '*.test.sh' -print | sort | while read -r t; do bash "$t"; done`

- [ ] **Step 1: Run all shell contract tests**

Expected: every test exits zero.

- [ ] **Step 2: Run local smoke commands when Docker is available**

```bash
bash ./runnerctl doctor-host
bash ./runnerctl status
```

Expected: commands print diagnostics and do not change containers.
