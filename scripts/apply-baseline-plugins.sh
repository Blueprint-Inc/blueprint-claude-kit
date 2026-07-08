#!/bin/bash
# Apply the Blueprint baseline plugin set to ~/.claude/settings.json.
# See docs/claude-setup-baseline.md for the rationale behind each state.
set -euo pipefail

SETTINGS="$HOME/.claude/settings.json"
[ -f "$SETTINGS" ] || { echo "ERROR: $SETTINGS not found"; exit 1; }

BACKUP="$SETTINGS.bak-baseline-$(date +%Y%m%d%H%M%S)"
cp "$SETTINGS" "$BACKUP"

python3 - "$SETTINGS" <<'PY'
import json, sys
path = sys.argv[1]
d = json.load(open(path))
plugins = d.setdefault("enabledPlugins", {})
baseline = {
    "compound-engineering@compound-engineering-plugin": True,
    "frontend-design@claude-plugins-official": True,
    "playwright@claude-plugins-official": True,
    "claude-md-management@claude-plugins-official": True,
    "claude-code-setup@claude-plugins-official": True,
    "superpowers@claude-plugins-official": False,
    "code-review@claude-plugins-official": False,
    "pr-review-toolkit@claude-plugins-official": False,
    "pr-review-toolkit@claude-code-plugins": False,
    "frontend-design@claude-code-plugins": False,
    "ralph-loop@claude-plugins-official": False,
    "ralph-wiggum@claude-code-plugins": False,
    "github@claude-plugins-official": False,
}
changed = []
for k, v in baseline.items():
    if k in plugins and plugins[k] != v:
        plugins[k] = v
        changed.append(f"{k} -> {v}")
    elif k not in plugins and v is False:
        pass  # not installed; nothing to disable
    elif k not in plugins and v is True:
        changed.append(f"NOTE: {k} not installed - install it via /plugin")
json.dump(d, open(path, "w"), indent=2)
json.load(open(path))  # re-validate
print("Applied baseline. Changes:")
print("\n".join(changed) if changed else "  (already at baseline)")
PY

echo "Backup at: $BACKUP"
echo "Restart Claude Code sessions to pick up the new plugin set."
