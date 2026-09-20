#!/usr/bin/env bash
# SessionStart: snapshot remaining tool names for Jev. Fail-open.
set -eu
HOME_DIR="${GROK_HOME:-$HOME/.grok-thin}"
STATE="$HOME_DIR/state"
mkdir -p "$STATE"
OUT="$STATE/thin-catalog.json"
DEFAULT='{"names":["run_terminal_command","search_replace","write","use_tool","spawn_subagent"]}'
if ! command -v grok >/dev/null 2>&1; then
  printf '%s\n' "$DEFAULT" > "$OUT"
  exit 0
fi
json=$(GROK_HOME="$HOME_DIR" grok inspect --json 2>/dev/null || true)
printf '%s' "$json" | python3 -c '
import json, sys
out = sys.argv[1]
raw = sys.stdin.read()
base = ["run_terminal_command", "search_replace", "write", "use_tool", "spawn_subagent"]
try:
    data = json.loads(raw) if raw.strip() else {}
except Exception:
    data = {}

def walk(obj, acc):
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k in ("name", "skill", "id") and isinstance(v, str) and v:
                acc.append(v)
            walk(v, acc)
    elif isinstance(obj, list):
        for i in obj:
            walk(i, acc)

found = []
walk(data, found)
merged = []
for n in base + found:
    if n not in merged:
        merged.append(n)
open(out, "w").write(json.dumps({"names": merged}, indent=2) + "\n")
' "$OUT" || printf '%s\n' "$DEFAULT" > "$OUT"
exit 0
