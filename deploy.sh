#!/bin/bash
set -euo pipefail

# Blueprint Claude Kit — Deploy to any project
# Combines compound-engineering review agents with bootstrapping's
# autonomous dev loop, issue management, and self-improvement system.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GOLDEN="$SCRIPT_DIR/golden"

usage() {
    echo "Usage: $0 <target-project-path>"
    echo ""
    echo "Deploys the Blueprint Claude Kit into a project directory."
    echo "Copies commands, skills, agent_docs, and templates."
    echo "Does NOT overwrite existing CLAUDE.md — merges safely."
    echo ""
    echo "After deploying, open the project in Claude Code and run:"
    echo "  /bootstrap-project"
    exit 1
}

if [ $# -lt 1 ]; then
    usage
fi

TARGET="$1"

if [ ! -d "$TARGET" ]; then
    echo "Error: '$TARGET' is not a directory"
    exit 1
fi

echo "Blueprint Claude Kit — Deploying to: $TARGET"
echo "============================================="

# Create directories
echo ""
echo "Creating directories..."
mkdir -p "$TARGET/.claude/commands"
mkdir -p "$TARGET/.claude/skills/pomo"
mkdir -p "$TARGET/agent_docs"

# Copy commands
echo "Installing commands..."
for cmd in wiggum create-issues close-issue triage bootstrap-project; do
    src="$GOLDEN/.claude/commands/$cmd.md"
    dst="$TARGET/.claude/commands/$cmd.md"
    if [ -f "$dst" ]; then
        read -p "  $cmd.md exists. Overwrite? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "  Skipped $cmd.md"
            continue
        fi
    fi
    if [ -f "$src" ]; then
        cp "$src" "$dst"
        echo "  Installed $cmd.md"
    fi
done

# Copy skills
echo "Installing skills..."
src="$GOLDEN/.claude/skills/pomo/SKILL.md"
dst="$TARGET/.claude/skills/pomo/SKILL.md"
if [ -f "$dst" ]; then
    read -p "  pomo/SKILL.md exists. Overwrite? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "  Skipped pomo/SKILL.md"
    else
        cp "$src" "$dst"
        echo "  Installed pomo/SKILL.md"
    fi
else
    cp "$src" "$dst"
    echo "  Installed pomo/SKILL.md"
fi

# Copy agent_docs
echo "Installing agent_docs..."
for doc in issue-conventions issue-tracker-ops self-improvement; do
    src="$GOLDEN/agent_docs/$doc.md"
    dst="$TARGET/agent_docs/$doc.md"
    if [ -f "$dst" ]; then
        read -p "  $doc.md exists. Overwrite? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "  Skipped $doc.md"
            continue
        fi
    fi
    cp "$src" "$dst"
    echo "  Installed $doc.md"
done

# Create .claude/lessons.md if it doesn't exist
if [ ! -f "$TARGET/.claude/lessons.md" ]; then
    cat > "$TARGET/.claude/lessons.md" << 'LESSONS_EOF'
# Lessons

Active lessons from debugging, corrections, and code reviews. See `agent_docs/self-improvement.md` for format and lifecycle.
LESSONS_EOF
    echo "Created .claude/lessons.md"
fi

# Create compound-engineering.local.md template if it doesn't exist
if [ ! -f "$TARGET/compound-engineering.local.md" ]; then
    cat > "$TARGET/compound-engineering.local.md" << 'CE_EOF'
# Compound Engineering — Review Agent Config

## Stack

- [FILL IN: language, framework, cloud platform]

## Review Agents

- kieran-python-reviewer
- security-sentinel
- performance-oracle

## Protected Artifacts

- docs/plans/
- docs/brainstorms/
- tasks/
CE_EOF
    echo "Created compound-engineering.local.md (edit to match your stack)"
fi

# Handle CLAUDE.md
if [ -f "$TARGET/CLAUDE.md" ]; then
    echo ""
    echo "CLAUDE.md already exists. Checking for workflow section..."
    if grep -q "## Workflow" "$TARGET/CLAUDE.md"; then
        echo "  Workflow section already present — skipping CLAUDE.md"
    else
        echo "  Appending workflow section to existing CLAUDE.md..."
        cat >> "$TARGET/CLAUDE.md" << 'WORKFLOW_EOF'

## Workflow

### Commands Available

| Command | Purpose |
|---------|---------|
| `/wiggum` | Autonomous dev loop: pick issue → TDD → PR → close → repeat |
| `/create-issues` | Convert a plan into structured GitHub issues with deps |
| `/close-issue` | Quality gate: validate acceptance criteria, then close |
| `/triage` | Backlog analysis with dependency graph |
| `/pomo` | Post-mortem: capture lessons from debugging sessions |
| `/ce:brainstorm` | Explore requirements before planning |
| `/ce:plan` | Create detailed implementation plan |
| `/ce:review` | Multi-agent code review |

### Development Workflow

```
/ce:brainstorm → /ce:plan → /create-issues → /wiggum → /ce:review → /close-issue → /pomo
```

### Issue Tracker

**Tool:** GitHub CLI (`gh`) | **Format:** `#NN` | **Smart close:** `Closes #NN` | **Deps:** `- Blocked by: #NN — reason`

For issue format specs, see `agent_docs/issue-conventions.md`. For CLI operations, see `agent_docs/issue-tracker-ops.md`.

### Continuous Improvement

Maintain `.claude/lessons.md` with patterns from corrections and reviews. See `agent_docs/self-improvement.md` for format and lifecycle.

## Reference Docs

| Doc | When to read |
|-----|-------------|
| `agent_docs/issue-conventions.md` | Creating or editing issues |
| `agent_docs/issue-tracker-ops.md` | Running issue tracker CLI commands |
| `agent_docs/self-improvement.md` | Updating lessons |
WORKFLOW_EOF
        echo "  Appended workflow section"
    fi
else
    echo ""
    echo "No CLAUDE.md found. Run /bootstrap-project in Claude Code to generate one."
fi

# Update .claude/settings.local.json permissions
if [ -f "$TARGET/.claude/settings.local.json" ]; then
    echo ""
    echo "Checking .claude/settings.local.json for gh permissions..."
    if ! grep -q '"Bash(gh ' "$TARGET/.claude/settings.local.json"; then
        echo "  Consider adding gh CLI permissions to settings.local.json"
        echo '  Example: "Bash(gh issue *)", "Bash(gh pr *)", "Bash(gh api *)"'
    else
        echo "  gh permissions already present"
    fi
fi

echo ""
echo "============================================="
echo "Deployment complete!"
echo ""
echo "Next steps:"
echo "  1. cd $TARGET"
echo "  2. Edit compound-engineering.local.md for your stack"
echo "  3. Open in Claude Code"
echo "  4. Run /bootstrap-project to configure project-specific settings"
echo ""
echo "Available commands:"
echo "  /wiggum          — Autonomous dev loop"
echo "  /create-issues   — Plan to GitHub issues"
echo "  /close-issue     — Quality gate for closure"
echo "  /triage          — Backlog analysis"
echo "  /pomo            — Post-mortem & lessons"
echo "  /ce:brainstorm   — Explore requirements (from compound-engineering plugin)"
echo "  /ce:plan         — Create implementation plan (from compound-engineering plugin)"
echo "  /ce:review       — Multi-agent code review (from compound-engineering plugin)"
