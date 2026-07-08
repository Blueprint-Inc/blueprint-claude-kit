#!/bin/bash
# weekly-git-cleanup.sh — safe recurring cleanup of merged branches and stale worktrees.
#
# Safe by construction:
#   - Tier 1: `git branch -d` only (refuses anything not fully merged)
#   - Tier 2: branches whose upstream is gone are force-deleted ONLY after
#     `gh` confirms a merged PR existed for that head branch
#   - Worktrees: removed only if the checkout is clean AND its branch
#     qualifies under tier 1 or 2; dirty/detached/unknown are reported only
#   - Protected: main, master, staging, develop, production, current branch
#   - Every deletion is logged with its SHA (recovery: git branch <name> <sha>)
#
# Usage:
#   weekly-git-cleanup.sh              # dry run (default): report, delete nothing
#   weekly-git-cleanup.sh --apply      # actually delete
#   weekly-git-cleanup.sh --install    # install weekly launchd job (Mon 09:00)
#
# Config via env: CLEANUP_ROOT (default ~/Projects)
set -uo pipefail

ROOT="${CLEANUP_ROOT:-$HOME/Projects}"
MODE="dry-run"
LOG_DIR="$HOME/.config/blueprint-git-cleanup"
PROTECTED="main master staging develop production"

case "${1:-}" in
	--apply) MODE="apply" ;;
	--install)
		PLIST="$HOME/Library/LaunchAgents/com.blueprint.git-cleanup.plist"
		SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
		mkdir -p "$LOG_DIR" "$HOME/Library/LaunchAgents"
		cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key><string>com.blueprint.git-cleanup</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/bash</string>
		<string>$SELF</string>
		<string>--apply</string>
	</array>
	<key>StartCalendarInterval</key>
	<dict><key>Weekday</key><integer>1</integer><key>Hour</key><integer>9</integer><key>Minute</key><integer>0</integer></dict>
	<key>StandardOutPath</key><string>$LOG_DIR/cleanup.log</string>
	<key>StandardErrorPath</key><string>$LOG_DIR/cleanup.log</string>
</dict>
</plist>
PLISTEOF
		launchctl bootout "gui/$(id -u)/com.blueprint.git-cleanup" 2>/dev/null
		launchctl bootstrap "gui/$(id -u)" "$PLIST"
		echo "Installed: runs Mondays 09:00, logs to $LOG_DIR/cleanup.log"
		exit 0
		;;
	"") ;;
	*) echo "usage: $(basename "$0") [--apply|--install]"; exit 1 ;;
esac

mkdir -p "$LOG_DIR"
echo "=== git cleanup $(date '+%Y-%m-%d %H:%M') mode=$MODE root=$ROOT ==="

HAVE_GH=0
command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 && HAVE_GH=1
[ "$HAVE_GH" = 0 ] && echo "note: gh unavailable — squash-merged (gone-upstream) branches will be reported, not deleted"

is_protected() {
	local b="$1"
	for p in $PROTECTED; do [ "$b" = "$p" ] && return 0; done
	return 1
}

total_deleted=0
total_wt_removed=0
total_skipped=0

for repo in "$ROOT"/*/; do
	[ -d "$repo/.git" ] || continue
	name="$(basename "$repo")"
	cd "$repo" || continue

	current="$(git branch --show-current 2>/dev/null || true)"
	default="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')"
	[ -z "$default" ] && { git show-ref -q refs/heads/main && default=main || default=master; }

	git worktree prune 2>/dev/null
	git fetch --prune --quiet origin 2>/dev/null

	deleted=0; wt_removed=0; skipped=0

	# --- Worktrees: remove clean checkouts of deletable branches ---
	git worktree list --porcelain | awk '/^worktree /{wt=$2} /^branch /{sub("refs/heads/","",$2); print wt"\t"$2}' > /tmp/wt-list.$$ || true
	while IFS=$'\t' read -r wt_path wt_branch; do
		[ "$wt_path" = "$(git rev-parse --show-toplevel 2>/dev/null)" ] && continue
		[ -z "$wt_branch" ] && continue
		is_protected "$wt_branch" && continue
		[ -n "$(git -C "$wt_path" status --porcelain 2>/dev/null)" ] && { echo "  [skip] worktree dirty: $wt_path ($wt_branch)"; skipped=$((skipped+1)); continue; }
		deletable=0
		if git merge-base --is-ancestor "$wt_branch" "$default" 2>/dev/null; then
			deletable=1
		elif [ "$HAVE_GH" = 1 ] && git config "branch.$wt_branch.merge" >/dev/null 2>&1; then
			if ! git rev-parse --verify -q "$wt_branch@{upstream}" >/dev/null 2>&1; then
				merged_pr="$(gh pr list --head "$wt_branch" --state merged --limit 1 --json number --jq '.[0].number' 2>/dev/null || true)"
				[ -n "$merged_pr" ] && deletable=1
			fi
		fi
		if [ "$deletable" = 1 ]; then
			sha="$(git rev-parse --short "$wt_branch" 2>/dev/null)"
			if [ "$MODE" = "apply" ]; then
				git worktree remove "$wt_path" 2>/dev/null && git branch -D "$wt_branch" >/dev/null 2>&1 \
					&& { echo "  [removed] worktree $wt_path + branch $wt_branch ($sha)"; wt_removed=$((wt_removed+1)); deleted=$((deleted+1)); }
			else
				echo "  [would remove] worktree $wt_path + branch $wt_branch ($sha)"
				wt_removed=$((wt_removed+1)); deleted=$((deleted+1))
			fi
		else
			echo "  [skip] worktree not merged: $wt_path ($wt_branch)"; skipped=$((skipped+1))
		fi
	done < /tmp/wt-list.$$
	rm -f /tmp/wt-list.$$

	# --- Tier 1: fully merged local branches ---
	for b in $(git branch --merged "$default" --format='%(refname:short)' 2>/dev/null); do
		[ "$b" = "$current" ] && continue
		is_protected "$b" && continue
		git worktree list --porcelain | grep -q "^branch refs/heads/$b\$" && continue
		sha="$(git rev-parse --short "$b" 2>/dev/null)"
		if [ "$MODE" = "apply" ]; then
			git branch -d "$b" >/dev/null 2>&1 && { echo "  [deleted] $b ($sha) merged"; deleted=$((deleted+1)); }
		else
			echo "  [would delete] $b ($sha) merged"; deleted=$((deleted+1))
		fi
	done

	# --- Tier 2: upstream gone + merged PR confirmed (squash merges) ---
	if [ "$HAVE_GH" = 1 ]; then
		for b in $(git for-each-ref refs/heads --format='%(refname:short) %(upstream:track)' | awk '$2=="[gone]"{print $1}'); do
			[ "$b" = "$current" ] && continue
			is_protected "$b" && continue
			git worktree list --porcelain | grep -q "^branch refs/heads/$b\$" && continue
			merged_pr="$(gh pr list --head "$b" --state merged --limit 1 --json number --jq '.[0].number' 2>/dev/null || true)"
			if [ -n "$merged_pr" ]; then
				sha="$(git rev-parse --short "$b" 2>/dev/null)"
				if [ "$MODE" = "apply" ]; then
					git branch -D "$b" >/dev/null 2>&1 && { echo "  [deleted] $b ($sha) PR #$merged_pr merged"; deleted=$((deleted+1)); }
				else
					echo "  [would delete] $b ($sha) PR #$merged_pr merged"; deleted=$((deleted+1))
				fi
			else
				skipped=$((skipped+1))
			fi
		done
	fi

	if [ "$deleted" -gt 0 ] || [ "$wt_removed" -gt 0 ] || [ "$skipped" -gt 0 ]; then
		echo "[$name] branches: $deleted, worktrees: $wt_removed, kept/skipped: $skipped"
	fi
	total_deleted=$((total_deleted+deleted)); total_wt_removed=$((total_wt_removed+wt_removed)); total_skipped=$((total_skipped+skipped))
done

echo "=== TOTAL mode=$MODE: $total_deleted branches, $total_wt_removed worktrees, $total_skipped kept/skipped ==="
