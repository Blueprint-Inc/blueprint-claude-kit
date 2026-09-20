#!/bin/bash
# migrate-from-kit.sh — retire the old copy-based kit from a machine.
#
# The kit used to copy itself into every project. It now installs as a plugin, so those
# copies are stale duplicates that SHADOW the plugin's own skills. This removes them.
#
# Inventory-first by design. With no flags it changes nothing and prints what it found.
# Only --apply modifies anything, and even then:
#
#   - A file is removed only when the deploy manifest attributes it to the kit AND its
#     hash still matches. A kit file you edited is preserved and reported by path.
#   - A project-owned file is never touched. The one deployed project here interleaves
#     8 kit commands with 10 of its own, and 3 kit skills with 17 of its own.
#   - Your permission allowlists are reported, never rewritten. Those are approvals you
#     granted; a stale one is inert.
#   - Settings files are backed up with a timestamp and re-validated as JSON before and
#     after any write.
#
# Safe to run twice: the second run finds nothing and says so.
# Safe on a machine that never had the kit: it finds nothing and says so.
#
# Usage:  scripts/migrate-from-kit.sh [--apply] [--root ~/Projects]
set -uo pipefail

OLD_NAME="blueprint-claude-kit"
NEW_NAME="blueprintos-code-kit"
ROOT="${CLEANUP_ROOT:-$HOME/Projects}"
APPLY=false
CLAUDE_DIR="${CLAUDE_HOME:-$HOME/.claude}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply) APPLY=true; shift ;;
    --root)  ROOT="$2"; shift 2 ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

removed=0; preserved=0; reported=0
say()    { echo "$@"; }
action() { if $APPLY; then echo "  [removed]  $1"; removed=$((removed+1)); else echo "  [would remove] $1"; fi; }
keep()   { echo "  [PRESERVED] $1 — $2"; preserved=$((preserved+1)); }
note()   { echo "  [report]   $1"; reported=$((reported+1)); }

backup_json() {
  local f="$1"
  [ -f "$f" ] || return 0
  python3 -c "import json,sys; json.load(open('$f'))" 2>/dev/null || {
    echo "  [SKIP] $f is not valid JSON — refusing to touch it" >&2; return 1; }
  $APPLY || return 0
  cp "$f" "$f.bak-migrate-$(date +%Y%m%d%H%M%S)"
  return 0
}

LOG=$(mktemp "${TMPDIR:-/tmp}/migrate-from-kit.XXXXXX")
exec > >(tee "$LOG") 2>&1

say "=== migrate-from-kit  mode=$([ "$APPLY" = true ] && echo APPLY || echo inventory)  root=$ROOT ==="
say ""

# ---------------------------------------------------------------------------
say "--- machine level ---"

for c in start-work finish-work; do
  f="$CLAUDE_DIR/commands/$c.md"
  [ -e "$f" ] && action "$f (global command copy, placed by the retired sync script)"
  [ -e "$f" ] && $APPLY && rm -f "$f"
done

gs="$CLAUDE_DIR/skills/deploy-blueprint-claude"
if [ -e "$gs" ]; then
  action "$gs (global skill for the retired deployer)"
  $APPLY && rm -rf "$gs"
fi

# Permission rules are the user's own approvals. Report the ones naming the old path so
# they can be updated by hand after the directory is renamed; never rewrite them here.
if [ -f "$CLAUDE_DIR/settings.json" ]; then
  n=$(grep -c "$OLD_NAME" "$CLAUDE_DIR/settings.json" 2>/dev/null || echo 0)
  [ "$n" -gt 0 ] && note "$CLAUDE_DIR/settings.json holds $n permission rule(s) naming '$OLD_NAME' — update the path by hand after renaming the directory; these are your approvals, not the kit's"
fi

if [ -d "$ROOT/$OLD_NAME" ] && [ ! -d "$ROOT/$NEW_NAME" ]; then
  note "the checkout is still at $ROOT/$OLD_NAME — rename it with:  mv $ROOT/$OLD_NAME $ROOT/$NEW_NAME"
fi

# Both names installed at once doubles the context cost silently.
if command -v claude >/dev/null 2>&1; then
  both=$(claude plugin list 2>/dev/null | grep -cE "$OLD_NAME|$NEW_NAME" | head -1); both=${both:-0}
  [ "$both" -gt 1 ] 2>/dev/null && note "more than one kit plugin appears installed — check for both the old and new name, which doubles context cost"
fi

say ""
say "--- per project (under $ROOT) ---"

for d in "$ROOT"/*/; do
  [ -d "$d" ] || continue
  name=$(basename "$d")
  stamp="$d.claude/.blueprint-kit-version"
  man="$d.claude/blueprint-kit-manifest.json"
  [ -f "$stamp" ] || [ -f "$man" ] || continue

  say ""
  say "  $name  (stamped $( [ -f "$stamp" ] && cat "$stamp" || echo "?" ))"

  if [ -f "$man" ]; then
    # Only manifest-listed files with a matching hash are removed. Anything else stays.
    python3 - "$d" "$man" "$APPLY" <<'PY'
import hashlib, json, os, pathlib, sys
proj, man, apply = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3] == "true"
files = json.loads(man.read_text()).get("files", {})
drift = gone = ok = 0
for rel, info in sorted(files.items()):
    p = proj / rel
    if not p.exists():
        gone += 1
        continue
    h = hashlib.sha256(p.read_bytes()).hexdigest()
    if h == info.get("sha256"):
        print(f"  [{'removed' if apply else 'would remove'}]  {rel}")
        if apply:
            p.unlink()
            for parent in p.parents:
                if parent == proj: break
                try: parent.rmdir()
                except OSError: break
        ok += 1
    else:
        print(f"  [PRESERVED] {rel} — edited since deploy, not the kit's to delete")
        drift += 1
print(f"    manifest: {ok} matched, {drift} edited and preserved, {gone} already gone")
PY
  fi

  # Anything under .claude/ the manifest does not claim belongs to the project.
  python3 - "$d" "$man" <<'PY'
import json, pathlib, sys
proj = pathlib.Path(sys.argv[1]); man = pathlib.Path(sys.argv[2])
kit = set(json.loads(man.read_text()).get("files", {})) if man.exists() else set()
for sub in ("commands", "skills"):
    p = proj / ".claude" / sub
    if not p.is_dir(): continue
    unclaimed = [x.name for x in sorted(p.iterdir())
                 if not any(k.endswith(f"{sub}/{x.name}") or f"/{sub}/{x.name}/" in k for k in kit)]
    if unclaimed:
        print(f"    untouched, project-owned in .claude/{sub}/: {len(unclaimed)}")
PY

  for f in "$stamp" "$man"; do
    [ -e "$f" ] && action "${f#$ROOT/} (deploy state, nothing tracks copies now)"
    [ -e "$f" ] && $APPLY && rm -f "$f"
  done

  # The upgrade nag pointed at a VERSION file the kit no longer has.
  sl="$d.claude/settings.local.json"
  if [ -f "$sl" ] && grep -q 'blueprint-claude-kit/VERSION' "$sl" 2>/dev/null; then
    if backup_json "$sl"; then
      if $APPLY; then
        python3 - "$sl" <<'PY'
import json, sys, pathlib
p = pathlib.Path(sys.argv[1]); d = json.loads(p.read_text())
hooks = d.get("hooks", {})
ss = [h for h in hooks.get("SessionStart", [])
      if "blueprint-claude-kit/VERSION" not in json.dumps(h)]
if ss: hooks["SessionStart"] = ss
else: hooks.pop("SessionStart", None)
if not hooks: d.pop("hooks", None)
else: d["hooks"] = hooks
p.write_text(json.dumps(d, indent=2) + "\n")
json.loads(p.read_text())   # re-validate after writing
PY
        echo "  [removed]  ${sl#$ROOT/} SessionStart upgrade hook"
        removed=$((removed+1))
      else
        echo "  [would remove] ${sl#$ROOT/} SessionStart upgrade hook"
      fi
    fi
  fi
done

say ""
say "--- references this script cannot reach ---"
found=0
for f in "$ROOT"/*/CLAUDE.md "$ROOT"/*/AGENTS.md; do
  [ -f "$f" ] || continue
  if grep -q "$OLD_NAME\|deploy-blueprint-claude" "$f" 2>/dev/null; then
    note "${f#$ROOT/} mentions the old kit — edit by hand"; found=1
  fi
done
[ "$found" = 0 ] && say "  none"

say ""
sync
# grep -c already prints 0 on no match; pipefail would make `|| echo 0` fire anyway
# and append a second line, so do not add one.
count() { grep -c "$1" "$LOG" 2>/dev/null | head -1; }
R=$(count '^  \[removed\]');    R=${R:-0}
W=$(count '\[would remove\]');  W=${W:-0}
P=$(count '\[PRESERVED\]');     P=${P:-0}
N=$(count '^  \[report\]');     N=${N:-0}
say "=== summary: $([ "$APPLY" = true ] && echo "$R removed" || echo "$W to remove"), $P preserved, $N reported ==="
if ! $APPLY; then
  say ""
  say "Nothing was changed. Re-run with --apply to perform the migration."
fi
