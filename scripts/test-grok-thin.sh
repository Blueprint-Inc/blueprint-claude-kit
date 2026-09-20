#!/usr/bin/env bash
# Offline smoke for the thin Grok home. Does not rewrite $HOME/.grok.
set -euo pipefail
KIT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/grok-thin-test.XXXXXX")
DEFAULT="$TMP/default"
THIN="$TMP/thin"
mkdir -p "$DEFAULT/installed-plugins/compound-engineering-plugin-fake/skills/ce-worktree" "$DEFAULT/hooks"
printf '# fake\n' > "$DEFAULT/installed-plugins/compound-engineering-plugin-fake/skills/ce-worktree/SKILL.md"
printf '{}\n' > "$DEFAULT/auth.json"
# Pretend default still has fat plugins.
printf 'enabled = ["cloudflare", "sentry", "compound-engineering"]\n' > "$DEFAULT/config.toml"

export GROK_DEFAULT_HOME="$DEFAULT"
export GROK_THIN_HOME="$THIN"
bash "$KIT_ROOT/scripts/grok-thin.sh" --install-only

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -f "$THIN/config.toml" ] || fail "thin config missing"
[ -L "$THIN/bundled/skills/ce-worktree" ] || fail "ce-worktree not aliased into bundled/skills"
grep -q 'compound-engineering' "$THIN/config.toml" || fail "CE not enabled"
grep -q 'impeccable' "$THIN/config.toml" || fail "Impeccable not enabled"
grep -q 'hooks = false' "$THIN/config.toml" || fail "claude hooks not muted"
grep -q 'chrome-devtools-mcp' "$THIN/config.toml" || fail "devtools not disabled"
[ -f "$DEFAULT/config.toml" ] || fail "default config vanished"
grep -q cloudflare "$DEFAULT/config.toml" || fail "default config rewritten"

# Jev fail-open: no key, no catalog
printf '{"toolName":"run_terminal_command","toolInput":{"command":"true"}}\n' \
  | GROK_HOME="$THIN" python3 "$KIT_ROOT/scripts/grok-thin-home/hooks/jev-pretool.sh" \
  | grep -q '"allow"' || fail "Jev missing-key should allow"

# Off-catalog deny when catalog exists
mkdir -p "$THIN/state"
printf '%s\n' '{"names":["run_terminal_command","search_replace","write","use_tool"]}' > "$THIN/state/thin-catalog.json"
printf '{"toolName":"some_cut_mcp_tool","toolInput":{}}\n' \
  | GROK_HOME="$THIN" python3 "$KIT_ROOT/scripts/grok-thin-home/hooks/jev-pretool.sh" \
  | grep -q '"deny"' || fail "off-catalog should deny"

# Read is ungated even if not in catalog
printf '{"toolName":"read_file","toolInput":{"target_file":"x"}}\n' \
  | GROK_HOME="$THIN" python3 "$KIT_ROOT/scripts/grok-thin-home/hooks/jev-pretool.sh" \
  | grep -q '"allow"' || fail "read_file should allow"

# Impeccable skip on PHP
printf '{"toolName":"search_replace","toolInput":{"target_file":"app/Foo.php"}}\n' \
  | python3 "$KIT_ROOT/scripts/grok-thin-home/hooks/impeccable-ui-edit.sh" \
  || fail "impeccable php should fail-open"

# qmd not advertised
grep -q 'disabled = \["qmd"' "$THIN/config.toml" || fail "qmd not disabled"

# Hooks json present, no Stop
grep -q jev-pretool "$THIN/hooks/thin-session.json" || fail "jev hook json missing"
grep -qv '"Stop"' "$THIN/hooks/thin-session.json" || true
python3 -c '
import json,sys
d=json.load(open(sys.argv[1]))
assert "Stop" not in d["hooks"], "Stop hook must not exist"
assert "PreToolUse" in d["hooks"]
' "$THIN/hooks/thin-session.json" || fail "Stop hook present"

# No secrets in templates
! grep -E 'bos_pat_|Bearer ey' "$KIT_ROOT/scripts/grok-thin-home/config.toml.tmpl" \
  || fail "secret in template"

# Operator keep-set is linked when BlueprintOS is a sibling of the kit.
BOS="$KIT_ROOT/../blueprintos/.claude"
if [ -d "$BOS/commands" ]; then
  [ -L "$THIN/commands/deploy.md" ] || fail "missing /deploy command link"
  [ -L "$THIN/commands/ship.md" ] || fail "missing /ship command link"
  [ -L "$THIN/commands/release.md" ] || fail "missing /release command link"
  [ -L "$THIN/commands/start-work.md" ] || fail "missing /start-work command link"
  [ -L "$THIN/commands/finish-work.md" ] || fail "missing /finish-work command link"
  [ -L "$THIN/commands/sb-factory-triage.md" ] || fail "missing /sb-factory-triage command link"
  grep -q 'daily-prod-errors' "$THIN/config.toml" || fail "daily-prod-errors not in skills.paths"
  grep -q 'open-user-issues' "$THIN/config.toml" || fail "open-user-issues not in skills.paths"
fi

echo "OK grok-thin smoke ($TMP)"
rm -rf "$TMP"
