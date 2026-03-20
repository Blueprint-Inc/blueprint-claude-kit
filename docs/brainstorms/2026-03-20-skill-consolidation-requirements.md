---
date: 2026-03-20
topic: skill-consolidation
---

# Skill Plugin Consolidation

## Problem Frame

The blueprint-claude-kit currently loads multiple plugin frameworks (superpowers, compound-engineering, pr-review-toolkit, code-review, frontend-design, ralph-loop, ralph-wiggum, gitnexus, claude-md-management, claude-code-setup) that have significant functional overlap. This creates confusion about which skill to invoke, wastes context window on duplicate skill descriptions, and makes the system harder to reason about. The goal is to rationalize the plugin stack with compound-engineering as the primary framework, and selectively adopt high-value capabilities from `everything-claude-code` (ECC) that fill genuine gaps.

## Requirements

- R1. Eliminate all duplicate skills where compound-engineering provides equivalent functionality
- R2. Keep superpowers installed but scoped to only the 6 skills with no CE equivalent
- R3. Use `compound-engineering:ce-review` as the single canonical code review workflow, replacing `superpowers:requesting-code-review`, `pr-review-toolkit:review-pr`, and `code-review:code-review`
- R4. Remove the standalone `frontend-design:frontend-design` plugin since `compound-engineering:frontend-design` is identical
- R5. Document the canonical skill for each workflow step so future sessions don't re-introduce overlap
- R6. Adopt strategic compact suggestion hook from ECC — prevents context loss from arbitrary auto-compaction by suggesting `/compact` at logical task boundaries
- R7. Adopt ECC's structured YAML instinct format and project-scoping convention for lessons — skip the observation hooks, CLI tooling, and background observer (pomo + lessons.md remains the capture mechanism; the format upgrade enables export/import and programmatic use)
- R8. Adopt ECC's `/context-budget` concept — analyze context window consumption across agents, skills, and MCP servers to identify token waste (directly supports this consolidation effort)
- R9. Evaluate ECC's AgentShield for config security — scans CLAUDE.md, hooks, MCP servers, and settings.json for vulnerabilities (102 rules, covers attack surface your code security agent doesn't)
- R10. Add version tracking to deploy.sh — stamp deployed projects with the kit version so you can tell what's current
- R11. Add a manifest of deployed files to each project so `deploy.sh` can detect and remove files that were deleted from the kit (currently it only adds/updates, never removes)
- R12. Update the workflow section in deploy.sh to reflect the consolidated skill map (remove any references to dropped plugins like pr-review-toolkit)
- R13. Add a SessionStart hook to deployed projects that compares the local kit version against `~/Projects/blueprint-claude-kit/VERSION` and prints a one-line upgrade reminder if stale
- R14. Add GitNexus auto-indexing to deploy.sh — after copying files, run `npx gitnexus analyze` on the target project (optional: skip if GitNexus not installed or `.gitnexus/` already exists)
- R15. Create `setup.sh` that auto-installs all prerequisites: Claude Code CLI, gh, bun, node, GitNexus, Playwright browsers, required plugins (compound-engineering, superpowers, playwright), and qmd MCP server. Interactive auth (gh auth login) prompts the user. Idempotent — safe to re-run.
- R16. Add dependency check to deploy.sh — before copying files, verify prerequisites are installed. If anything is missing, print which deps are missing and tell the user to run `setup.sh` first. Do not block on optional deps (GitNexus), but block on required ones (claude, gh auth).
- R17. Update ONBOARDING.md to point to `setup.sh` instead of manual installation steps

## Consolidated Skill Map

### Primary Framework: compound-engineering

| Workflow Step | Canonical Skill | Replaces |
|---|---|---|
| Ideation | `ce-ideate` | — |
| Brainstorming | `ce-brainstorm` | `superpowers:brainstorming` (drop) |
| Planning | `ce-plan` | `superpowers:writing-plans` (drop) |
| Deepening plans | `deepen-plan` | — |
| Document review | `document-review` | — |
| Executing work | `ce-work` | `superpowers:executing-plans`, `superpowers:subagent-driven-development` (drop both) |
| Code review | `ce-review` | `superpowers:requesting-code-review`, `pr-review-toolkit:review-pr`, `code-review:code-review` (drop all) |
| Git worktrees | `git-worktree` | `superpowers:using-git-worktrees` (drop) |
| Writing skills | `create-agent-skills` | `superpowers:writing-skills` (drop) |
| Frontend design | `frontend-design` | `frontend-design:frontend-design` (drop standalone plugin) |
| Compounding knowledge | `ce-compound` | — |
| Todo resolution | `resolve-todo-parallel` | — |

### Retained from superpowers (no CE equivalent)

| Skill | Purpose | Notes |
|---|---|---|
| `using-superpowers` | Session bootstrap — skill discovery & routing | Core orchestration skill |
| `test-driven-development` | TDD workflow enforcement | No CE equivalent; valuable discipline gate |
| `verification-before-completion` | Verify before claiming done | Prevents premature "done" claims |
| `receiving-code-review` | Handle incoming review feedback with rigor | Complements `ce-review` (which is for *giving* reviews) |
| `dispatching-parallel-agents` | Parallel subagent orchestration patterns | General-purpose orchestration |
| `finishing-a-development-branch` | Branch completion / merge / PR guidance | Workflow gap without this |

### Retained from superpowers (deprecated, to remove)

| Skill | Status |
|---|---|
| `superpowers:execute-plan` | Deprecated — remove |
| `superpowers:write-plan` | Deprecated — remove |
| `superpowers:brainstorm` | Deprecated — remove |

### Blueprint-kit custom (unchanged)

| Skill/Command | Purpose |
|---|---|
| `/bootstrap-project` | Project detection and CLAUDE.md setup |
| `/wiggum` | Autonomous dev loop |
| `/create-issues` | Issue creation from plans |
| `/close-issue` | Validated issue closure |
| `/triage` | Backlog analysis |
| `/pomo` | Post-mortem / lesson capture |
| `/deploy` | Cloud Function deployment (golden template) |

### Other plugins — disposition

| Plugin | Decision | Rationale |
|---|---|---|
| `pr-review-toolkit` | **Drop** | `ce-review` is the canonical review; its specialized agents (silent-failure-hunter, etc.) are subagents of ce-review anyway |
| `code-review:code-review` | **Drop** | Replaced by `ce-review` |
| `frontend-design` (standalone) | **Drop** | Duplicate of `compound-engineering:frontend-design` |
| `ralph-loop` | **Keep** | Unique recurring task runner — no overlap |
| `ralph-wiggum` | **Keep** | Unique autonomous loop technique — no overlap |
| `gitnexus-*` | **Keep** | Unique codebase knowledge graph — no overlap |
| `claude-md-management` | **Keep** | Unique CLAUDE.md maintenance — no overlap |
| `claude-code-setup` | **Keep** | Unique automation recommender — no overlap |
| `humanizer` | **Keep** | Unique text editing — no overlap |
| `simplify` | **Keep** | Unique code simplification — no overlap |
| `loop` | **Keep** | Unique interval runner — no overlap |
| `claude-api` | **Keep** | Unique Anthropic SDK guidance — no overlap |
| `update-config` | **Keep** | Unique settings management — no overlap |
| `keybindings-help` | **Keep** | Unique keybinding help — no overlap |
| `compound-engineering:systematic-debugging` | **N/A** | Does not exist in CE; `gitnexus-debugging` and `superpowers:systematic-debugging` are different tools with different approaches |

## Success Criteria

- Zero duplicate skills across installed plugins — each workflow step maps to exactly one canonical skill
- Superpowers plugin is installed but only its 6 unique skills are active/relevant
- `ce-review` is the only code review entry point
- Context window overhead from skill descriptions is reduced (fewer plugins = fewer skill listings in system reminders)
- Strategic compact hook is active and preventing mid-task context loss
- Continuous learning hooks are capturing session patterns (if adopted)

## Additions from everything-claude-code (ECC)

ECC (github.com/affaan-m/everything-claude-code) was evaluated for additive capabilities. Most of its 28 agents, 59 commands, and 116 skills duplicate what CE + superpowers + blueprint-kit already provide. The following items fill genuine gaps:

| Priority | ECC Feature | Gap It Fills | Adoption Approach |
|---|---|---|---|
| **High** | Structured YAML Instinct Format | Lessons in `tasks/lessons.md` are freeform markdown; structured YAML enables project scoping, export/import, and programmatic use | Adopt the YAML format and project-scoping convention only; skip observation hooks, CLI tooling, and background observer |
| **High** | Strategic Compact Suggestions | No protection against arbitrary auto-compaction losing context mid-task | Adopt PreToolUse hook that tracks tool count and suggests compact at boundaries (~10 min effort) |
| **Medium** | `/context-budget` | No way to measure context window consumption across plugins | Adopt as blueprint-kit command; directly informs consolidation decisions |
| **Medium** | AgentShield | Security agent reviews code but not the agent harness config itself | Evaluate `ecc-agentshield` npm package for one-time audit, then decide on ongoing use |
| **Low** | `/harness-audit` | No self-diagnostic for Claude Code setup quality | Nice-to-have after consolidation is done |
| **Low** | Session Persistence Hooks | Memory system exists but no automated session state save/restore | Evaluate whether this adds value beyond existing memory system |

**Not adopted from ECC:** Language-specific skills (Go/Rust/Java/Kotlin/C++/Swift/Flutter), investor materials, content engine, cross-platform Cursor/OpenCode/Codex support, ClickHouse/Supabase/Railway MCP configs, PM2 multi-agent orchestration, DevFleet, NanoClaw REPL.

## Scope Boundaries

- **Not migrating** the 6 unique superpowers skills into CE — keeping both plugins for now
- **Not modifying** any skill implementations — this is a plugin configuration change only
- **Not touching** blueprint-kit custom commands/skills — they have no overlap
- **Not addressing** compound-engineering skills that are domain-specific (dhh-rails-style, andrew-kane-gem-writer, dspy-ruby, etc.) — these are opt-in and don't conflict
- **Not installing ECC as a whole plugin** — cherry-picking specific capabilities only

## Key Decisions

- **compound-engineering is primary**: When CE and superpowers overlap, CE wins
- **ce-review replaces all review tools**: Single entry point for code review, eliminating 3 redundant alternatives
- **superpowers retained for unique capabilities**: TDD, verification, receiving reviews, parallel agents, branch finishing, and session bootstrap have no CE equivalent

## Outstanding Questions

### Deferred to Planning

- [Affects R2][Technical] How are superpowers skills selectively disabled? Is it per-skill config in settings.json, or does the plugin need to be forked/trimmed?
- [Affects R3][Needs research] Does `ce-review` dispatch the same specialized agents as `pr-review-toolkit` (silent-failure-hunter, type-design-analyzer, etc.), or would dropping pr-review-toolkit lose those capabilities?
- [Affects R1][Technical] What is the actual mechanism to uninstall/disable plugins — is it `settings.json`, `.claude/plugins/`, or something else?
- [Affects R7][Technical] Define the YAML instinct schema for blueprint-kit lessons — fields: id, trigger, confidence, domain, scope, project_id. Decide where to store them (e.g., `tasks/instincts/` or alongside `tasks/lessons.md`).
- [Affects R6][Technical] What is the exact hook implementation for strategic compact suggestions? Is it a simple tool-call counter or something more sophisticated?
- [Affects R9][Needs research] Can `ecc-agentshield` be run standalone via npx without installing ECC? What does a typical audit report look like?

## Next Steps

→ `/ce:plan` for structured implementation planning
