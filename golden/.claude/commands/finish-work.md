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
   one-line *why it matched*. **Never invent** issue numbers. For each, decide:
   - **Fully addressed** — add `Closes #<n>` (or Fixes/Resolves) to the PR body under
     an `## Issues` section. Prefer Closes for completed user-feedback issues.
   - **Partial / soak / monitoring** — use `Refs #<n>` or “Related to #<n>” instead of
     Closes when acceptance criteria say wait (soak period, `in-staging` monitor).
     Default to Refs when unsure — premature Closes is a regression.

   **Always put keyword lines in the PR body** — do not rely on title-only `(#N)`.
   GitHub auto-closes only when the PR merges to the **default branch**. On
   BlueprintOS, feature PRs target `staging` (not default); `Closes` there still
   matters for discovery: the staging→prod release PR collector and SAW
   deploy-notifier read these lines so prod ships can auto-close and send
   thank-yous. See `agent_docs/issue-closes-on-prod-ship.md`. For BOS full ship
   (promotion-window, merge, deploy watch), use BOS `/ship` rather than this
   command alone.

   Confirm the list with the user before baking keywords into the PR.

6. **Push + PR.** Push the branch and open a PR **targeting the base branch this was
   cut from** (staging for blueprintos, the default branch otherwise) via
   `gh pr create`. Write a value-first description: what changed and why, scaled to
   the size of the change — not a file-by-file dump. Always include the agreed
   `## Issues` section with `Closes #<n>` / `Refs #<n>` lines from step 5. If exactly
   one primary issue and the title lacks it, append ` (#N)` (house style).

7. **Report + clean up.** Print the PR URL, then ask whether to remove the worktree
   now or keep it until the PR merges. On confirmation, switch out of it and run
   `git worktree remove <path>` then `git worktree prune`.

**Guardrails:** never force-delete branches (`git branch -D`) and never delete
remote branches (`git push --delete` / `git push :branch`). Local `git branch -d`
and `git worktree remove` are fine.
