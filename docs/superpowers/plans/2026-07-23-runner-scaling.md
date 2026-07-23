# Safe Runner Scaling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add safe runner scaling commands for creating, listing, pool-labeling, and downscaling worker instances.

**Architecture:** Extend `runnerctl` with pure instance-file helpers first, then wire them into command dispatch. Scaling commands use existing `create_instance`, `compose_instance`, `stop`, and `remove` behavior where possible, but never touch unrelated instances or secrets.

**Tech Stack:** Bash, Docker Compose via existing `runnerctl`, shell contract tests.

## Global Constraints

- Do not modify host Docker socket permissions.
- Do not print PATs, registration tokens, cookies, or private URLs.
- Do not execute `docker system prune` or broad Docker cleanup.
- Do not start or stop existing live instances during tests.
- Default worker labels stay isolated unless `--join-pool` is passed.
- Base instance is never stopped or removed by `downscale`.

---

### Task 1: Scaling Contract Tests

**Files:**
- Create: `tests/runnerctl-scaling-contract.test.sh`

**Interfaces:**
- Consumes: `runnerctl` CLI.
- Produces: executable contract test used by GitHub Actions matrix.

- [ ] **Step 1: Write failing test**

Create a temp checkout, copy `runnerctl` and `compose.yaml`, create `.env` and `instances/community.env`, stub `docker`, and verify:

```bash
bash ./runnerctl add-worker community w01
bash ./runnerctl add-worker community w02 --join-pool
bash ./runnerctl scale community 4 --join-pool
bash ./runnerctl downscale community 2 --stop-only
bash ./runnerctl pool-leave community-w02 community
bash ./runnerctl pool-join community-w02 community
```

- [ ] **Step 2: Verify fail before implementation**

Run: `bash tests/runnerctl-scaling-contract.test.sh`
Expected: FAIL because commands are unknown.

- [ ] **Step 3: Commit test**

```bash
git add tests/runnerctl-scaling-contract.test.sh
git commit -m "test: cover runner scaling commands"
```

### Task 2: Instance File Helpers

**Files:**
- Modify: `runnerctl`

**Interfaces:**
- Produces `set_env_value(file, key, value)`, `append_label(label_string, label)`, `remove_label(label_string, label)`, `worker_name(base, worker_id)`, `is_worker_for(base, name)`.

- [ ] **Step 1: Add helper implementation**

Implement portable awk/temp-file based env editing and comma-label helpers.

- [ ] **Step 2: Run focused test**

Run: `bash tests/runnerctl-scaling-contract.test.sh`
Expected: still FAIL on command dispatch or missing scaling functions.

- [ ] **Step 3: Commit helpers**

```bash
git add runnerctl
git commit -m "refactor: add runner instance env helpers"
```

### Task 3: Add Worker, Pool Join, Pool Leave

**Files:**
- Modify: `runnerctl`

**Interfaces:**
- Produces commands `add-worker`, `pool-join`, `pool-leave`.

- [ ] **Step 1: Implement commands**

`add-worker` copies base metadata, creates worker env, applies labels, and optionally starts the worker.

- [ ] **Step 2: Run focused test**

Run: `bash tests/runnerctl-scaling-contract.test.sh`
Expected: FAIL only for `scale` or `downscale` until Task 4.

- [ ] **Step 3: Commit commands**

```bash
git add runnerctl
git commit -m "feat: add safe worker creation commands"
```

### Task 4: Scale, Downscale, Workers

**Files:**
- Modify: `runnerctl`

**Interfaces:**
- Produces commands `scale`, `downscale`, and `workers`.

- [ ] **Step 1: Implement commands**

`scale` creates missing `wNN` workers. `downscale` selects workers in descending order and stops or removes exact worker instances. `workers` lists matching base workers.

- [ ] **Step 2: Run focused test**

Run: `bash tests/runnerctl-scaling-contract.test.sh`
Expected: PASS.

- [ ] **Step 3: Run full local contract suite**

Run: `find tests -type f -name '*.test.sh' -print | sort | while read -r t; do bash "$t"; done`
Expected: PASS.

- [ ] **Step 4: Commit commands**

```bash
git add runnerctl tests/runnerctl-scaling-contract.test.sh
git commit -m "feat: add safe runner scaling commands"
```

### Task 5: Documentation and PR Verification

**Files:**
- Modify: `README.md`
- Modify: `docs/runner-operator-contract.md`
- Modify: `.github/workflows/normalize-script-modes.yml`

**Interfaces:**
- Documents user-facing commands and includes scaling test in CI matrix.

- [ ] **Step 1: Document scaling commands**

Add examples for isolated test workers, shared-pool join, stop-only downscale, and remove-config downscale.

- [ ] **Step 2: Update CI matrix**

Add `tests/runnerctl-scaling-contract.test.sh` to the regression matrix.

- [ ] **Step 3: Run full local contract suite**

Run all shell tests.
Expected: PASS.

- [ ] **Step 4: Open PR and verify GitHub Actions**

Open PR from `codex/runner-manager-p1-resilience` to `main`.
Expected: shell syntax and all regression tests pass.
