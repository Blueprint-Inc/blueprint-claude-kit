# Self-Improvement System

> Reference document. Loaded by /pomo, /ce:review, and /wiggum when updating lessons.

## Lessons Format

Each entry in `.claude/lessons.md`:

```markdown
### [Pattern name]
- **Wrong:** [what was done incorrectly]
- **Right:** [the correct approach]
- **Why:** [root cause or reasoning]
```

## Triggers

Update `.claude/lessons.md` when:
- After any user correction
- After /ce:review finds issues Claude introduced
- After /wiggum retry failures (2+ attempts)
- Deduplicate ruthlessly

**/pomo is the primary entry point for all self-improvement.**

## Deduplication Rules

1. Read `.claude/lessons.md` first
2. Same pattern → update existing
3. Related but distinct → new + cross-reference

## Lesson Lifecycle

1. **Active** — Recently captured (default, no tag needed)
2. **Validated** — 2+ matching incidents
3. **Promoted** — Encoded into CLAUDE.md or a command. Remove from lessons.md.
4. **Stale** — No matches in 30+ days. Candidate for archival.

## Pruning Rules

- **Max:** 40 active lessons
- **Promotion:** Validated 3+ times → propose CLAUDE.md instruction
- **Archival:** 60+ days with no matches → `.claude/lessons-archive.md`
- **Deduplication:** Always merge, never duplicate

## Structured Instincts (YAML Format)

New lessons captured via `/pomo` are written as YAML files in `tasks/instincts/`. This structured format enables project scoping, export/import, and programmatic use.

### Schema

```yaml
id: prefer-tabs-over-spaces          # kebab-case identifier (also the filename)
trigger: "when writing PHP or SvelteKit code"  # natural-language condition
action: "Use tabs for indentation, never spaces"  # what to do
confidence: 0.9                        # 0.3 = tentative, 0.9 = near-certain
domain: code-style                     # one of: code-style, testing, git, debugging, workflow, security
scope: project                         # project or global
evidence: "Corrected by user on 2026-03-15 — campaign manager strictly enforces tabs"
```

### Storage

- **Project-scoped:** `tasks/instincts/<id>.yaml` (in the project repo)
- **Global:** `~/.claude/instincts/<id>.yaml` (personal, not committed)

### Relationship to lessons.md

- Existing `.claude/lessons.md` entries continue to work (backward compatible)
- `/pomo` writes new lessons as YAML instincts to `tasks/instincts/`
- Instincts follow the same lifecycle (Active → Validated → Promoted → Stale)
- When an instinct is promoted to CLAUDE.md, remove the YAML file
