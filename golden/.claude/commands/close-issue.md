---
name: close-issue
description: Validate acceptance criteria and close an issue with a structured comment
user_invocable: true
---

# /close-issue — Issue Validation & Closure

Quality gate. Validates all acceptance criteria before closing.

## Task Tracking Mode

When CLAUDE.md defines a Task Tracker section using `tasks/todo.md`:
- Uses `T-NN` references
- Moves row from Active to Done table with completion date
- Checks downstream `Blocked by: T-NN` references

## Invocation

```
/close-issue 53         # Close issue #53
/close-issue 53 54 55   # Close multiple
```

## Steps

### 1. Fetch the issue
Parse: Summary, Dependencies, Acceptance criteria, Implementation notes.

### 2. Validate acceptance criteria
Run project's test command first (hard gate). Then validate each criterion as PASS, FAIL, or SKIP.

### 3. Gate on results
If ANY FAIL → do NOT close. Return structured failure.

### 4. Check off criteria on the issue
Update `- [ ]` → `- [x]` for passing criteria.

### 5. Compose closing comment
Structured comment with summary, changes, criteria results, verification.

### 6. Close the issue
Interactive: confirm first. Autonomous (wiggum): proceed.

### 7. Downstream impact
Find unblocked issues, report milestone progress.

## Rules

- NEVER close if tests fail
- NEVER close if any criterion is FAIL
- ALWAYS post structured closing comment
