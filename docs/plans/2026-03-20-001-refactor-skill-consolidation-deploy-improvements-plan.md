---
title: "refactor: Skill plugin consolidation & deploy improvements"
type: refactor
status: completed
date: 2026-03-20
origin: docs/brainstorms/2026-03-20-skill-consolidation-requirements.md
---

# Skill Plugin Consolidation & Deploy Improvements

## Overview

Rationalize the blueprint-claude-kit plugin stack to eliminate duplicates, improve the deploy pipeline with version tracking and dependency management, create a one-command setup script for new developers, and cherry-pick high-value capabilities from everything-claude-code (ECC).

## Problem Statement / Motivation

The current setup loads 10+ plugins with significant overlap — 7 superpowers skills duplicate compound-engineering equivalents, 3 separate plugins provide code review, and frontend-design appears twice. This wastes context window tokens on redundant skill descriptions and creates confusion about which skill to invoke. The deploy pipeline also lacks version tracking, dependency checking, and automated setup — requiring new developers to follow a 9-step manual onboarding guide.

## Research Findings

### Plugin Management (answers deferred question from origin)

Plugins are **all-or-nothing** — Claude Code provides no per-skill disabling. The `enabledPlugins` setting in `~/.claude/settings.json` toggles entire plugins. This means:
- R2 ("scope superpowers to 6 skills") cannot be enforced technically
- Duplicate skills will still appear in the system reminder
- The canonical skill map must be in CLAUDE.md to steer Claude toward the right skill

### ce-review vs pr-review-toolkit (answers deferred question from origin)

**ce-review dispatches 15 agents** (kieran-rails/python/typescript-reviewer, security-sentinel, performance-oracle, architecture-strategist, code-simplicity-reviewer, data-integrity-guardian, data-migration-expert, schema-drift-detector, deployment-verification-agent, pattern-recognition-specialist, agent-native-reviewer, dhh-rails-reviewer, julik-frontend-races-reviewer).

**pr-review-toolkit has 6 agents** with **4 that are genuinely unique** — not covered by ce-review:
- `silent-failure-hunter` — error handling auditing
- `pr-test-analyzer` — test coverage quality
- `comment-analyzer` — comment accuracy and rot
- `type-design-analyzer` — type invariants and encapsulation

**Decision change:** Keep pr-review-toolkit. The origin doc's disposition (drop it) was based on an incorrect assumption. Update R3 to: "Use ce-review as the primary review workflow. Keep pr-review-toolkit for its 4 unique specialized agents."

### Current Deploy Pipeline

- `deploy.sh` copies 6 commands, 1 skill, 4 agent_docs from `golden/` into target projects
- Prompts before overwriting, non-destructive
- No VERSION file, no manifest, no dependency checking
- `/deploy-blueprint-claude` command in each project calls `deploy.sh`
- `deploy` skill (Cloud Function deployment) exists in golden but is **not deployed by the script** — it's project-specific

### Hook Types

Claude Code supports `SessionStart` as a hook type (confirmed in system-reminder). R13 can use a real SessionStart hook.

## Proposed Solution

Four phases, ordered by impact and independence. Each phase is independently shippable.

### Phase 1: Plugin Consolidation & Canonical Skill Map

**Goal:** Reduce confusion by documenting which skill to use for each workflow step, remove truly duplicate plugins, and update all kit references.

**Files to create/modify:**
- `golden/agent_docs/canonical-skill-map.md` — full skill map reference (loaded on demand)
- `golden/.claude/commands/bootstrap-project.md` — add canonical skill map to generated CLAUDE.md workflow section
- `deploy.sh` lines 141-192 — update the workflow section template
- `ONBOARDING.md` — remove `pr-review-toolkit` install → keep it; remove `code-review` install; remove `frontend-design` standalone install

**Plugin changes (manual, per developer):**
- Uninstall `code-review@claude-plugins-official` — fully replaced by ce-review
- Uninstall `frontend-design@claude-plugins-official` — duplicate of `compound-engineering:frontend-design`
- Keep `pr-review-toolkit@claude-code-plugins` — has unique agents
- Keep `superpowers@claude-plugins-official` — has unique skills (TDD, verification, etc.)
- Keep all other plugins unchanged

**Canonical skill map (condensed, for CLAUDE.md):**
```markdown
## Canonical Skills

When multiple skills overlap, use these:

| Workflow | Use This | Not This |
|----------|----------|----------|
| Brainstorm | /ce:brainstorm | superpowers:brainstorming |
| Plan | /ce:plan | superpowers:writing-plans |
| Execute | /ce:work | superpowers:executing-plans |
| Review (give) | /ce:review | superpowers:requesting-code-review |
| Git worktrees | /ce:git-worktree | superpowers:using-git-worktrees |
| Write skills | /ce:create-agent-skills | superpowers:writing-skills |
| Frontend UI | /ce:frontend-design | (standalone removed) |

Superpowers-only (no CE equivalent): TDD, verification-before-completion,
receiving-code-review, dispatching-parallel-agents, finishing-a-development-branch
```

### Phase 2: Deploy Pipeline Improvements

**Goal:** Add version tracking, file manifest, GitNexus auto-indexing, and the SessionStart upgrade hook.

#### 2a. VERSION file and stamping (R10)

- Create `VERSION` at repo root with format `YYYY.MM.DD` (e.g., `2026.03.20`)
- `deploy.sh` stamps target project with `.claude/.blueprint-kit-version` containing the VERSION value
- On re-deploy, show: `Upgrading from 2026.03.15 → 2026.03.20`

**Files:** `VERSION` (new), `deploy.sh` (modify)

#### 2b. File manifest with checksums (R11)

- After deploying, write `.claude/blueprint-kit-manifest.json`:
  ```json
  {
    "version": "2026.03.20",
    "deployedAt": "2026-03-20T15:30:00Z",
    "files": {
      ".claude/commands/wiggum.md": { "sha256": "abc123..." },
      ".claude/commands/create-issues.md": { "sha256": "def456..." }
    }
  }
  ```
- On re-deploy, compare current manifest against golden:
  - Files in manifest but not in golden → orphans. Prompt: "wiggum.md was removed from the kit. Delete? [y/N]"
  - But only if the file's checksum matches the deployed version (user hasn't customized it). If checksum differs, warn: "wiggum.md was removed from kit but you've customized it. Keeping."
- Commit `.claude/blueprint-kit-manifest.json` to version control (alongside `.claude/commands/`)

**Files:** `deploy.sh` (modify)

#### 2c. SessionStart upgrade hook (R13)

- `deploy.sh` adds a SessionStart hook to `.claude/settings.local.json`:
  ```json
  {
    "hooks": {
      "SessionStart": [{
        "command": "bash -c 'KIT_VER=$(cat ~/Projects/blueprint-claude-kit/VERSION 2>/dev/null || echo unknown); LOCAL_VER=$(cat .claude/.blueprint-kit-version 2>/dev/null || echo none); [ \"$KIT_VER\" != \"$LOCAL_VER\" ] && echo \"Blueprint kit update available: $LOCAL_VER → $KIT_VER. Run /deploy-blueprint-claude\" || true'"
      }]
    }
  }
  ```
- Hook must merge with existing hooks in settings.local.json, not overwrite
- If blueprint-claude-kit repo doesn't exist at `~/Projects/`, hook is silent (no error)

**Files:** `deploy.sh` (modify)

#### 2d. GitNexus auto-indexing (R14)

- After file copying, check if `gitnexus` is available and `.gitnexus/` doesn't exist
- Run `npx gitnexus analyze` in background (don't block deploy)
- Print: "GitNexus indexing started in background..." or "GitNexus not installed — skipping index"

**Files:** `deploy.sh` (modify)

#### 2e. Update workflow section template (R12)

- Remove any references to dropped plugins (code-review standalone)
- Add canonical skill map (condensed) to the workflow section
- Keep pr-review-toolkit references (it's retained)

**Files:** `deploy.sh` lines 141-192 (modify)

#### 2f. Add `--yes` and `--dry-run` flags

- `--yes`: Skip all prompts, overwrite everything (for scripting/CI)
- `--dry-run`: Show what would change without making changes

**Files:** `deploy.sh` (modify)

### Phase 3: Setup Automation

**Goal:** One-command prerequisite installation for new developers.

#### 3a. Create setup.sh (R15)

macOS-only (brew-based). Idempotent — safe to re-run.

```
setup.sh flow:
1. Check for Homebrew → install if missing
2. Check for Node.js → brew install node if missing
3. Check for Bun → install via curl if missing
4. Check for gh → brew install gh if missing
5. Check for gh auth → prompt user to run `gh auth login` (interactive, cannot automate)
6. Check for Claude Code CLI → npm install -g @anthropic-ai/claude-code if missing
7. Install plugins:
   - claude plugins install compound-engineering@every-marketplace
   - claude plugins install superpowers@claude-plugins-official
   - claude plugins install playwright@claude-plugins-official
   - claude plugins install pr-review-toolkit@claude-code-plugins
   - claude plugins install ralph-wiggum@claude-code-plugins
   - claude plugins install claude-md-management@claude-plugins-official
8. Install Playwright browsers → npx playwright install
9. Check for GitNexus → npm install -g gitnexus if missing
10. Install qmd MCP → bun install -g github:tobi/qmd && claude mcp add --scope user qmd -- qmd mcp
11. Summary of what was installed/skipped
```

Each step: check if already installed → skip with ✓ or install with ⬇

**Files:** `setup.sh` (new)

#### 3b. Deploy dependency check (R16)

Before copying files, deploy.sh checks:
- **Required (blocks):** `claude` CLI, `gh auth status`
- **Recommended (warns):** `bun`, `node`, compound-engineering plugin
- **Optional (notes):** `gitnexus`

If required deps missing: "Missing required tools. Run setup.sh first." and exit.

**Files:** `deploy.sh` (modify)

#### 3c. Update ONBOARDING.md (R17)

Replace manual Steps 2-3 (install prerequisites, install plugins) with:
```
## Step 2: Run setup.sh
~/Projects/blueprint-claude-kit/setup.sh
```

Keep Steps 4-9 (MCP config, CLAUDE.md, deploy, permissions, verify) since they're project-specific. Remove the `code-review` and standalone `frontend-design` plugin lines.

**Files:** `ONBOARDING.md` (modify), `README.md` (modify to reference setup.sh)

### Phase 4: ECC Cherry-Picks

**Goal:** Add strategic compact hook and YAML instinct format. Defer context-budget and AgentShield.

#### 4a. Strategic compact suggestion hook (R6)

- Add a PreToolUse hook to `golden/.claude/settings.local.json` template
- Simple tool-call counter: after every 50 tool calls, print:
  `"Consider running /compact — 50 tool calls since last compact"`
- Counter stored in a temp file: `/tmp/.claude-tool-count-$$`
- Reset on compact or new session

**Files:** `deploy.sh` (add hook to settings.local.json merge logic)

#### 4b. YAML instinct format for lessons (R7)

Define the schema and migrate from freeform `lessons.md`:

**Schema** (stored in `tasks/instincts/<id>.yaml`):
```yaml
id: prefer-tabs-over-spaces
trigger: "when writing PHP or SvelteKit code"
action: "Use tabs for indentation, never spaces"
confidence: 0.9
domain: code-style
scope: project  # or global
evidence: "Corrected by user on 2026-03-15 — campaign manager strictly enforces tabs"
```

**Migration path:**
- Existing `lessons.md` entries are not auto-migrated
- New lessons from `/pomo` are written in YAML format to `tasks/instincts/`
- `lessons.md` is kept for backward compatibility until all entries age out
- `deploy.sh` creates `tasks/instincts/` directory in target projects

**Files:** `golden/agent_docs/self-improvement.md` (update format docs), `deploy.sh` (create instincts dir), `.claude/skills/pomo/SKILL.md` (update to write YAML)

#### 4c. Context-budget command (R8) — DEFERRED

Deferred to a future iteration. Requires understanding Claude Code's token accounting, which is not exposed via API. Would be a heuristic based on character counts of skill descriptions and system-reminder content. Low priority after consolidation reduces the problem.

#### 4d. AgentShield evaluation (R9) — DEFERRED

One-time audit. Run `npx ecc-agentshield` after consolidation is complete to validate the new configuration. Not a kit component — just a one-off check.

## Acceptance Criteria

### Phase 1
- [ ] `code-review@claude-plugins-official` and `frontend-design@claude-plugins-official` listed as "uninstall" in setup/onboarding docs
- [ ] `golden/agent_docs/canonical-skill-map.md` exists with full skill map
- [ ] Deploy's CLAUDE.md workflow section includes condensed canonical skill map
- [ ] ONBOARDING.md no longer references code-review or standalone frontend-design plugins

### Phase 2
- [ ] `VERSION` file exists at repo root
- [ ] `deploy.sh` stamps `.claude/.blueprint-kit-version` in target projects
- [ ] `deploy.sh` writes `.claude/blueprint-kit-manifest.json` with file checksums
- [ ] Re-deploy detects orphaned files and prompts for removal (only if unchanged)
- [ ] SessionStart hook installed in target projects, prints upgrade reminder when stale
- [ ] GitNexus auto-indexing runs (or skips gracefully) after deploy
- [ ] `deploy.sh --dry-run` shows changes without applying
- [ ] `deploy.sh --yes` runs non-interactively

### Phase 3
- [ ] `setup.sh` installs all prerequisites on a clean macOS machine
- [ ] `setup.sh` is idempotent — re-running skips already-installed tools
- [ ] `deploy.sh` blocks with clear message if required deps missing
- [ ] ONBOARDING.md Step 2 points to `setup.sh`

### Phase 4
- [ ] PreToolUse compact suggestion hook fires after 50 tool calls
- [ ] `/pomo` writes instincts in YAML format to `tasks/instincts/`
- [ ] `tasks/instincts/` directory created by deploy.sh
- [ ] `agent_docs/self-improvement.md` documents YAML instinct format

## Dependencies & Risks

**Risks:**
- **All-or-nothing plugins:** The canonical skill map relies on Claude reading CLAUDE.md and choosing the right skill. This is soft enforcement — Claude may still invoke a superpowers duplicate if the canonical map isn't in context. Mitigated by putting the condensed map directly in the CLAUDE.md workflow section (always loaded).
- **pr-review-toolkit retention:** Keeping it means more skills in the system reminder. But losing its unique agents would degrade review quality. Acceptable tradeoff.
- **setup.sh platform lock:** macOS-only via brew. If the team adds Linux developers, setup.sh needs conditional logic. Acceptable for now — the team is macOS.

**Dependencies:**
- Phase 2c (SessionStart hook) depends on 2a (VERSION file)
- Phase 2b (manifest) should ship with 2a (version stamping) in the same deploy.sh update
- Phase 3a (setup.sh) is independent of other phases
- Phase 4b (YAML instincts) depends on updating the pomo skill, which is in golden/

## Implementation Order

```
Phase 1 (consolidation) ← Do first, highest impact, zero code risk
  ↓
Phase 2 (deploy improvements) ← Second, enables all future upgrades
  ↓
Phase 3 (setup automation) ← Third, depends on Phase 1 plugin list being final
  ↓
Phase 4 (ECC cherry-picks) ← Last, additive features
```

Phases 1 and 3 can be worked in parallel since they touch different files.

## Sources & References

- **Origin document:** [docs/brainstorms/2026-03-20-skill-consolidation-requirements.md](docs/brainstorms/2026-03-20-skill-consolidation-requirements.md) — 17 requirements covering consolidation, ECC cherry-picks, deploy improvements, and setup automation. Key decisions: CE is primary framework, superpowers retained for 6 unique skills, pr-review-toolkit retained (revised from origin's "drop" disposition after research showed unique capabilities).
- **Plugin registry:** `~/.claude/plugins/installed_plugins.json`
- **Plugin settings:** `~/.claude/settings.json` (`enabledPlugins` dictionary)
- **ce-review skill:** `~/.claude/plugins/cache/every-marketplace/compound-engineering/2.46.0/skills/ce-review/SKILL.md`
- **ECC instinct system:** `github.com/affaan-m/everything-claude-code` — evaluated, adopted YAML format only
- **Current deploy script:** `/Users/jaygraves/Projects/blueprint-claude-kit/deploy.sh`
