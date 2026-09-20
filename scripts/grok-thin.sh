#!/usr/bin/env bash
# Launch the opt-in thin Grok session. Does not rewrite $HOME/.grok.
# Usage: bash scripts/grok-thin.sh [--install-only] [--home DIR] [grok args...]
set -euo pipefail

KIT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEFAULT_HOME="${GROK_DEFAULT_HOME:-$HOME/.grok}"
THIN_HOME="${GROK_THIN_HOME:-$HOME/.grok-thin}"
INSTALL_ONLY=0
if [ "${1:-}" = "--install-only" ]; then
  INSTALL_ONLY=1
  shift
fi
if [ "${1:-}" = "--home" ]; then
  THIN_HOME="$2"
  shift 2
fi

ok() { printf '  grok-thin: %s\n' "$1"; }

mkdir -p "$THIN_HOME/hooks" "$THIN_HOME/state"

# Auth: share login with default home. Copy if symlink is refused later.
if [ -f "$DEFAULT_HOME/auth.json" ] && [ ! -e "$THIN_HOME/auth.json" ]; then
  ln -s "$DEFAULT_HOME/auth.json" "$THIN_HOME/auth.json"
  [ -f "$DEFAULT_HOME/auth.json.lock" ] && ln -sf "$DEFAULT_HOME/auth.json.lock" "$THIN_HOME/auth.json.lock"
  ok "linked auth from default Grok home"
fi
if [ -f "$DEFAULT_HOME/mcp_credentials.json" ] && [ ! -e "$THIN_HOME/mcp_credentials.json" ]; then
  ln -s "$DEFAULT_HOME/mcp_credentials.json" "$THIN_HOME/mcp_credentials.json"
fi

# Plugin store: thin config enables CE+Impeccable only; files live in the default store.
if [ -d "$DEFAULT_HOME/installed-plugins" ] && [ ! -e "$THIN_HOME/installed-plugins" ]; then
  ln -s "$DEFAULT_HOME/installed-plugins" "$THIN_HOME/installed-plugins"
  ok "linked installed-plugins store"
fi

KIT_SKILLS="$KIT_ROOT/skills"
OVERLAY_SKILLS="$KIT_ROOT/plugins/blueprint/skills"
IMPECCABLE_SKILL=""
if [ -d "$KIT_ROOT/../blueprintos/.claude/skills/impeccable" ]; then
  IMPECCABLE_SKILL="$(cd "$KIT_ROOT/../blueprintos/.claude/skills/impeccable" && pwd)"
elif [ -d "$HOME/.claude/plugins/cache/impeccable" ]; then
  found=$(find "$HOME/.claude/plugins/cache/impeccable" -type d -name impeccable -path '*/skills/impeccable' 2>/dev/null | head -1 || true)
  IMPECCABLE_SKILL="${found:-}"
fi
FIRECRAWL_SKILLS="$HOME/.agents/skills"

python3 - "$THIN_HOME/config.toml" "$KIT_SKILLS" "$OVERLAY_SKILLS" "$IMPECCABLE_SKILL" "$FIRECRAWL_SKILLS" "$THIN_HOME" <<'PY'
import os, sys
out, kit, overlay, impec, fire, thin = sys.argv[1:7]
paths = [p for p in (kit, overlay, impec) if p]
path_l = ",\n    ".join('"%s"' % p.replace("\\", "\\\\") for p in paths)
ignore = fire if fire else ""
ignore_l = '"%s"' % ignore.replace("\\", "\\\\") if ignore else ""
ignore_block = "ignore = [\n    %s\n]" % ignore_l if ignore_l else "ignore = []"
body = """# Thin Grok session. Written by scripts/grok-thin.sh. No secrets.

[plugins]
enabled = [
    "compound-engineering",
    "impeccable",
]
disabled = [
    "browser-use",
    "chrome-devtools-mcp",
    "cloudflare",
    "sentry",
]

[compat.claude]
agents = false
hooks = false
mcps = false
rules = false
skills = false

[compat.cursor]
agents = false
hooks = false
mcps = false
rules = false
skills = false

[compat.codex]
hooks = false

[skills]
paths = [
    %s
]
%s
disabled = ["qmd", "typesafe-ai", "whathappened"]

[mcp_servers.playwright]
command = "npx"
args = ["-y", "@playwright/mcp@latest"]
enabled = true

[mcp_servers.blueprintos-tasks]
url = "https://api.styleblueprint.ai/mcp"
enabled = true
""" % (path_l, ignore_block)
open(out, "w").write(body)
PY

HOOK_SRC="$KIT_ROOT/scripts/grok-thin-home/hooks"
cp "$HOOK_SRC/jev-pretool.sh" "$THIN_HOME/hooks/jev-pretool.sh"
cp "$HOOK_SRC/impeccable-ui-edit.sh" "$THIN_HOME/hooks/impeccable-ui-edit.sh"
cp "$HOOK_SRC/write-catalog.sh" "$THIN_HOME/hooks/write-catalog.sh"
chmod +x "$THIN_HOME/hooks/"*.sh

# JSON hooks: commands relative to this JSON file (Grok hook-file rule).
python3 - "$THIN_HOME/hooks/thin-session.json" <<'PY'
import json, sys
path = sys.argv[1]
doc = {
  "hooks": {
    "SessionStart": [{"hooks": [{"type": "command", "command": "./write-catalog.sh", "timeout": 15}]}],
    "PreToolUse": [{
      "matcher": "run_terminal_command|search_replace|write|use_tool|spawn_subagent|Bash|Write|Edit|MultiEdit",
      "hooks": [{"type": "command", "command": "./jev-pretool.sh", "timeout": 8}],
    }],
    "PostToolUse": [{
      "matcher": "search_replace|write|Write|Edit|MultiEdit",
      "hooks": [{"type": "command", "command": "./impeccable-ui-edit.sh", "timeout": 6}],
    }],
  }
}
json.dump(doc, open(path, "w"), indent=2)
open(path, "a").write("\n")
PY

ok "thin home at $THIN_HOME"
ok "default home untouched: $DEFAULT_HOME"

if [ "$INSTALL_ONLY" = 1 ]; then
  exit 0
fi
export GROK_HOME="$THIN_HOME"
exec grok "$@"
