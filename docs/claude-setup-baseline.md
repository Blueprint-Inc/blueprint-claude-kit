# Claude Code Setup Baseline — Blueprint

_Outcome of the 2026-07-08 setup performance review. Dev sessions were carrying
~32k tokens of always-on context (skills, lessons, duplicate plugins) before any
work started — this baseline cuts that to roughly a third and removes competing
workflow systems._

## Canonical plugin set

One workflow system: **Compound Engineering**. Everything that competed with it
is disabled.

| Plugin | State | Why |
|---|---|---|
| `compound-engineering@compound-engineering-plugin` | **on** | Our standard workflow (brainstorm/plan/review/debug/worktree) |
| `frontend-design@claude-plugins-official` | on | Design skill (official copy only) |
| `playwright@claude-plugins-official` | on | Browser testing |
| `claude-md-management@claude-plugins-official` | on | CLAUDE.md upkeep |
| `claude-code-setup@claude-plugins-official` | on | Setup helpers |
| `superpowers@*` | **off** | Duplicates CE (brainstorming, plans, debugging, TDD, worktrees) and adds a mandatory skill-check gate to every task |
| `pr-review-toolkit@*` (both marketplaces) | **off** | Third/fourth code-review system; ~33KB of agent definitions per copy |
| `code-review@claude-plugins-official` | **off** | Redundant with `ce-code-review` and the built-in `/code-review` |
| `ralph-loop@*` / `ralph-wiggum@*` | **off** | Same plugin under two names; never used, generated Stop-hook errors |
| `frontend-design@claude-code-plugins` | **off** | Duplicate of the official copy |
| `github@claude-plugins-official` | off | Was already disabled; `gh` CLI covers it |

Apply on a dev machine: `./scripts/apply-baseline-plugins.sh` (merges into
`~/.claude/settings.json`, backs up first). Takes effect on next session start.

**Rule: one marketplace source per plugin.** Installing the same plugin from two
marketplaces doubles its context cost silently.

## Skill scoping

- `~/.claude/skills/` (global) is for **dev tooling only** — every skill
  description there loads into every session in every project. Baseline keeps:
  `deploy-blueprint-claude`, `gitnexus-*`.
- The marketing pack (ads-*, firecrawl-*, seo, copywriting, banana, etc. — 94
  skills + 10 agents, ~10.5k tokens of descriptions) lives in
  `styleblueprint-marketing/.claude/` with an SEO subset in
  `styleblueprint-seo/.claude/skills/`. Sessions in those projects load it;
  dev sessions don't.
- Adding a skill pack? Put it in the project(s) that use it, never global.

## Coach lessons budget

The global `coach-lessons.md` is injected into every session. It is generated
from instinct YAMLs in `blueprint-code-coach` and capped at **15 lessons
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
deletes, dirty-worktree skips, SHA logging) are enforced by the script, not by
the model — that's the point. The Monday launchd job (`--install`) covers the
recurring case regardless.

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
sections in bender-automation, blueprint-code-coach, blueprintos, prepotente,
and styleblueprint-audience-warehouse. If you have GitNexus hooks in your own
`~/.claude/settings.json`, remove them too.

Lesson for future tooling: before adopting anything that hooks every tool
call or adds MUST-rules to CLAUDE.md, define how you'll measure whether it's
used — transcript grep for actual tool calls vs. injected noise settles it.

## Verifying your session weight

Run `/context` in a session — if system-prompt overhead is well above ~15k
tokens in a plain dev project, something has crept back in: check for new
global skills, duplicate plugins, or a regrown lessons file.
