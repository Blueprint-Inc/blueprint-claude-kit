---
name: create-issues
description: Create issues from a plan discussed in conversation — with tracking epic, dependencies, and assignee resolution
user_invocable: true
---

# /create-issues — Plan-to-Issues Pipeline

Convert a plan discussed in conversation into a structured set of issues with a tracking epic, explicit dependencies, and proper sequencing.

## Task Tracking Mode

When CLAUDE.md defines a Task Tracker section using `tasks/todo.md`:
- **Step 0:** Skip assignee resolution
- **Steps 1-5:** Same planning and validation logic
- **Step 6:** Present review table using `T-NN` IDs
- **Step 7:** Add rows to Active table in `tasks/todo.md`
- **Step 8:** Validate by re-reading the file

## Invocation

```
/create-issues                  # Unassigned
/create-issues me               # Assign to authenticated user
/create-issues ben              # Resolve to collaborator username
```

## Step 0. Resolve Assignee

1. **`me`** — `gh api user --jq '.login'`
2. **Name** — Match against `gh api repos/{owner}/{repo}/collaborators`
3. **No argument** — Unassigned

## Step 1. Extract Plan from Conversation

Find the plan. Extract: epic title, steps, implementation details, dependencies.
If no plan found, ask.

## Step 2. Survey Existing Issues

Check for duplicates via `gh issue list --state open`.

## Step 3. Draft Tracking Epic

**Title:** `tracking: {epic title}` / **Labels:** `tracking`

## Step 4. Draft Child Issues

**Title:** `{type}({scope}): {description}`
**Body:** Follow `agent_docs/issue-conventions.md`

## Step 5. Validate Dependency Graph

Cycle detection, verify all blockers exist.

## Step 6. Present for Review

Show summary table + full previews. Ask before creating.

## Step 7. Create Issues

Dependency order. Epic first. Update bodies with real `#NN` references.

## Step 8. Post-Creation Validation

Rebuild graph, confirm no orphaned references.

## Rules

- NEVER create without user confirmation
- NEVER create duplicates
- ALWAYS include test-passing criterion in acceptance criteria
- ALWAYS create tracking epic for 2+ related issues
- Dependencies use: `- Blocked by: #NN — reason`
