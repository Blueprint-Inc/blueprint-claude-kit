---
name: start-work
description: Start an isolated git worktree on a project's base branch for a new task
---

# /start-work — Isolated Work Session

Set up an isolated git worktree so this session can never collide with other
parallel sessions on the same repo, then begin the task. Never do the work in the
repo's main checkout.

**Task:** the input this skill was invoked with. Reason over it to identify the task;
it may come from the user or from another skill that invoked this one with a payload.
If no task is supplied, ask for one — never proceed against an empty task.

## Steps

1. **Verify gcloud is logged in** (when gcloud is installed). Many Blueprint
   projects need GCP credentials for deploys, BigQuery, or Cloud Functions.
   If `command -v gcloud` succeeds, run:
   `gcloud auth print-access-token >/dev/null 2>&1`
   - **Success:** note the active account (`gcloud config get-value account`) and continue.
   - **Failure (not logged in / expired):** **STOP.** Do not create a worktree yet.
     Tell the user:

     ```
     gcloud is not logged in (or credentials expired). Run this in your terminal, then tell me when you're done:

     gcloud auth login
     ```

     After they confirm, re-run the check. Do not proceed until it succeeds.
   - **gcloud not installed:** skip this check (not every machine/project needs it).

2. **Identify the target repo.** Run `git rev-parse --show-toplevel`. If the cwd is
   not inside a git repo, stop and ask which repo to work in (or have the user
   `cd` into it). Everything below runs against that repo.

3. **Determine the BASE branch** (what new work branches from):
   - If the repo directory is named `blueprintos`, the base is **`staging`** — it
     integrates on staging, not prod, so branching from prod starts you behind
     everything mid-deploy.
   - Otherwise the base is the repo's default branch:
     `git symbolic-ref --quiet refs/remotes/origin/HEAD | sed 's#refs/remotes/origin/##'`
     (usually `main`).

4. **Refresh the base** so the worktree is cut from current code:
   `git checkout <base> && git fetch --prune && git pull --ff-only`.
   If the tree is dirty and checkout/pull is blocked, **STOP and report exactly
   what's uncommitted** — never discard or stash without asking.

5. **Scan for active sibling sessions** (awareness — the rest of the repo is
   invisible from inside a worktree, yet every worktree shares one `.git`, so two
   sessions can clobber the *same logical file* at merge time). Run
   `git worktree list`; for each *other* worktree, run
   `git -C <path> status --porcelain` and note its branch. Report which ones are
   actively editing and the files involved — call it out loudly if any overlap the
   area this task will touch. Informational only; don't block.

6. **Create the worktree.** Pick a short kebab-case slug for the task and create a
   worktree whose branch name matches it — `feat/<slug>`, `fix/<slug>`, or
   `chore/<slug>` depending on the task — so directory and branch stay in sync
   (this prevents the branch≠dir drift that makes parallel sessions confusing).
   Use your environment's native worktree tool if it has one; otherwise:
   `git worktree add .worktrees/<slug> -b <prefix>/<slug> <base>` and `cd` into it.

7. **Bootstrap per-machine files (if the project provides a script).** A fresh
   worktree contains only *tracked* files, so every gitignored per-machine artifact
   (local config, installed dependencies, local credentials) is absent — the project
   often can't build, run its tests, or reach a local DB until they're restored. If
   the new worktree contains an executable `scripts/worktree-setup.sh`, run it
   (`bash scripts/worktree-setup.sh`) and report its output. It should be idempotent
   (a no-op when nothing needs restoring). Projects without that script skip this
   step. Keep all project-specific bootstrap logic inside the script, never here.

8. **Confirm and begin.** Report the worktree path, the branch, and the base it was
   cut from. Then start the task using the **Compound Engineering (`/ce-*`) skills by
   default** — for anything non-trivial (3+ steps or an architectural decision),
   run `/ce-brainstorm` to explore requirements, then `/ce-plan`, then implement
   (optionally via `/ce-work`), and `/ce-code-review` before `/finish-work`.
   Prefer the `ce` skills over their `superpowers:*` equivalents (e.g.
   `ce-brainstorm` over `superpowers:brainstorming`, `ce-plan` over
   `superpowers:writing-plans`) whenever both could apply.
