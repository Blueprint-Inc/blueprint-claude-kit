# Canonical Skill Map

When multiple plugins provide overlapping skills, use the canonical skill listed here. This prevents confusion and ensures consistent workflows across projects.

## Primary Framework: compound-engineering

| Workflow Step | Use This | Not This |
|---|---|---|
| Ideation | `/ce-ideate` | — |
| Brainstorming | `/ce-brainstorm` | `superpowers:brainstorming` |
| Planning | `/ce-plan` | `superpowers:writing-plans` |
| Deepening plans | `/ce-plan` | — |
| Document review | `/ce-doc-review` | — |
| Executing work | `/ce-work` | `superpowers:executing-plans`, `superpowers:subagent-driven-development` |
| Code review (giving) | `/ce-code-review` | `superpowers:requesting-code-review` |
| Git worktrees | `/ce-worktree` | `superpowers:using-git-worktrees` |
| Writing skills | `/ce-create-agent-skills` | `superpowers:writing-skills` |
| Frontend UI | `/ce-frontend-design` | `frontend-design:frontend-design` (standalone — uninstall) |
| Compounding knowledge | `/ce-compound` | — |
| Todo resolution | `/ce-resolve-todo-parallel` | — |

## Superpowers-Only Skills (No CE Equivalent)

These skills are unique to superpowers and should be used as-is:

| Skill | Purpose |
|---|---|
| `using-superpowers` | Session bootstrap — skill discovery and routing |
| `test-driven-development` | TDD workflow enforcement |
| `verification-before-completion` | Verify work before claiming done |
| `receiving-code-review` | Handle incoming review feedback with rigor |
| `dispatching-parallel-agents` | Parallel subagent orchestration patterns |
| `finishing-a-development-branch` | Branch completion, merge, and PR guidance |

## Code Review Stack

- **Primary review:** `/ce-code-review` — dispatches 15 specialized agents (security, performance, architecture, language-specific reviewers, data integrity, schema drift, deployment verification)
- **Supplemental review:** `pr-review-toolkit` — 4 unique agents not covered by ce-review:
  - `silent-failure-hunter` — error handling auditing
  - `pr-test-analyzer` — test coverage quality
  - `comment-analyzer` — comment accuracy and rot detection
  - `type-design-analyzer` — type invariants and encapsulation

## Plugins to Uninstall

These plugins are fully replaced by compound-engineering equivalents:

```bash
# Run these once to clean up duplicate plugins
claude plugins uninstall code-review@claude-plugins-official
claude plugins uninstall frontend-design@claude-plugins-official
```

## Development Lifecycle

```
/ce-brainstorm → /ce-plan → /create-issues → /wiggum → /ce-code-review → /close-issue → /pomo
```

## When to Read This Doc

Read this when:
- You're unsure which skill to use for a workflow step
- A new plugin is installed and may overlap with existing skills
- Onboarding a new developer to the shared Claude Code environment
