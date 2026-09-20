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

# Grok's skill-read UI always opens $GROK_HOME/bundled/skills/<name>/SKILL.md.
# Plugin skills live under installed-plugins, so that first path 404s (seen as
# "Read 1 skill · 1 failed" for ce-worktree). Alias them into bundled/skills.
python3 - "$THIN_HOME" <<'PY'
import sys
from pathlib import Path
home = Path(sys.argv[1])
bundled = home / "bundled" / "skills"
plugins = home / "installed-plugins"
bundled.mkdir(parents=True, exist_ok=True)
allow_frags = ("compound-engineering", "impeccable")
skip_names = {
    "agent-only-skill", "claude-only-skill", "default-skill",
    "disabled-skill", "skill-one",
}
wanted = {}
if plugins.exists():
    for skill_md in plugins.glob("**/skills/*/SKILL.md"):
        parts = [p.lower() for p in skill_md.parts]
        if not any(f in "/".join(parts) for f in allow_frags):
            continue
        name = skill_md.parent.name
        if name in skip_names:
            continue
        wanted[name] = skill_md.parent.resolve()
linked = 0
for dest in list(bundled.iterdir()) if bundled.exists() else []:
    if dest.is_symlink() and dest.name not in wanted:
        dest.unlink()
for name, src in wanted.items():
    dest = bundled / name
    if dest.exists() or dest.is_symlink():
        if dest.is_symlink() and dest.resolve() == src:
            continue
        if dest.exists() and not dest.is_symlink():
            continue
        dest.unlink()
    dest.symlink_to(src)
    linked += 1
print("  grok-thin: aliased %d CE/Impeccable skills into bundled/skills" % linked)
PY

BOS_ROOT="${GROK_THIN_BOS_ROOT:-$KIT_ROOT/../blueprintos}"
if [ -d "$BOS_ROOT" ]; then
  BOS_ROOT="$(cd "$BOS_ROOT" && pwd)"
else
  BOS_ROOT=""
fi

KIT_SKILLS="$KIT_ROOT/skills"
OVERLAY_SKILLS="$KIT_ROOT/plugins/blueprint/skills"
GOLDEN_COMMANDS="$KIT_ROOT/golden/.claude/commands"
BOS_COMMANDS="$BOS_ROOT/.claude/commands"
BOS_SKILLS="$BOS_ROOT/.claude/skills"
IMPECCABLE_SKILL=""
if [ -d "$BOS_SKILLS/impeccable" ]; then
  IMPECCABLE_SKILL="$BOS_SKILLS/impeccable"
elif [ -d "$HOME/.claude/plugins/cache/impeccable" ]; then
  found=$(find "$HOME/.claude/plugins/cache/impeccable" -type d -name impeccable -path '*/skills/impeccable' 2>/dev/null | head -1 || true)
  IMPECCABLE_SKILL="${found:-}"
fi
FIRECRAWL_SKILLS="$HOME/.agents/skills"

# Slash commands Grok will not see from .claude/commands while Claude-compat is off.
mkdir -p "$THIN_HOME/commands"
link_cmd() {
  src="$1"
  stem="$2"
  if [ -f "$src" ]; then
    ln -sf "$src" "$THIN_HOME/commands/${stem}.md"
    ok "command /$stem"
  fi
}
# 1: deploy, ship, release  2: start-work, finish-work  3: factory triage
link_cmd "$BOS_COMMANDS/deploy.md" deploy
link_cmd "$BOS_COMMANDS/ship.md" ship
link_cmd "$BOS_COMMANDS/release.md" release
if [ -f "$BOS_COMMANDS/start-work.md" ]; then
  link_cmd "$BOS_COMMANDS/start-work.md" start-work
elif [ -f "$KIT_ROOT/skills/start-work/SKILL.md" ]; then
  link_cmd "$KIT_ROOT/skills/start-work/SKILL.md" start-work
else
  link_cmd "$GOLDEN_COMMANDS/start-work.md" start-work
fi
if [ -f "$BOS_COMMANDS/finish-work.md" ]; then
  link_cmd "$BOS_COMMANDS/finish-work.md" finish-work
elif [ -f "$KIT_ROOT/skills/finish-work/SKILL.md" ]; then
  link_cmd "$KIT_ROOT/skills/finish-work/SKILL.md" finish-work
else
  link_cmd "$GOLDEN_COMMANDS/finish-work.md" finish-work
fi
link_cmd "$BOS_COMMANDS/sb-factory-triage.md" sb-factory-triage

# 3+4: skill dirs (SKILL.md), not the whole BOS skills tree
KEEP_SKILL_DIRS=""
for d in sb-factory-triage daily-prod-errors wp-bos-sync whatshipped open-user-issues; do
  if [ -f "$BOS_SKILLS/$d/SKILL.md" ]; then
    KEEP_SKILL_DIRS="$KEEP_SKILL_DIRS $BOS_SKILLS/$d"
    ok "skill $d"
  fi
done

# KEEP_SKILL_DIRS is space-separated; unquoted so each dir is its own argv.
python3 - "$THIN_HOME/config.toml" "$DEFAULT_HOME/config.toml" "$KIT_SKILLS" "$OVERLAY_SKILLS" "$IMPECCABLE_SKILL" "$FIRECRAWL_SKILLS" $KEEP_SKILL_DIRS <<'PY'
import os, sys
out, default_cfg, kit, overlay, impec, fire = sys.argv[1:7]
extra = [p for p in sys.argv[7:] if p]
paths = [p for p in [kit, overlay, impec] + extra if p and os.path.isdir(p)]
path_l = ",\n    ".join('"%s"' % p.replace("\\", "\\\\") for p in paths)
ignore_dirs = [p for p in (fire, os.path.expanduser("~/.claude/skills"), os.path.expanduser("~/.cursor/skills")) if p]
ignore_l = ",\n    ".join('"%s"' % p.replace("\\", "\\\\") for p in ignore_dirs)
ignore_block = "ignore = [\n    %s\n]" % ignore_l if ignore_l else "ignore = []"
disabled = [
    "qmd", "typesafe-ai", "whathappened",
    "agent-only-skill", "claude-only-skill", "default-skill", "disabled-skill", "skill-one",
    "game-animation-frames", "game-asset-core", "game-character-consistency",
    "game-tilesets", "game-ui-icons", "imagine",
    "pdf", "pptx", "docx",
    "resume-claude", "resume-codex", "resume-cursor",
    "build-with-ai", "create-skill", "create-workflow", "statusline",
    "skill-design-principles", "execute-plan", "design",
]
disabled_l = ",\n    ".join('"%s"' % n for n in disabled)

def bos_headers(path):
    try:
        lines = open(path).read().splitlines()
    except OSError:
        return {}
    in_tbl = False
    headers = {}
    for line in lines:
        s = line.strip()
        if s.startswith("["):
            in_tbl = s == "[mcp_servers.blueprintos-tasks.headers]"
            continue
        if in_tbl and "=" in s and not s.startswith("#"):
            k, v = s.split("=", 1)
            headers[k.strip()] = v.strip()
    return headers

hdr = bos_headers(default_cfg)
hdr_block = ""
if hdr:
    hdr_block = "\n[mcp_servers.blueprintos-tasks.headers]\n"
    for k, v in hdr.items():
        hdr_block += "%s = %s\n" % (k, v)

body = """# Thin Grok session. Written by scripts/grok-thin.sh. Secrets only copied from the default Grok home on this machine.

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
disabled = [
    %s
]

[mcp_servers.playwright]
command = "npx"
args = ["-y", "@playwright/mcp@latest"]
enabled = true

[mcp_servers.blueprintos-tasks]
url = "https://api.styleblueprint.ai/mcp"
enabled = true
%s""" % (path_l, ignore_block, disabled_l, hdr_block)
open(out, "w").write(body)
if hdr:
    print("  grok-thin: copied BlueprintOS tasks MCP headers from default Grok home")
PY

HOOK_SRC="$KIT_ROOT/scripts/grok-thin-home/hooks"
cp "$HOOK_SRC/jev-pretool.sh" "$THIN_HOME/hooks/jev-pretool.sh"
cp "$HOOK_SRC/impeccable-ui-edit.sh" "$THIN_HOME/hooks/impeccable-ui-edit.sh"
cp "$HOOK_SRC/write-catalog.sh" "$THIN_HOME/hooks/write-catalog.sh"
chmod +x "$THIN_HOME/hooks/"*.sh

JEV_KEY="${JEV_API_KEY_FILE:-$HOME/.config/dev-approved-lfg/jev_api_key}"
python3 - "$THIN_HOME/hooks/thin-session.json" "$JEV_KEY" <<'PY'
import json, os, sys
path, key = sys.argv[1], sys.argv[2]
doc = {
  "hooks": {
    "SessionStart": [{"hooks": [{"type": "command", "command": "./write-catalog.sh", "timeout": 15}]}],
    "PostToolUse": [{
      "matcher": "search_replace|write|Write|Edit|MultiEdit",
      "hooks": [{"type": "command", "command": "./impeccable-ui-edit.sh", "timeout": 6}],
    }],
  }
}
if os.path.isfile(key) and os.path.getsize(key) > 0:
    doc["hooks"]["PreToolUse"] = [{
      "matcher": "run_terminal_command|search_replace|write|use_tool|spawn_subagent|Bash|Write|Edit|MultiEdit",
      "hooks": [{"type": "command", "command": "./jev-pretool.sh", "timeout": 8}],
    }]
    print("  grok-thin: Jev PreToolUse enabled")
else:
    print("  grok-thin: Jev hook skipped (no key). Run scripts/pickup-jev-key.sh")
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
