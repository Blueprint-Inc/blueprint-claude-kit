# Onboarding Guide

A step-by-step guide to set up the shared Claude Code environment used by this project.

---

## Step 1: Set Up Your `~/Projects` Directory

All repos live under a single `~/Projects` directory. The tooling assumes this layout — the deploy script, the `/deploy-blueprint-claude` command, and the workspace-level `CLAUDE.md` all reference this path.

```bash
mkdir -p ~/Projects
cd ~/Projects
```

### Clone the common repos

These three repos power the shared Claude Code environment. Everyone needs all of them.

```bash
# This kit — commands, skills, and agent_docs that deploy into every project
git clone <your-org>/blueprint-claude-kit.git

# Autonomous dev loop foundation (wiggum, issue management, TDD enforcement)
git clone https://github.com/quadradad/claude-bootstrapping.git

# Multi-agent review system, brainstorming, and planning (Claude Code plugin)
git clone https://github.com/anthropics/claude-code.git compound-engineering-plugin
```

Then clone whichever project repos you'll be working in alongside them.

### Why `~/Projects`?

- The deploy script at `~/Projects/blueprint-claude-kit/deploy.sh` is referenced by the `/deploy-blueprint-claude` command across all projects
- The workspace-level `CLAUDE.md` at `~/Projects/CLAUDE.md` provides cross-project context when you open Claude Code from `~/Projects`
- Consistent paths mean team members can share instructions without path translation

---

## Step 2: Install Prerequisites

These CLI tools are used across the environment. Install any you don't already have.

### Required

| Tool | What it's for | Install |
|------|--------------|---------|
| [Claude Code](https://claude.ai/code) | The AI coding agent | `npm install -g @anthropic-ai/claude-code` |
| [GitHub CLI](https://cli.github.com/) (`gh`) | Issue management, PRs, `/create-issues`, `/wiggum`, `/triage` | `brew install gh` then `gh auth login` |
| [Bun](https://bun.sh) | Runs qmd and compound-engineering-plugin | `curl -fsSL https://bun.sh/install \| bash` |
| [Node.js](https://nodejs.org/) | Frontend projects, Playwright | `brew install nvm` then `nvm install 18` |
| [Python 3](https://www.python.org/) | Python projects, scripting | `brew install python` |

### Optional (depending on your projects)

| Tool | What it's for | Install |
|------|--------------|---------|
| [gcloud CLI](https://cloud.google.com/sdk/docs/install) | GCP deploys (Cloud Functions, BigQuery) | `brew install google-cloud-sdk` then `gcloud auth login` |
| [gws](https://github.com/nicholasgasior/gws) | Google Workspace CLI (Drive, Gmail, Sheets) | `npm install -g gws` |

---

## Step 3: Install Claude Code Plugins

Plugins extend Claude Code with specialized agents, review tools, and workflows. Install the shared set:

```bash
# Multi-agent review, brainstorming, planning — the core workflow engine
claude plugins install compound-engineering@every-marketplace

# Skill system — TDD, debugging, brainstorming, plan execution
claude plugins install superpowers@claude-plugins-official

# Browser automation — screenshots, form filling, web testing
claude plugins install playwright@claude-plugins-official

# CLAUDE.md auditing and improvement
claude plugins install claude-md-management@claude-plugins-official

# PR review with specialized agents
claude plugins install pr-review-toolkit@claude-plugins-official

# Automated dev loop (Ralph Wiggum)
claude plugins install ralph-wiggum@claude-code-plugins
```

Install Playwright's browser binaries after enabling the plugin:

```bash
npx playwright install
```

### Verify

Run `claude` and check that the plugins load. You should see skills like `/ce:brainstorm`, `/ce:plan`, `/ce:review`, `/wiggum`, and `/pomo` available.

---

## Step 4: Configure MCP Servers

MCP servers give Claude access to external tools and data sources. Add these to your global config.

### qmd — Local Document Search

qmd indexes your project files locally so Claude can search them instead of reading entire files. Saves ~92% of token usage.

```bash
# Install
bun install -g github:tobi/qmd

# Add as MCP server (global, available in all projects)
claude mcp add --scope user qmd -- qmd mcp
```

Index your projects after installing:

```bash
cd ~/Projects/your-project
qmd collection add . --name your-project --mask "**/*.py"  # adjust mask for your file types
qmd embed  # creates vector embeddings for semantic search
```

### Google Dev Knowledge (optional)

Gives Claude access to Google's developer documentation:

```bash
claude mcp add --scope user --transport http google-dev-knowledge \
  --url "https://developerknowledge.googleapis.com/mcp" \
  --header "X-Goog-Api-Key: <your-api-key>"
```

---

## Step 5: Set Up Global `CLAUDE.md`

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

## Step 6: Set Up the Workspace `CLAUDE.md`

The workspace-level `CLAUDE.md` at `~/Projects/CLAUDE.md` provides cross-project context when you open Claude Code from the `~/Projects` directory. This is useful when working across multiple repos in the same session.

This file describes:
- What each project is and how they relate to each other
- Language and indentation conventions per project
- Dev server, build, and test commands
- Links to per-project `CLAUDE.md` files for deeper context

If a workspace `CLAUDE.md` already exists, read it and make sure your projects are represented. If you're the first to set this up, create one that maps out your project relationships.

---

## Step 7: Deploy the Kit to Your Projects

Run the deploy script to install commands, skills, and agent_docs into each project you work on:

```bash
~/Projects/blueprint-claude-kit/deploy.sh ~/Projects/your-project
```

The script:
- Copies commands (`/wiggum`, `/create-issues`, `/close-issue`, `/triage`, `/bootstrap-project`, `/deploy-blueprint-claude`)
- Copies skills (`/pomo`)
- Copies reference docs to `agent_docs/`
- Creates `compound-engineering.local.md` template
- Creates `.claude/lessons.md`
- Appends a Workflow section to existing `CLAUDE.md` (non-destructive)
- Prompts before overwriting anything

After deploying, bootstrap the project:

```bash
cd ~/Projects/your-project
claude
> /bootstrap-project
```

This scans the project, detects the tech stack, and configures `CLAUDE.md` with project-specific settings and the right review agents.

Repeat for each project you work on.

---

## Step 8: Configure Permissions

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

The deploy script will remind you about gh permissions if they're missing.

---

## Step 9: Verify Everything Works

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
/ce:brainstorm → /ce:plan → /create-issues → /wiggum → /ce:review → /close-issue → /pomo
```

| Size of work | What to use |
|-------------|-------------|
| Quick bug fix | Fix it, `/pomo` if the root cause was surprising |
| Small feature (< 1 hour) | `/ce:plan` → implement → `/ce:review` |
| Medium feature (hours) | `/ce:brainstorm` → `/ce:plan` → `/create-issues` → implement → `/ce:review` |
| Large feature (days) | Full pipeline: brainstorm → plan → issues → `/wiggum` → review → close |
| Backlog grooming | `/triage` |

See the [README](README.md) for detailed documentation on each command.
