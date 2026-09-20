---
name: triage
description: Analyze the issue backlog — dependency graph, readiness, label validation, and prioritization. Use when deciding what to work on next, or when the backlog's readiness and dependencies are unclear.
---

# /triage — Backlog Analysis

Analyze all open issues, build a dependency graph, and produce an actionable summary.

## Task Tracking Mode

When CLAUDE.md defines a Task Tracker section using `tasks/todo.md`:
- Read `tasks/todo.md` instead of fetching from tracker
- Parse `- Blocked by: T-NN — reason` format
- Skip label validation and label fix offers

## Steps

### 1. Fetch all open issues
### 2. Parse `- Blocked by: #NN — reason` dependencies
### 3. Topological sort, detect cycles
### 4. Classify: Ready / Blocked / Impact score
### 5. Validate labels (stale blocked, missing blocked, no acceptance criteria)
### 6. Group by category (Feature, Bug, Infra, Docs, Tracking)
### 7. Output structured summary
### 8. Offer label fixes (with user confirmation)

Read-only by default. Only `- Blocked by: #NN — reason` is recognized.
