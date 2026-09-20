# Onboarding Guide

A step-by-step guide to set up the shared Claude Code environment used by this project.

---

## Step 1: Set Up Your `~/Projects` Directory

All repos live under a single `~/Projects` directory. The workspace-level `CLAUDE.md` and the maintenance scripts assume this layout.

```bash
mkdir -p ~/Projects
cd ~/Projects
```

### Clone the common repos

These three repos power the shared Claude Code environment. Everyone needs all of them.

```bash
# This kit — commands, skills, and agent_docs that deploy into every project
git clone git@github.com:Blueprint-Inc/blueprint-claude-kit.git

# Autonomous dev loop foundation (wiggum, issue management, TDD enforcement)
git clone https://github.com/quadradad/claude-bootstrapping.git

# Multi-agent review system, brainstorming, and planning (Claude Code plugin)
git clone https://github.com/EveryInc/compound-engineering-plugin.git compound-engineering-plugin
```

Then clone whichever project repos you'll be working in alongside them.

### Why `~/Projects`?

- The workspace-level `CLAUDE.md` at `~/Projects/CLAUDE.md` provides cross-project context when you open Claude Code from `~/Projects`
- Consistent paths mean team members can share instructions without path translation

---

## Step 2: Run the Setup Script

The setup script installs all prerequisites automatically — Homebrew, Node.js, Bun, GitHub CLI, Claude Code CLI, qmd, and exactly two Claude Code plugins: Compound Engineering and Impeccable. It also applies the plugin baseline, turning off anything that competed with them.

```bash
~/Projects/blueprint-claude-kit/setup.sh
```

The script is idempotent — it skips anything already installed and is safe to re-run.

> **Note:** You will be prompted to authenticate with GitHub (`gh auth login`) if not already authenticated.

### Optional tools (project-dependent)

| Tool | What it's for | Install |
|------|--------------|---------|
| [gcloud CLI](https://cloud.google.com/sdk/docs/install) | GCP deploys (Cloud Functions, BigQuery) | `brew install google-cloud-sdk` then `gcloud auth login` |
| [gws](https://github.com/nicholasgasior/gws) | Google Workspace CLI (Drive, Gmail, Sheets) | `npm install -g gws` |
| [Python 3](https://www.python.org/) | Python projects, scripting | `brew install python` |

### Verify

Run `claude` and check that the plugins load. You should see skills like `/ce-brainstorm`, `/ce-plan`, `/ce-code-review`, `/wiggum`, and `/pomo` available.

---

## Step 3: Configure MCP Servers

The kit registers no MCP servers. `setup.sh` installs the qmd **CLI** — the qmd MCP server was removed on measured evidence (7 calls against the CLI's ~50). You just need to index your projects.

### qmd — Index Your Projects

qmd indexes your project files locally so Claude can search them instead of reading entire files. Saves ~92% of token usage.

Index each project you work on:

```bash
cd ~/Projects/your-project
qmd collection add . --name your-project --mask "**/*.py"  # adjust mask for your file types
qmd embed  # creates vector embeddings for semantic search
```

---

## Step 4: Set Up Global `CLAUDE.md`

Your global `CLAUDE.md` lives at `~/.claude/CLAUDE.md` and applies to every Claude Code session regardless of project. Use it for personal preferences, tool priorities, and cross-cutting instructions.

```bash
mkdir -p ~/.claude
```

Create `~/.claude/CLAUDE.md` with at minimum:

```markdown
# Global Claude Code Configuration

## Document Search Strategy

Before reading files or exploring directories, always use qmd to search for information in local projects.

### Search Tool Priority

1. **First: Use qmd** for document and code searches
   - `qmd search "query"` - Fast keyword-based search
   - `qmd query "query"` - Hybrid search with re-ranking (recommended for complex queries)
   - `qmd vsearch "query"` - Semantic similarity search

2. **Then: Use Read/Glob/Grep** only if qmd doesn't return sufficient results

### Current qmd Collections

Run `qmd status` to see indexed collections and available documents.
```

Add any personal preferences, API configurations, or tool-specific instructions below that. This file is yours — it's not checked into any repo.

---

## Step 5: Set Up the Workspace `CLAUDE.md`

The workspace-level `CLAUDE.md` at `~/Projects/CLAUDE.md` provides cross-project context when you open Claude Code from the `~/Projects` directory. This is useful when working across multiple repos in the same session.

This file describes:
- What each project is and how they relate to each other
- Language and indentation conventions per project
- Dev server, build, and test commands
- Links to per-project `CLAUDE.md` files for deeper context

If a workspace `CLAUDE.md` already exists, read it and make sure your projects are represented. If you're the first to set this up, create one that maps out your project relationships.

---

## Step 6: Install the Kit

Install once per machine. Nothing is copied into your repositories:

```bash
claude plugin marketplace add Blueprint-Inc/blueprintos-code-kit
claude plugin install code-kit@blueprintos-code-kit --scope user
```

That installs the core workflow skills: `/start-work`, `/finish-work`, `/create-issues`,
`/triage`, `/close-issue`, `/wiggum`, `/pomo`, and `/bootstrap-project`.

Blueprint developers also install the overlay, which adds the Cloud Functions deploy
skill and cross-model deep review:

```bash
claude plugin install code-kit-blueprint@blueprintos-code-kit --scope user
```

Then bootstrap each project you work in. This is the step that seeds the files which
genuinely belong in a repository — `agent_docs/`, the review-agent config, the lessons
file, and `.code-kit/config.json`:

```bash
cd ~/Projects/your-project
claude
> /bootstrap-project
```

This scans the project, detects the tech stack, and configures `CLAUDE.md` with project-specific settings and the right review agents.

Repeat the bootstrap step for each project you work on. The install itself is once per machine.

---

## Step 7: Configure Permissions

Claude Code prompts for approval on shell commands by default. Add permissions for frequently used tools to avoid repeated prompts.

### Global permissions (`~/.claude/settings.json`)

These apply to every project:

```json
{
  "permissions": {
    "allow": [
      "Bash(gh issue *)",
      "Bash(gh pr *)",
      "Bash(gh api *)",
      "Bash(git checkout *)",
      "Bash(git push:*)",
      "Bash(venv/bin/pytest *)"
    ]
  }
}
```

### Per-project permissions (`.claude/settings.local.json`)

Add project-specific permissions in each repo. This file is gitignored — it won't be committed.

```json
{
  "permissions": {
    "allow": [
      "Bash(npm run dev)",
      "Bash(npm run build)",
      "Bash(npm run check)"
    ]
  }
}
```



---

## Step 8: Verify Everything Works

Quick smoke test to confirm the setup:

```bash
cd ~/Projects/your-project
claude
```

Then in Claude Code:

1. **qmd works:** Ask Claude to search for something — it should use `qmd search` or `qmd query` before reading files
2. **Commands available:** Type `/` and verify you see `wiggum`, `create-issues`, `close-issue`, `triage`, `pomo`, `ce:brainstorm`, `ce:plan`, `ce:review`
3. **gh works:** Run `/triage` — it should fetch issues without permission prompts
4. **Playwright works:** Ask Claude to take a screenshot of a URL

---

## Quick Reference

Once you're set up, here's how the workflow commands fit together:

```
/ce-brainstorm → /ce-plan → /create-issues → /wiggum → /ce-code-review → /close-issue → /pomo
```

| Size of work | What to use |
|-------------|-------------|
| Quick bug fix | Fix it, `/pomo` if the root cause was surprising |
| Small feature (< 1 hour) | `/ce-plan` → implement → `/ce-code-review` |
| Medium feature (hours) | `/ce-brainstorm` → `/ce-plan` → `/create-issues` → implement → `/ce-code-review` |
| Large feature (days) | Full pipeline: brainstorm → plan → issues → `/wiggum` → review → close |
| Backlog grooming | `/triage` |

See the [README](README.md) for detailed documentation on each command.
