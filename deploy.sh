#!/bin/bash
set -euo pipefail

# Blueprint Claude Kit — Deploy to any project
# Combines compound-engineering review agents with bootstrapping's
# autonomous dev loop, issue management, and self-improvement system.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GOLDEN="$SCRIPT_DIR/golden"
KIT_VERSION=$(cat "$SCRIPT_DIR/VERSION" 2>/dev/null || echo "unknown")

# --- Flags ---
usage() {
    echo "Usage: $0 [options] <target-project-path>"
    echo ""
    echo "Deploys the Blueprint Claude Kit into a project directory."
    echo "Copies commands, skills, agent_docs, and templates."
    echo "Does NOT overwrite existing CLAUDE.md — merges safely."
    echo ""
    echo "Options:"
    echo "  --yes, -y      Skip all prompts (overwrite everything)"
    echo "  --dry-run, -n  Show what would change without applying"
    echo "  --help, -h     Show this help"
    echo ""
    echo "After deploying, open the project in Claude Code and run:"
    echo "  /bootstrap-project"
    exit 1
}

YES_MODE=false
DRY_RUN=false
TARGET=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes|-y) YES_MODE=true; shift ;;
        --dry-run|-n) DRY_RUN=true; shift ;;
        --help|-h) usage ;;
        -*) echo "Unknown option: $1"; exit 1 ;;
        *) TARGET="$1"; shift ;;
    esac
done

if [ -z "$TARGET" ]; then
    usage
fi

if [ ! -d "$TARGET" ]; then
    echo "Error: '$TARGET' is not a directory"
    exit 1
fi

# --- Helper functions ---

confirm() {
    local msg="$1"
    if $YES_MODE; then
        return 0
    fi
    read -p "$msg [y/N] " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

sha256_file() {
    shasum -a 256 "$1" 2>/dev/null | cut -d' ' -f1
}

dry_run_msg() {
    if $DRY_RUN; then
        echo "  [dry-run] Would $1"
        return 0
    fi
    return 1
}

# --- Dependency check ---

echo "Checking prerequisites..."
MISSING_REQUIRED=()
MISSING_RECOMMENDED=()

if ! command -v claude &>/dev/null; then
    MISSING_REQUIRED+=("claude (Claude Code CLI)")
fi

if ! gh auth status &>/dev/null 2>&1; then
    MISSING_REQUIRED+=("gh auth (GitHub CLI not authenticated)")
fi

if ! command -v bun &>/dev/null; then
    MISSING_RECOMMENDED+=("bun (needed for qmd)")
fi

if ! command -v node &>/dev/null; then
    MISSING_RECOMMENDED+=("node (needed for GitNexus, Playwright)")
fi

if [ ${#MISSING_REQUIRED[@]} -gt 0 ]; then
    echo ""
    echo "ERROR: Missing required tools:"
    for dep in "${MISSING_REQUIRED[@]}"; do
        echo "  - $dep"
    done
    echo ""
    echo "Run setup.sh first: $SCRIPT_DIR/setup.sh"
    exit 1
fi

if [ ${#MISSING_RECOMMENDED[@]} -gt 0 ]; then
    echo ""
    echo "WARNING: Missing recommended tools:"
    for dep in "${MISSING_RECOMMENDED[@]}"; do
        echo "  - $dep"
    done
    echo "  Consider running: $SCRIPT_DIR/setup.sh"
    echo ""
fi

echo "  Prerequisites OK"

# --- Version check ---

LOCAL_VERSION=$(cat "$TARGET/.claude/.blueprint-kit-version" 2>/dev/null || echo "")
if [ -n "$LOCAL_VERSION" ] && [ "$LOCAL_VERSION" != "$KIT_VERSION" ]; then
    echo ""
    echo "Upgrading: $LOCAL_VERSION → $KIT_VERSION"
elif [ -n "$LOCAL_VERSION" ] && [ "$LOCAL_VERSION" = "$KIT_VERSION" ]; then
    echo ""
    echo "Kit version $KIT_VERSION (already current)"
else
    echo ""
    echo "Kit version: $KIT_VERSION (first deploy)"
fi

echo ""
echo "Blueprint Claude Kit — Deploying to: $TARGET"
echo "============================================="

# --- Manifest tracking (bash 3 compatible via temp files) ---

MANIFEST_FILE="$TARGET/.claude/blueprint-kit-manifest.json"
OLD_MANIFEST_TMP=$(mktemp)
NEW_MANIFEST_TMP=$(mktemp)
trap "rm -f '$OLD_MANIFEST_TMP' '$NEW_MANIFEST_TMP'" EXIT

# Parse existing manifest into temp file (format: sha256<TAB>filepath)
if [ -f "$MANIFEST_FILE" ]; then
    python3 -c "
import json, sys
with open('$MANIFEST_FILE') as f:
    m = json.load(f)
for path, info in m.get('files', {}).items():
    print(info['sha256'] + '\t' + path)
" > "$OLD_MANIFEST_TMP" 2>/dev/null || true
fi

# Helper: record a deployed file in the new manifest
record_file() {
    local rel="$1" hash="$2"
    echo "$hash	$rel" >> "$NEW_MANIFEST_TMP"
}

# Helper: get old manifest hash for a file
old_manifest_hash() {
    local rel="$1"
    grep "	${rel}$" "$OLD_MANIFEST_TMP" 2>/dev/null | cut -f1
}

# --- Create directories ---

if ! $DRY_RUN; then
    echo ""
    echo "Creating directories..."
    mkdir -p "$TARGET/.claude/commands"
    mkdir -p "$TARGET/.claude/skills"
    mkdir -p "$TARGET/agent_docs"
    mkdir -p "$TARGET/agent_docs/postmortems"
    mkdir -p "$TARGET/tasks/instincts"
fi

# --- Copy commands ---

echo ""
echo "Installing commands..."
for cmd in wiggum create-issues close-issue triage bootstrap-project deploy-blueprint-claude start-work finish-work; do
    src="$GOLDEN/.claude/commands/$cmd.md"
    dst="$TARGET/.claude/commands/$cmd.md"
    rel=".claude/commands/$cmd.md"

    if [ ! -f "$src" ]; then
        continue
    fi

    if $DRY_RUN; then
        if [ -f "$dst" ]; then
            if [ "$(sha256_file "$src")" != "$(sha256_file "$dst")" ]; then
                echo "  [dry-run] Would update $cmd.md"
            else
                echo "  [dry-run] $cmd.md unchanged"
            fi
        else
            echo "  [dry-run] Would install $cmd.md"
        fi
        record_file "$rel" "$(sha256_file "$src")"
        continue
    fi

    if [ -f "$dst" ]; then
        if ! confirm "  $cmd.md exists. Overwrite?"; then
            echo "  Skipped $cmd.md"
            record_file "$rel" "$(sha256_file "$dst")"
            continue
        fi
    fi
    cp "$src" "$dst"
    echo "  Installed $cmd.md"
    record_file "$rel" "$(sha256_file "$dst")"
done

# --- Copy skills (every directory under golden/.claude/skills/, recursively) ---
# Generalized from the old single-file pomo copy so multi-file skills (with
# references/, scripts/, nested dirs) deploy intact. Each file gets the same
# overwrite-confirm + manifest treatment as commands. bash 3 compatible
# (find + while-read + process substitution; no associative arrays).

echo ""
echo "Installing skills..."
if [ -d "$GOLDEN/.claude/skills" ]; then
    while IFS= read -r src; do
        rel="${src#"$GOLDEN"/}"
        dst="$TARGET/$rel"

        if $DRY_RUN; then
            if [ -f "$dst" ]; then
                if [ "$(sha256_file "$src")" != "$(sha256_file "$dst")" ]; then
                    echo "  [dry-run] Would update $rel"
                else
                    echo "  [dry-run] $rel unchanged"
                fi
            else
                echo "  [dry-run] Would install $rel"
            fi
            record_file "$rel" "$(sha256_file "$src")"
            continue
        fi

        if [ -f "$dst" ]; then
            if [ "$(sha256_file "$src")" = "$(sha256_file "$dst")" ]; then
                record_file "$rel" "$(sha256_file "$dst")"
                continue
            fi
            if ! confirm "  $rel exists. Overwrite?"; then
                echo "  Skipped $rel"
                record_file "$rel" "$(sha256_file "$dst")"
                continue
            fi
        fi
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
        echo "  Installed $rel"
        record_file "$rel" "$(sha256_file "$dst")"
    done < <(find "$GOLDEN/.claude/skills" -type f | sort)
fi

# --- Copy agent_docs ---

echo ""
echo "Installing agent_docs..."
for doc in issue-conventions issue-tracker-ops self-improvement canonical-skill-map postmortems/README; do
    src="$GOLDEN/agent_docs/$doc.md"
    dst="$TARGET/agent_docs/$doc.md"
    rel="agent_docs/$doc.md"

    if [ ! -f "$src" ]; then
        continue
    fi

    if $DRY_RUN; then
        if [ -f "$dst" ]; then
            if [ "$(sha256_file "$src")" != "$(sha256_file "$dst")" ]; then
                echo "  [dry-run] Would update $doc.md"
            else
                echo "  [dry-run] $doc.md unchanged"
            fi
        else
            echo "  [dry-run] Would install $doc.md"
        fi
        record_file "$rel" "$(sha256_file "$src")"
        continue
    fi

    if [ -f "$dst" ]; then
        if ! confirm "  $doc.md exists. Overwrite?"; then
            echo "  Skipped $doc.md"
            record_file "$rel" "$(sha256_file "$dst")"
            continue
        fi
    fi
    cp "$src" "$dst"
    echo "  Installed $doc.md"
    record_file "$rel" "$(sha256_file "$dst")"
done

# --- Detect orphaned files ---

if [ -s "$OLD_MANIFEST_TMP" ]; then
    echo ""
    while IFS=$'\t' read -r old_hash old_file; do
        if ! grep -q "	${old_file}$" "$NEW_MANIFEST_TMP" 2>/dev/null && [ -f "$TARGET/$old_file" ]; then
            current_hash=$(sha256_file "$TARGET/$old_file")
            if [ "$current_hash" = "$old_hash" ]; then
                if $DRY_RUN; then
                    echo "  [dry-run] Would remove orphaned file: $old_file"
                elif confirm "  $old_file was removed from kit. Delete?"; then
                    rm "$TARGET/$old_file"
                    echo "  Removed $old_file"
                else
                    echo "  Kept $old_file"
                fi
            else
                echo "  $old_file was removed from kit but you've customized it. Keeping."
            fi
        fi
    done < "$OLD_MANIFEST_TMP"
fi

# --- Create templates ---

if ! $DRY_RUN; then
    # Create .claude/lessons.md if it doesn't exist
    if [ ! -f "$TARGET/.claude/lessons.md" ]; then
        cat > "$TARGET/.claude/lessons.md" << 'LESSONS_EOF'
# Lessons

Active lessons from debugging, corrections, and code reviews. See `agent_docs/self-improvement.md` for format and lifecycle.
LESSONS_EOF
        echo ""
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
fi

# --- Handle CLAUDE.md ---

if ! $DRY_RUN; then
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
| `/ce-brainstorm` | Explore requirements before planning |
| `/ce-plan` | Create detailed implementation plan |
| `/ce-code-review` | Multi-agent code review |

### Development Workflow

```
/ce-brainstorm → /ce-plan → /create-issues → /wiggum → /ce-code-review → /close-issue → /pomo
```

### Canonical Skills

When multiple plugins provide overlapping skills, use these:

| Workflow | Use This | Not This |
|----------|----------|----------|
| Brainstorm | `/ce-brainstorm` | `superpowers:brainstorming` |
| Plan | `/ce-plan` | `superpowers:writing-plans` |
| Execute | `/ce-work` | `superpowers:executing-plans` |
| Review (give) | `/ce-code-review` | `superpowers:requesting-code-review` |
| Git worktrees | `/ce-worktree` | `superpowers:using-git-worktrees` |
| Write skills | `/ce-create-agent-skills` | `superpowers:writing-skills` |
| Frontend UI | `/ce-frontend-design` | — |

Superpowers-only (no CE equivalent): TDD, verification-before-completion, receiving-code-review, dispatching-parallel-agents, finishing-a-development-branch.

For the full skill map, see `agent_docs/canonical-skill-map.md`.

### Issue Tracker

**Tool:** GitHub CLI (`gh`) | **Format:** `#NN` | **Smart close:** `Closes #NN` | **Deps:** `- Blocked by: #NN — reason`

For issue format specs, see `agent_docs/issue-conventions.md`. For CLI operations, see `agent_docs/issue-tracker-ops.md`.

### Postmortems

After deploying a **bug fix**, write a postmortem to `agent_docs/postmortems/` if:
- The root cause was surprising or non-obvious
- The bug recurred (2+ occurrences)
- Production data or user-facing behavior was affected
- The fix required understanding multiple interacting systems

See `agent_docs/postmortems/README.md` for format. Search existing postmortems before debugging — the answer may already be there.

### Continuous Improvement

Maintain `.claude/lessons.md` with patterns from corrections and reviews. See `agent_docs/self-improvement.md` for format and lifecycle.

## Reference Docs

| Doc | When to read |
|-----|-------------|
| `agent_docs/canonical-skill-map.md` | Choosing between overlapping skills |
| `agent_docs/issue-conventions.md` | Creating or editing issues |
| `agent_docs/issue-tracker-ops.md` | Running issue tracker CLI commands |
| `agent_docs/self-improvement.md` | Updating lessons |
| `agent_docs/postmortems/` | Debugging recurring or non-obvious bugs |
WORKFLOW_EOF
            echo "  Appended workflow section"
        fi
    else
        echo ""
        echo "No CLAUDE.md found. Run /bootstrap-project in Claude Code to generate one."
    fi
fi

# --- Version stamping ---

if ! $DRY_RUN; then
    echo "$KIT_VERSION" > "$TARGET/.claude/.blueprint-kit-version"
    echo ""
    echo "Stamped kit version: $KIT_VERSION"
fi

# --- Write manifest ---

if ! $DRY_RUN; then
    python3 -c "
import json, sys
files = {}
with open('$NEW_MANIFEST_TMP') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        parts = line.split('\t', 1)
        if len(parts) == 2:
            files[parts[1]] = {'sha256': parts[0]}
manifest = {
    'version': '$KIT_VERSION',
    'deployedAt': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
    'files': dict(sorted(files.items()))
}
with open('$MANIFEST_FILE', 'w') as f:
    json.dump(manifest, f, indent=2)
    f.write('\n')
"
    echo "Written manifest: .claude/blueprint-kit-manifest.json"
fi

# --- SessionStart upgrade hook ---

if ! $DRY_RUN; then
    SETTINGS_FILE="$TARGET/.claude/settings.local.json"
    HOOK_CMD="bash -c 'KIT_VER=\$(cat ~/Projects/blueprint-claude-kit/VERSION 2>/dev/null || echo unknown); LOCAL_VER=\$(cat .claude/.blueprint-kit-version 2>/dev/null || echo none); [ \"\$KIT_VER\" != \"\$LOCAL_VER\" ] && echo \"Blueprint kit update available: \$LOCAL_VER -> \$KIT_VER. Run /deploy-blueprint-claude\" || true'"

    if [ -f "$SETTINGS_FILE" ]; then
        # Check if hook already exists
        if ! grep -q "blueprint-claude-kit/VERSION" "$SETTINGS_FILE" 2>/dev/null; then
            echo ""
            echo "Adding SessionStart upgrade hook to settings.local.json..."
            # Use python3 to merge the hook into existing JSON
            python3 -c "
import json, sys
with open('$SETTINGS_FILE', 'r') as f:
    settings = json.load(f)
hooks = settings.setdefault('hooks', {})
session_hooks = hooks.setdefault('SessionStart', [])
session_hooks.append({'command': '''$HOOK_CMD'''})
with open('$SETTINGS_FILE', 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')
" 2>/dev/null && echo "  Installed SessionStart hook" || echo "  Could not merge hook into settings.local.json (manual setup needed)"
        else
            echo ""
            echo "SessionStart upgrade hook already present"
        fi
    else
        echo ""
        echo "Creating settings.local.json with SessionStart upgrade hook..."
        cat > "$SETTINGS_FILE" << HOOK_EOF
{
  "hooks": {
    "SessionStart": [
      {
        "command": "$HOOK_CMD"
      }
    ]
  }
}
HOOK_EOF
        echo "  Created settings.local.json with SessionStart hook"
    fi
fi

# --- Check permissions ---

if ! $DRY_RUN; then
    SETTINGS_FILE="$TARGET/.claude/settings.local.json"
    if [ -f "$SETTINGS_FILE" ]; then
        if ! grep -q '"Bash(gh ' "$SETTINGS_FILE"; then
            echo ""
            echo "Consider adding gh CLI permissions to settings.local.json:"
            echo '  "Bash(gh issue *)", "Bash(gh pr *)", "Bash(gh api *)"'
        fi
    fi
fi

# --- GitNexus auto-indexing ---

if ! $DRY_RUN; then
    echo ""
    if command -v gitnexus &>/dev/null || command -v npx &>/dev/null; then
        if [ ! -d "$TARGET/.gitnexus" ]; then
            echo "Starting GitNexus indexing in background..."
            (cd "$TARGET" && npx gitnexus analyze . &>/dev/null &)
            echo "  GitNexus indexing started (background)"
        else
            echo "GitNexus index already exists"
        fi
    else
        echo "GitNexus not installed — skipping index (install with: npm install -g gitnexus)"
    fi
fi

# --- Summary ---

echo ""
echo "============================================="
if $DRY_RUN; then
    echo "Dry run complete — no changes made."
else
    echo "Deployment complete! (kit v$KIT_VERSION)"
fi
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
echo "  /start-work      — Start an isolated worktree session"
echo "  /finish-work     — Commit, PR, and clean up the worktree"
echo "  /pomo            — Post-mortem & lessons"
echo "  /deploy-blueprint-claude — Update from blueprint-claude-kit"
echo "  /ce-brainstorm   — Explore requirements (from compound-engineering plugin)"
echo "  /ce-plan         — Create implementation plan (from compound-engineering plugin)"
echo "  /ce-code-review       — Multi-agent code review (from compound-engineering plugin)"
echo ""
echo "First time? See the full onboarding guide:"
echo "  $SCRIPT_DIR/ONBOARDING.md"
