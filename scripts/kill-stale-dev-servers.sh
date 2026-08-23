#!/bin/bash
# kill-stale-dev-servers.sh — stop leftover Vite / npm run dev processes.
#
# Matches the worktree pattern used by start-work / ce-worktree:
#   npm run dev --port N --strictPort
#   node .../vite dev --port N --strictPort
#
# Default: only processes with elapsed time >= 24 hours (yesterday's leftovers).
# weekly-git-cleanup.sh calls this with --min-age-hours 0 --under <worktree>
# before force-removing a merged dirty worktree.
#
# Usage:
#   kill-stale-dev-servers.sh                    # dry run
#   kill-stale-dev-servers.sh --apply
#   kill-stale-dev-servers.sh --install          # daily launchd 07:00
#   kill-stale-dev-servers.sh --min-age-hours 0 --under /path/to/worktree --apply
#
# Config via env: MIN_AGE_HOURS (default 24), UNDER (optional path prefix)
set -uo pipefail

MODE="dry-run"
MIN_AGE_HOURS="${MIN_AGE_HOURS:-24}"
UNDER="${UNDER:-}"
LOG_DIR="$HOME/.config/blueprint-git-cleanup"

etime_seconds() {
	# macOS ps etime: [[dd-]hh:]mm:ss
	local e="${1// /}"
	local days=0 h=0 m=0 s=0
	if [[ "$e" == *-* ]]; then
		days="${e%%-*}"
		e="${e#*-}"
	fi
	local IFS=:
	# shellcheck disable=SC2086
	set -- $e
	if [ "$#" -eq 3 ]; then
		h=$1; m=$2; s=$3
	elif [ "$#" -eq 2 ]; then
		m=$1; s=$2
	else
		s=$1
	fi
	echo $((10#$days * 86400 + 10#$h * 3600 + 10#$m * 60 + 10#$s))
}

cwd_of() {
	lsof -a -p "$1" -d cwd -Fn 2>/dev/null | awk '/^n/{print substr($0,2); exit}'
}

matches_under() {
	local pid="$1" cmd="$2"
	[ -z "$UNDER" ] && return 0
	case "$cmd" in
		*"$UNDER"*) return 0 ;;
	esac
	local cwd
	cwd="$(cwd_of "$pid")"
	case "$cwd" in
		"$UNDER"|"$UNDER"/*) return 0 ;;
	esac
	return 1
}

is_dev_server() {
	local cmd="$1"
	case "$cmd" in
		*"vite dev --port"*) return 0 ;;
		*"npm run dev --port"*) return 0 ;;
	esac
	return 1
}

install_job() {
	local plist="$HOME/Library/LaunchAgents/com.blueprint.kill-stale-dev-servers.plist"
	local self
	self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
	mkdir -p "$LOG_DIR" "$HOME/Library/LaunchAgents"
	cat > "$plist" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key><string>com.blueprint.kill-stale-dev-servers</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/bash</string>
		<string>$self</string>
		<string>--apply</string>
	</array>
	<key>EnvironmentVariables</key>
	<dict>
		<key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
		<key>HOME</key><string>$HOME</string>
	</dict>
	<key>StartCalendarInterval</key>
	<dict><key>Hour</key><integer>7</integer><key>Minute</key><integer>0</integer></dict>
	<key>ProcessType</key><string>Background</string>
	<key>Nice</key><integer>10</integer>
	<key>StandardOutPath</key><string>$LOG_DIR/stale-dev-servers.log</string>
	<key>StandardErrorPath</key><string>$LOG_DIR/stale-dev-servers.log</string>
</dict>
</plist>
PLISTEOF
	launchctl bootout "gui/$(id -u)/com.blueprint.kill-stale-dev-servers" 2>/dev/null || true
	launchctl bootstrap "gui/$(id -u)" "$plist"
	echo "Installed: runs daily 07:00, kills vite/npm run dev older than ${MIN_AGE_HOURS}h, logs to $LOG_DIR/stale-dev-servers.log"
	exit 0
}

while [ "$#" -gt 0 ]; do
	case "$1" in
		--apply) MODE="apply"; shift ;;
		--install) install_job ;;
		--min-age-hours)
			MIN_AGE_HOURS="$2"
			shift 2
			;;
		--under)
			UNDER="$2"
			shift 2
			;;
		*)
			echo "usage: $(basename "$0") [--apply|--install] [--min-age-hours N] [--under PATH]"
			exit 1
			;;
	esac
done

min_age_secs=$((MIN_AGE_HOURS * 3600))
echo "=== kill stale dev servers $(date '+%Y-%m-%d %H:%M') mode=$MODE min-age=${MIN_AGE_HOURS}h under=${UNDER:-<any>} ==="

killed=0
skipped_young=0
considered=0

# ps: PID, elapsed, full command. Skip the headerless empty pid rows.
while IFS= read -r line; do
	line="${line#"${line%%[![:space:]]*}"}"
	[ -n "$line" ] || continue
	pid="${line%% *}"
	rest="${line#"$pid"}"
	rest="${rest#"${rest%%[![:space:]]*}"}"
	etime="${rest%% *}"
	cmd="${rest#"$etime"}"
	cmd="${cmd#"${cmd%%[![:space:]]*}"}"
	[ -n "$pid" ] && [ -n "$cmd" ] || continue
	is_dev_server "$cmd" || continue
	matches_under "$pid" "$cmd" || continue
	considered=$((considered + 1))
	secs="$(etime_seconds "$etime")"
	if [ "$secs" -lt "$min_age_secs" ]; then
		echo "  [skip] pid=$pid age=${etime} (under ${MIN_AGE_HOURS}h) $cmd"
		skipped_young=$((skipped_young + 1))
		continue
	fi
	if [ "$MODE" = "apply" ]; then
		if kill -TERM "$pid" 2>/dev/null; then
			echo "  [killed] pid=$pid age=${etime} $cmd"
			killed=$((killed + 1))
		else
			echo "  [miss] pid=$pid already gone"
		fi
	else
		echo "  [would kill] pid=$pid age=${etime} $cmd"
		killed=$((killed + 1))
	fi
done < <(ps -axo pid=,etime=,command=)

echo "=== TOTAL mode=$MODE: $killed stale, $skipped_young too-young, $considered matched ==="
