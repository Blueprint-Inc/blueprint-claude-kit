---
name: wiggum
description: Automated dev loop — pick the next unblocked issue, implement, test, close, and repeat
user_invocable: true
---

# /wiggum — Automated Development Loop

The orchestrator. Picks up issues in dependency order and implements them continuously until complete.

## Invocation

```
/wiggum                        # Auto-detect from open issues
/wiggum 53                     # Start with a specific issue
```

## Task Tracking Mode

When CLAUDE.md defines a Task Tracker section using `tasks/todo.md`:
- **Step 1 (Context):** Read `tasks/todo.md` Active table instead of querying milestones. Skip release PR discovery.
- **Step 2 (Select):** Pick the highest-impact unblocked task from the Active table
- **Step 3 (Branch):** Use `T-NN-slug` branch naming (e.g., `T-3-add-auth`)
- **Step 8 (Commit):** Use `Completes T-NN` instead of the smart close syntax
- **Step 9 (PR):** Target `main` (no release branch in todo.md mode)
- **Step 10 (Close):** Run `/close-issue T-NN` to move the task to Done
- **Release Completion:** Not applicable — loop ends when the Active table is empty

## Loop

Each iteration follows this sequence:

### 1. Context

Detect the current working context:
- Check the current git branch
- If a specific issue number was provided, start with that issue
- Otherwise, fetch all open issues and select the best candidate

### 2. Select next issue

Find the highest-impact unblocked issue:
- Fetch all open issues
- Run dependency analysis (triage logic)
- Filter to ready (unblocked) issues only
- Sort by impact score (issues that unblock the most others first)
- Pick the top issue and proceed immediately

### 3. Branch

Create a feature branch from main:

```bash
git checkout main
git pull origin main
git checkout -b 53-feature-slug
```

Branch naming: `{issue-number}-{slug}` where slug is a short kebab-case summary.

### 4. Understand

**For bugs:**
- Read the issue description for reproduction steps
- Attempt to reproduce the bug
- If not reproducible, skip the issue (log it) and move to the next one

**For features:**
- Read the issue description, acceptance criteria, and implementation notes
- Review relevant code and docs referenced in CLAUDE.md
- Check existing modules and established patterns

### 5. Implement

Follow the project's architecture strictly as defined in CLAUDE.md.

**Test-Driven Development (all changes):**
1. Write test file first with test cases covering the happy path and key error cases
2. Run the project's test command — confirm the new tests fail (red)
3. Implement the production code
4. Run the project's test command — confirm all tests pass (green)
5. Refactor if needed

### 6. Validate

Run the full validation suite defined in CLAUDE.md — this is a **hard gate**.

**Retry logic:**
- If validation fails, analyze the error and fix
- After 2 consecutive failures on the same issue, STOP — re-read the issue and ask: is the approach itself wrong?
- If still failing after 3 total attempts, revert the branch, log the failure on the issue, skip to the next issue

**Pre-existing failures:** If a test file you did NOT modify is failing, create an issue for it and continue.

### 6b. Post-Retry Reflection

If this issue required 2+ retry attempts:
1. Run `/pomo` with context about the retry failures
2. Continue the loop — this is non-blocking

### 7. Docs

Check if the implementation requires documentation updates. Update relevant docs if architecture, APIs, or data models changed.

### 8. Commit & Push

```bash
git add [specific files]
git commit -m "feat(scope): implement feature X

- Key change 1
- Key change 2

Closes #NN"
git push -u origin 53-feature-branch
```

### 9. PR

Create a pull request targeting main:

```bash
gh pr create \
  --base main \
  --title "feat(scope): Implement feature X (#53)" \
  --body "PR_BODY"
```

### 10. Review

Run `/ce:review` for multi-agent code review. Address any findings before proceeding.

### 11. Close issue

Run `/close-issue` to validate acceptance criteria and close.

**If close-issue returns failure:**
1. Fix the implementation
2. Commit, push, update PR
3. Retry `/close-issue` (max 2 retries)

### 12. Merge

```bash
gh pr merge PR_NUMBER --merge --delete-branch
git checkout main
git pull origin main
```

### 13. Loop

After merging:
- Log a summary
- Select the next highest-impact unblocked issue
- Continue without pausing

## Discovery Escape Hatch

If during implementation you discover:
- A bug that needs fixing before you can continue
- Missing functionality that should be a separate issue

**Handle autonomously:**
1. Create new issue(s) using `/create-issues` format
2. If blocking, commit progress, skip current, pick up blocker next
3. If independent, continue current work

## Stopping Conditions

The loop runs until:
- All open issues are closed
- All remaining issues are blocked or skipped
- The user intervenes

## Rules

- ALWAYS follow CLAUDE.md architecture rules
- NEVER force-push or rewrite history
- NEVER skip validation
- One issue per feature branch
- ALWAYS practice TDD
- Pre-existing test failures get their own issue
