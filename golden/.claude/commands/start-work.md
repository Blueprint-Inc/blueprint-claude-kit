---
name: start-work
description: Start an isolated git worktree on a project's base branch for a new task
user_invocable: true
---

# /start-work — Isolated Work Session

Set up an isolated git worktree so this session can never collide with other
parallel sessions on the same repo, then begin the task. Never do the work in the
repo's main checkout.

**Task:** $ARGUMENTS

## Steps

1. **Identify the target repo.** Run `git rev-parse --show-toplevel`. If the cwd is
   not inside a git repo, stop and ask which repo to work in (or have the user
   `cd` into it). Everything below runs against that repo.

2. **Determine the BASE branch** (what new work branches from):
   - If the repo directory is named `blueprintos`, the base is **`staging`** — it
     integrates on staging, not prod, so branching from prod starts you behind
     everything mid-deploy.
   - Otherwise the base is the repo's default branch:
     `git symbolic-ref --quiet refs/remotes/origin/HEAD | sed 's#refs/remotes/origin/##'`
     (usually `main`).

3. **Refresh the base** so the worktree is cut from current code:
   `git checkout <base> && git fetch --prune && git pull --ff-only`.
   If the tree is dirty and checkout/pull is blocked, **STOP and report exactly
   what's uncommitted** — never discard or stash without asking.

4. **Create the worktree.** Pick a short kebab-case slug for the task and create a
   worktree whose branch name matches it — `feat/<slug>`, `fix/<slug>`, or
   `chore/<slug>` depending on the task — so directory and branch stay in sync
   (this prevents the branch≠dir drift that makes parallel sessions confusing).
   Use your environment's native worktree tool if it has one; otherwise:
   `git worktree add .worktrees/<slug> -b <prefix>/<slug> <base>` and `cd` into it.

5. **Confirm and begin.** Report the worktree path, the branch, and the base it was
   cut from. Then start the task using the **Compound Engineering (`/ce-*`) skills by
   default** — for anything non-trivial (3+ steps or an architectural decision),
   run `/ce-brainstorm` to explore requirements, then `/ce-plan`, then implement
   (optionally via `/ce-work`), and `/ce-code-review` before `/finish-work`.
   Prefer the `ce` skills over their `superpowers:*` equivalents (e.g.
   `ce-brainstorm` over `superpowers:brainstorming`, `ce-plan` over
   `superpowers:writing-plans`) whenever both could apply.
