# Claude Code Setup Baseline — Blueprint

_Outcome of the 2026-07-08 setup performance review. Dev sessions were carrying
~32k tokens of always-on context (skills, lessons, duplicate plugins) before any
work started — this baseline cuts that to roughly a third and removes competing
workflow systems._

## Canonical plugin set

**Two plugins. Everything else is off.**

| Plugin | State | Why |
|---|---|---|
| `compound-engineering@compound-engineering-plugin` | **on** | The workflow system: brainstorm, plan, work, review, debug, worktrees |
| `impeccable@impeccable` | **on** | Design fluency for frontend work — one skill, 23 commands, curated anti-patterns |
| everything else | **off** | See below |

Installed from exactly one source each:

```bash
claude plugin marketplace add EveryInc/compound-engineering-plugin
claude plugin install compound-engineering@compound-engineering-plugin --scope user
claude plugin marketplace add pbakaus/impeccable
claude plugin install impeccable@impeccable --scope user
```

### What was removed, and why

The 2026-07-08 audit cut the plugin set from ten to five on measured usage. This round
cuts it to two, on the same principle: a plugin earns its place by being reached for, and
every one below was either duplicating Compound Engineering or going unused.

| Removed | Reason |
|---|---|
| `superpowers@*` | Duplicates CE across brainstorming, plans, debugging, TDD and worktrees, and adds a mandatory skill-check gate to every task |
| `pr-review-toolkit@*` (both marketplaces) | A third and fourth code-review system; ~33KB of agent definitions per copy |
| `code-review@claude-plugins-official` | Redundant with `ce-code-review` and the built-in `/code-review` |
| `ralph-loop@*` / `ralph-wiggum@*` | One plugin under two names; never used, generated Stop-hook errors |
| `frontend-design@*` (both copies) | Superseded by Impeccable, which is the deeper tool for the same job |
| `playwright@claude-plugins-official` | CE's own browser skill instructs against a standalone browser stack: "Never install or substitute standalone Playwright". The host-native browser is the sanctioned path |
| `claude-md-management@claude-plugins-official` | Unused; CLAUDE.md upkeep happens during ordinary work |
| `claude-code-setup@claude-plugins-official` | Unused; it was listed as on in the previous baseline but nothing ever installed it |
| `github@claude-plugins-official` | The `gh` CLI covers it |

Apply on a dev machine: `./scripts/apply-baseline-plugins.sh` (merges into
`~/.claude/settings.json`, backs up first). Takes effect on next session start.

**Rule: one marketplace source per plugin.** Installing the same plugin from two
marketplaces doubles its context cost silently.

## Skill scoping

- `~/.claude/skills/` (global) is for **dev tooling only** — every skill
  description there loads into every session in every project. Baseline keeps
  nothing at all: the kit's own skills now arrive as a plugin, and the
  `gitnexus-*` skills were removed with the rest of GitNexus (see below).
- The marketing pack (ads-*, firecrawl-*, seo, copywriting, banana, etc. — 94
  skills + 10 agents, ~10.5k tokens of descriptions) lives in
  `styleblueprint-marketing/.claude/` with an SEO subset in
  `styleblueprint-seo/.claude/skills/`. Sessions in those projects load it;
  dev sessions don't.
- Adding a skill pack? Put it in the project(s) that use it, never global.

## Coach lessons budget

The global `coach-lessons.md` is injected into every session. It is generated
from instinct YAMLs in the coach repository and capped at **15 lessons
(~3.3k tokens)** — see `rank_and_cap` in `src/generate_coach_lessons.py`.
Raising the cap raises every developer's per-session cost; duplicates should be
retired at the YAML source (`confidence: 0.1`), and every retirement needs a
verified surviving keeper.

## Branch/worktree cleanup permissions

Keep the destructive denies (`git branch -D`, remote branch deletion) — they
force squash-merge verification through the vetted script instead of model
judgment. Then allow the script itself, so you can say "run the branch
cleanup" in any session and Claude executes it without classifier friction:

```json
"Bash(bash /Users/<you>/Projects/blueprint-claude-kit/scripts/weekly-git-cleanup.sh:*)",
"Bash(/Users/<you>/Projects/blueprint-claude-kit/scripts/weekly-git-cleanup.sh:*)"
```

Add both lines to `permissions.allow` in `~/.claude/settings.json` with your
username in the path. The safety tiers (merged-only, PR-verified force
deletes, dirty-unmerged skips, SHA logging) are enforced by the script, not by
the model — that's the point. The Monday launchd job (`--install`) covers the
recurring case regardless. A sibling daily job (`kill-stale-dev-servers.sh
--install`, 07:00) kills leftover `vite` / `npm run dev` processes older than
24 hours. Merged worktrees are force-removed even if dirty.

## Permission hygiene

- **Never approve a command whose text contains a secret** (API token in a curl
  header, key in a URL) — Claude Code saves the full command as a permission
  rule in `settings.local.json`, where it lives in plaintext indefinitely. Run
  such commands with the secret in an env var instead.
- Prune allowlists periodically: broad prefix rules (`Bash(git:*)`) subsume the
  narrow ones accumulated by daily approvals; loop fragments (`Bash(done)`)
  are junk. `/fewer-permission-prompts` can rebuild a clean minimal list.

## GitNexus: removed (2026-07-08)

Measured over 459 sessions / 3–4 months: **22 actual graph tool calls**
(9 `impact`, 13 `detect_changes`) versus **4,130 stale-index nags** injected
by its hooks and **30 sessions detoured into multi-minute re-indexing**. The
"MUST run impact analysis before editing" CLAUDE.md mandates were followed in
~2% of sessions — dead instruction weight the model was perpetually violating.

Removed: the Grep/Glob/Bash hooks (this was the nag source), 7 global skills,
the MCP server, ~1GB of `.gitnexus/` indexes, and the CLAUDE.md/AGENTS.md
sections in all five active repositories. If you have GitNexus hooks in your own
`~/.claude/settings.json`, remove them too.

Lesson for future tooling: before adopting anything that hooks every tool
call or adds MUST-rules to CLAUDE.md, define how you'll measure whether it's
used — transcript grep for actual tool calls vs. injected noise settles it.

## Round 2 (2026-07-08): unused MCP servers and instruction mandates

Same measurement discipline as the GitNexus removal, applied to MCP servers and
standing CLAUDE.md mandates. Usage counts are actual tool calls across 459
session transcripts on one machine.

**MCP servers removed** (from `~/.claude.json` top-level + project entries and
`~/.claude/settings.json`), archived locally first:

| Server | Lifetime calls | Why removed |
|---|---|---|
| context7 | 0 | Never called; also had a paired `~/.claude/rules/context7.md` "always use" mandate (archived earlier the same day) |
| google-dev-knowledge | 0 | Never called |
| google-sheets | 0 | Never called |
| gsc | 2 | `gws` CLI + direct API cover it |
| qmd (MCP server) | 7 | The qmd **CLI** was used ~50× over the same window — the CLI stays, the MCP server goes |
| n8n-mcp | 0 | Registration pointed at a deleted directory |

**Kept:** `analytics-mcp` (19 calls), `nanobanana-mcp` (image gen), and the
two client WordPress servers — out of
scope. Also pruned **5 stale project entries** (directories that no longer
exist) from `~/.claude.json`.

**Mandates demoted:**

- The global `~/.claude/CLAUDE.md` "always use qmd first" mandate → a plain
  tool mention. qmd stays available; it's no longer an always-first rule the
  model was following ~10% of the time.
- The workspace `~/Projects/CLAUDE.md` "Workflow Orchestration" and "Task
  Management" sections (plan-mode-default, `tasks/todo.md` ritual) → a short
  habits list that points workflow ownership at Compound Engineering, which
  those sections duplicated and contradicted.

### Replicating on another dev machine

1. **Re-check usage first — nonzero is a per-machine veto.** Before removing a
   server, grep your own transcripts; if *you* use it, keep it:
   ```
   for s in context7 google-dev-knowledge google-sheets gsc n8n-mcp; do \
     printf '%s: ' "$s"; \
     grep -rho "\"name\":\"mcp__${s}[_-]*[a-zA-Z_]*\"" ~/.claude/projects/ 2>/dev/null | wc -l; \
   done
   ```
2. Back up `~/.claude.json` and `~/.claude/settings.json`, then remove the
   server blocks and any stale project entries.
3. Apply the two CLAUDE.md demotions above.

**Never commit the archived MCP config blocks.** At least one (context7)
embeds an API key and gsc references a client-secrets file. Archived blocks
stay in the local `~/.claude/backups/` path — this doc records server names,
counts, and the re-check grep only, never the JSON.

## Verifying your session weight

Run `/context` in a session — if system-prompt overhead is well above ~15k
tokens in a plain dev project, something has crept back in: check for new
global skills, duplicate plugins, or a regrown lessons file.
