#!/bin/bash
set -euo pipefail

# Blueprint Claude Kit — Sync global slash commands
# Copies selected golden commands into ~/.claude/commands/ so they are
# available as user-level (global) slash commands in every project.
#
# Re-run this after pulling kit updates to refresh the global copies.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GOLDEN_COMMANDS="$SCRIPT_DIR/golden/.claude/commands"
DEST="${CLAUDE_HOME:-$HOME/.claude}/commands"

# Commands to expose globally. Add more slugs here as needed.
COMMANDS=(
    start-work
    finish-work
)

DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        --dry-run|-n) DRY_RUN=true ;;
        --help|-h)
            echo "Usage: $0 [--dry-run]"
            echo "Syncs golden commands (${COMMANDS[*]}) into $DEST"
            exit 0
            ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

mkdir -p "$DEST"

for name in "${COMMANDS[@]}"; do
    src="$GOLDEN_COMMANDS/$name.md"
    dst="$DEST/$name.md"
    if [ ! -f "$src" ]; then
        echo "  skip: $name (missing $src)" >&2
        continue
    fi
    if $DRY_RUN; then
        echo "  [dry-run] would copy $name -> $dst"
        continue
    fi
    cp "$src" "$dst"
    echo "  synced: $name -> $dst"
done

$DRY_RUN || echo "Done. Global commands available in every project."
