#!/bin/bash
# weekly-git-cleanup.sh — safe recurring cleanup of merged branches and stale worktrees.
#
# Safe by construction:
#   - Tier 1: `git branch -d` only (refuses anything not fully merged)
#   - Tier 2: branches are force-deleted ONLY after `gh` confirms the branch
#     tip commit belongs to a MERGED pull request
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
		# launchd starts jobs with a bare PATH (/usr/bin:/bin:/usr/sbin:/sbin).
		# gh lives in a Homebrew prefix, so without this the job silently loses
		# squash-merge detection and reports "nothing to clean".
		GH_BIN_DIR="$(dirname "$(command -v gh 2>/dev/null || echo /opt/homebrew/bin/gh)")"
		JOB_PATH="$GH_BIN_DIR:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
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
	<key>EnvironmentVariables</key>
	<dict><key>PATH</key><string>$JOB_PATH</string><key>HOME</key><string>$HOME</string></dict>
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
if ! command -v gh >/dev/null 2>&1; then
	echo "WARNING: gh not found on PATH — squash-merged branches CANNOT be detected."
	echo "         This run will under-report and may clean nothing at all."
	echo "         PATH=$PATH"
elif ! gh auth status >/dev/null 2>&1; then
	echo "WARNING: gh found but not authenticated — squash-merged branches CANNOT be detected."
	echo "         This run will under-report. Run: gh auth status"
else
	HAVE_GH=1
fi

is_protected() {
	local b="$1"
	# The repo's own default branch is always protected, even when it is not
	# one of the hardcoded names (blueprintos uses "prod"). Without this a
	# local checkout of the default is deleted by tier 1, since every branch
	# is trivially "merged" into itself.
	[ -n "${default:-}" ] && [ "$b" = "$default" ] && return 0
	for p in $PROTECTED; do [ "$b" = "$p" ] && return 0; done
	return 1
}

# Merged-PR lookup, keyed on the branch TIP COMMIT rather than the branch name.
#
# Two reasons the old name-based/upstream-gone approach missed real merges:
#   1. Repos with delete_branch_on_merge=false keep the remote ref forever, so
#      the branch never goes [gone] and the check never ran.
#   2. branch.autoSetupMerge inheritance leaves local branches tracking a
#      DIFFERENT remote head, so `gh pr list --head <local-name>` found nothing.
# Asking GitHub which PRs contain the tip commit sidesteps both.
#
# Echoes the merged PR number, or nothing. Never fails the caller.
PR_CACHE="$(mktemp -t gitcleanup-pr)"
trap 'rm -f "$PR_CACHE" /tmp/wt-list.$$' EXIT

merged_pr_for() {
	local b="$1" sha hit res
	[ "$HAVE_GH" = 1 ] || return 0
	sha="$(git rev-parse -q --verify "$b" 2>/dev/null)"
	[ -n "$sha" ] || return 0

	hit="$(grep -m1 "^$sha " "$PR_CACHE" 2>/dev/null | cut -d' ' -f2-)"
	if [ -n "$hit" ]; then
		[ "$hit" = "-" ] || echo "$hit"
		return 0
	fi

	# PRs containing this commit, narrowed to those actually merged.
	# NOTE: a commit that was never pushed returns HTTP 422 and gh emits the
	# error JSON on stdout. Anything non-numeric MUST be discarded, or an
	# unpushed branch reads as "merged" and gets force-deleted.
	res="$(gh api "repos/{owner}/{repo}/commits/$sha/pulls" \
		--jq 'map(select(.merged_at != null)) | .[0].number // empty' 2>/dev/null || true)"
	case "$res" in ''|*[!0-9]*) res="" ;; esac

	# Fallback: head-name lookup, for branches whose tip was rewritten on merge.
	if [ -z "$res" ]; then
		res="$(gh pr list --head "$b" --state merged --limit 1 \
			--json number --jq '.[0].number // empty' 2>/dev/null || true)"
		case "$res" in ''|*[!0-9]*) res="" ;; esac
	fi

	printf '%s %s\n' "$sha" "${res:--}" >> "$PR_CACHE"
	[ -n "$res" ] && echo "$res"
	return 0
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
		deletable=0; why=""
		if git merge-base --is-ancestor "$wt_branch" "$default" 2>/dev/null; then
			deletable=1; why="merged"
		else
			merged_pr="$(merged_pr_for "$wt_branch")"
			[ -n "$merged_pr" ] && { deletable=1; why="PR #$merged_pr merged"; }
		fi
		if [ "$deletable" = 1 ]; then
			sha="$(git rev-parse --short "$wt_branch" 2>/dev/null)"
			if [ "$MODE" = "apply" ]; then
				git worktree remove "$wt_path" 2>/dev/null && git branch -D "$wt_branch" >/dev/null 2>&1 \
					&& { echo "  [removed] worktree $wt_path + branch $wt_branch ($sha) $why"; wt_removed=$((wt_removed+1)); deleted=$((deleted+1)); }
			else
				echo "  [would remove] worktree $wt_path + branch $wt_branch ($sha) $why"
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
			# `git branch -d` validates against HEAD, not $default, so it
			# refuses these whenever the repo sits on a feature branch. The
			# --merged $default selection above already proved the merge, so
			# fall back to -D only after re-confirming ancestry.
			if ! git branch -d "$b" >/dev/null 2>&1; then
				git merge-base --is-ancestor "$b" "$default" 2>/dev/null \
					&& git branch -D "$b" >/dev/null 2>&1
			fi
			if ! git show-ref -q "refs/heads/$b"; then
				echo "  [deleted] $b ($sha) merged"; deleted=$((deleted+1))
			else
				echo "  [skip] merged but undeletable: $b ($sha)"; skipped=$((skipped+1))
			fi
		else
			echo "  [would delete] $b ($sha) merged"; deleted=$((deleted+1))
		fi
	done

	# --- Tier 2: merged PR confirmed by tip commit (squash merges, renamed heads) ---
	# Every local branch is checked, not just [gone] ones: repos with
	# delete_branch_on_merge=false never produce a [gone] upstream.
	if [ "$HAVE_GH" = 1 ]; then
		for b in $(git for-each-ref refs/heads --format='%(refname:short)'); do
			[ "$b" = "$current" ] && continue
			is_protected "$b" && continue
			git worktree list --porcelain | grep -q "^branch refs/heads/$b\$" && continue
			git merge-base --is-ancestor "$b" "$default" 2>/dev/null && continue  # tier 1 owns it
			merged_pr="$(merged_pr_for "$b")"
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
