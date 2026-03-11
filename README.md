# Blueprint Claude Kit

A portable configuration kit that combines the best of [compound-engineering](https://github.com/anthropics/claude-code) plugin's multi-agent review system with [claude-bootstrapping](https://github.com/quadradad/claude-bootstrapping)'s autonomous development loop.

## What You Get

### Commands (from claude-bootstrapping, adapted)

| Command | What it does |
|---------|-------------|
| `/wiggum` | Autonomous dev loop: pick issue → TDD → implement → PR → review → close → repeat |
| `/create-issues` | Convert a plan into structured GitHub issues with dependency tracking |
| `/close-issue` | Quality gate: validate acceptance criteria before closing |
| `/triage` | Backlog analysis with dependency graph and prioritization |
| `/bootstrap-project` | Auto-detect tech stack and configure CLAUDE.md |

### Skills

| Skill | What it does |
|-------|-------------|
| `/pomo` | Post-mortem: capture lessons with lifecycle management |

### From compound-engineering plugin (already installed)

| Command | What it does |
|---------|-------------|
| `/ce:brainstorm` | Explore requirements before planning |
| `/ce:plan` | Create detailed implementation plan |
| `/ce:review` | Multi-agent code review (language-specific reviewers + security + performance) |

### Reference Layer (`agent_docs/`)

On-demand reference files loaded by commands, not every session:

- `issue-conventions.md` — Issue format and dependency syntax
- `issue-tracker-ops.md` — GitHub CLI operations table
- `self-improvement.md` — Lesson format, lifecycle, pruning rules

## Prerequisites

- [Claude Code CLI](https://claude.ai/code)
- [GitHub CLI](https://cli.github.com/) (`gh`)
- [compound-engineering plugin](https://github.com/anthropics/claude-code) installed in Claude Code

## Quick Start

```bash
# 1. Clone this kit
git clone <this-repo-url> ~/blueprint-claude-kit

# 2. Deploy to any project
~/blueprint-claude-kit/deploy.sh /path/to/your/project

# 3. Open in Claude Code and bootstrap
cd /path/to/your/project
claude
> /bootstrap-project
```

The deploy script:
- Copies commands, skills, and agent_docs into your project
- Prompts before overwriting existing files
- Appends workflow section to existing CLAUDE.md (doesn't replace)
- Creates template `compound-engineering.local.md` for review agent config
- Creates empty `.claude/lessons.md` for the self-improvement system

## Development Workflow

```
/ce:brainstorm          (clarify what to build)
    ↓
/ce:plan                (detailed implementation plan)
    ↓
/create-issues          (break plan into GitHub issues with deps)
    ↓
/wiggum                 (autonomous loop: pick issue → TDD → PR → next)
    ↓
/ce:review              (multi-agent review)
    ↓
/close-issue            (quality gate + acceptance criteria)
    ↓
/pomo                   (capture lessons)
```

## Customization

### Review Agents

Edit `compound-engineering.local.md` in your project to configure which review agents `/ce:review` uses:

- **Python:** `kieran-python-reviewer`, `security-sentinel`, `performance-oracle`
- **TypeScript:** `kieran-typescript-reviewer`, `security-sentinel`, `performance-oracle`
- **Ruby/Rails:** `kieran-rails-reviewer`, `security-sentinel`, `data-integrity-guardian`

### Issue Scopes

Edit `agent_docs/issue-conventions.md` to add project-specific scopes for issue titles.

### Project-Specific agent_docs

Add your own reference docs to `agent_docs/` for on-demand loading. For example:
- `agent_docs/active-features.md` — Details of deployed features
- `agent_docs/api-reference.md` — External API quirks and gotchas

Reference them from CLAUDE.md's reference docs table.

## File Structure

```
your-project/
├── CLAUDE.md                           # Project config (slimmed, with workflow section)
├── compound-engineering.local.md       # Review agent config
├── agent_docs/                         # On-demand reference (not loaded every session)
│   ├── issue-conventions.md
│   ├── issue-tracker-ops.md
│   └── self-improvement.md
├── .claude/
│   ├── settings.local.json             # Tool permissions
│   ├── lessons.md                      # Active lessons (max 40)
│   ├── commands/
│   │   ├── wiggum.md
│   │   ├── create-issues.md
│   │   ├── close-issue.md
│   │   ├── triage.md
│   │   └── bootstrap-project.md
│   └── skills/
│       └── pomo/SKILL.md
└── tasks/                              # Plans and history (optional)
    ├── todo.md
    └── lessons.md
```

## Design Decisions

**Why combine two systems?** Compound-engineering excels at multi-agent review and planning discipline. Claude-bootstrapping excels at autonomous execution and issue-driven workflow. Together they cover the full development lifecycle.

**Why agent_docs/?** Large CLAUDE.md files waste tokens every session. Reference data (issue formats, CLI commands, lesson lifecycle) is only needed when specific commands run. Loading on-demand saves ~90% of context budget.

**Why /pomo with lifecycle?** Not all lessons are equal. The Active → Validated → Promoted → Stale lifecycle prevents lesson bloat while surfacing high-value patterns into permanent CLAUDE.md rules.
