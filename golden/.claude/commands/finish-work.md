---
name: finish-work
description: Finish the current worktree branch — commit, push, PR, then clean up
user_invocable: true
---

# /finish-work — Ship & Clean Up

Close out the current work session. This should be running inside an isolated
worktree created by `/start-work`.

**Optional context:** $ARGUMENTS

## Steps

1. **Confirm you're in a worktree.** Run `git rev-parse --show-toplevel`; it should
   be under `.worktrees/` or `.claude/worktrees/`. If you're in the repo's main
   checkout, STOP and ask — do not commit or push from the root.

2. **Show what will ship.** Determine the base branch (staging for `blueprintos`,
   the default branch otherwise) and run `git status` plus
   `git diff --stat <base>...HEAD`. Summarize the change in a sentence or two.

3. **Clobber check against other worktrees** (they share this repo's `.git` but are
   invisible from your worktree). List your changed paths —
   `git diff --name-only <base>...HEAD` — they're repo-relative. For every *other*
   worktree (`git worktree list`), gather its in-flight paths: uncommitted
   (`git -C <path> status --porcelain`) plus committed-but-unmerged
   (`git -C <path> diff --name-only <base>...HEAD`). If any path overlaps yours,
   **WARN clearly** — name the file and the other branch/worktree — so you can
   coordinate before the merge clobbers their work. Advisory: proceed, but surface it.

4. **Commit.** Stage and commit any uncommitted work with a clear, specific message
   following the repo's conventions, ending with the `Co-Authored-By` trailer.
   **Ask first** if the diff includes anything unexpected — secrets, unrelated
   files, debug/TODO strings, or generated artifacts.

5. **Find related issues this work closes.** Catch issues the change resolves but
   nobody linked. Pull open issues — `gh issue list --state open --json number,title,labels,body`
   (or, in Task-Tracker mode, scan `tasks/todo.md` for active `T-NN` rows). Match
   them against this branch's slug, the commit subjects (`git log <base>..HEAD --format='%s'`),
   and the changed file areas; surface every plausible hit as `#<n> — <title>` with a
   one-line *why it matched*. For each, decide:
   - **Close on merge** — add `Closes #<n>` to the PR body, but ONLY when the PR
     targets the repo's **default branch**. `Closes` does nothing on a non-default
     base, so for blueprintos staging PRs reference the issue in the body instead and
     plan to close it after merge (via `/close-issue` or a summary comment).
   - **Don't close** — if the issue is a monitoring / `in-staging` item, or its
     acceptance criteria say to close only after a soak period ("confirm 1–2 weeks",
     "monitor for recurrence"), link it but leave it open. Default to NOT closing when
     unsure — surfacing a missed issue is the win; premature closure is a regression.
   Confirm the close list with the user before baking any `Closes #<n>` into the PR.

6. **Push + PR.** Push the branch and open a PR **targeting the base branch this was
   cut from** (staging for blueprintos, the default branch otherwise) via
   `gh pr create`. Write a value-first description: what changed and why, scaled to
   the size of the change — not a file-by-file dump. Include the `Closes #<n>` lines
   agreed in step 5 (only when the PR targets the default branch).

7. **Report + clean up.** Print the PR URL, then ask whether to remove the worktree
   now or keep it until the PR merges. On confirmation, switch out of it and run
   `git worktree remove <path>` then `git worktree prune`.

**Guardrails:** never force-delete branches (`git branch -D`) and never delete
remote branches (`git push --delete` / `git push :branch`). Local `git branch -d`
and `git worktree remove` are fine.
