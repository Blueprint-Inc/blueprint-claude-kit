#!/bin/bash
# kill-stale-python-mcp.sh — reap leftover Homebrew Python.app MCP servers.
#
# Coding agents launch `uvx ... browser-use --cli-mcp` through Homebrew's
# Python.app GUI bundle. Each launch puts a rocket in the Dock, and old
# processes are never reaped, so the icons pile up.
#
# Policy (newest first):
#   - Never touch a process younger than MIN_AGE_MINUTES (default 60)
#   - Keep at most KEEP_NEWEST (default 2) browser-use Python.app processes
#   - Kill anything older than MAX_AGE_HOURS (default 8), even a kept slot
#   - Also TERM the matching `uv tool uvx ... browser-use` parent
#
# Usage:
#   kill-stale-python-mcp.sh                 # dry run
#   kill-stale-python-mcp.sh --apply
#   kill-stale-python-mcp.sh --install       # launchd every 30 minutes
#
# Config via env: MIN_AGE_MINUTES, KEEP_NEWEST, MAX_AGE_HOURS
set -uo pipefail

MODE="dry-run"
MIN_AGE_MINUTES="${MIN_AGE_MINUTES:-60}"
KEEP_NEWEST="${KEEP_NEWEST:-2}"
MAX_AGE_HOURS="${MAX_AGE_HOURS:-8}"
LOG_DIR="$HOME/.config/blueprint-git-cleanup"

etime_seconds() {
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

is_browser_use_python() {
	local cmd="$1"
	case "$cmd" in
		*"/Python.app/Contents/MacOS/Python "*"browser-use --cli-mcp"*) return 0 ;;
		*"Python.app/Contents/MacOS/Python "*"browser-use --cli-mcp"*) return 0 ;;
	esac
	return 1
}

is_browser_use_uv() {
	local cmd="$1"
	case "$cmd" in
		*"uv tool uvx"*"browser-use"*) return 0 ;;
		*"uvx "*"browser-use"*"--cli-mcp"*) return 0 ;;
	esac
	return 1
}

cmd_of() {
	ps -p "$1" -o command= 2>/dev/null
}

term_pid() {
	local pid="$1" why="$2"
	if [ "$MODE" = "apply" ]; then
		if kill -TERM "$pid" 2>/dev/null; then
			echo "  [killed] pid=$pid $why"
			return 0
		fi
		echo "  [miss] pid=$pid already gone"
		return 1
	fi
	echo "  [would kill] pid=$pid $why"
	return 0
}

install_job() {
	local plist="$HOME/Library/LaunchAgents/com.blueprint.kill-stale-python-mcp.plist"
	local self
	self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
	mkdir -p "$LOG_DIR" "$HOME/Library/LaunchAgents"
	cat > "$plist" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key><string>com.blueprint.kill-stale-python-mcp</string>
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
	<key>StartInterval</key><integer>1800</integer>
	<key>RunAtLoad</key><true/>
	<key>ProcessType</key><string>Background</string>
	<key>Nice</key><integer>10</integer>
	<key>StandardOutPath</key><string>$LOG_DIR/stale-python-mcp.log</string>
	<key>StandardErrorPath</key><string>$LOG_DIR/stale-python-mcp.log</string>
</dict>
</plist>
PLISTEOF
	launchctl bootout "gui/$(id -u)/com.blueprint.kill-stale-python-mcp" 2>/dev/null || true
	launchctl bootstrap "gui/$(id -u)" "$plist"
	echo "Installed: every 30 minutes, keeps $KEEP_NEWEST newest browser-use Python.app processes, kills the rest if older than ${MIN_AGE_MINUTES}m (hard cap ${MAX_AGE_HOURS}h). Log: $LOG_DIR/stale-python-mcp.log"
	exit 0
}

while [ "$#" -gt 0 ]; do
	case "$1" in
		--apply) MODE="apply"; shift ;;
		--install) install_job ;;
		--min-age-minutes)
			MIN_AGE_MINUTES="$2"
			shift 2
			;;
		--keep-newest)
			KEEP_NEWEST="$2"
			shift 2
			;;
		--max-age-hours)
			MAX_AGE_HOURS="$2"
			shift 2
			;;
		*)
			echo "usage: $(basename "$0") [--apply|--install] [--min-age-minutes N] [--keep-newest N] [--max-age-hours N]"
			exit 1
			;;
	esac
done

min_age_secs=$((MIN_AGE_MINUTES * 60))
max_age_secs=$((MAX_AGE_HOURS * 3600))

echo "=== kill stale python mcp $(date '+%Y-%m-%d %H:%M') mode=$MODE keep=$KEEP_NEWEST min-age=${MIN_AGE_MINUTES}m max-age=${MAX_AGE_HOURS}h ==="

# pid, ppid, secs, etime — newest first
entries=()
while IFS= read -r line; do
	line="${line#"${line%%[![:space:]]*}"}"
	[ -n "$line" ] || continue
	pid="${line%% *}"
	rest="${line#"$pid"}"
	rest="${rest#"${rest%%[![:space:]]*}"}"
	ppid="${rest%% *}"
	rest="${rest#"$ppid"}"
	rest="${rest#"${rest%%[![:space:]]*}"}"
	etime="${rest%% *}"
	cmd="${rest#"$etime"}"
	cmd="${cmd#"${cmd%%[![:space:]]*}"}"
	[ -n "$pid" ] && [ -n "$cmd" ] || continue
	is_browser_use_python "$cmd" || continue
	secs="$(etime_seconds "$etime")"
	entries+=("$secs $pid $ppid $etime")
done < <(LC_ALL=C ps -axo pid=,ppid=,etime=,command=)

if [ "${#entries[@]}" -eq 0 ]; then
	echo "=== TOTAL mode=$MODE: 0 matched ==="
	exit 0
fi

# Newest first (smallest elapsed seconds)
IFS=$'\n' sorted=($(printf '%s\n' "${entries[@]}" | sort -n))
unset IFS

kept=0
killed=0
skipped_young=0
considered=0

for entry in "${sorted[@]}"; do
	secs="${entry%% *}"
	rest="${entry#* }"
	pid="${rest%% *}"
	rest="${rest#* }"
	ppid="${rest%% *}"
	etime="${rest#* }"
	considered=$((considered + 1))

	action="kill"
	reason=""
	if [ "$secs" -lt "$min_age_secs" ]; then
		action="keep"
		reason="under ${MIN_AGE_MINUTES}m"
		skipped_young=$((skipped_young + 1))
		kept=$((kept + 1))
	elif [ "$secs" -ge "$max_age_secs" ]; then
		action="kill"
		reason="over ${MAX_AGE_HOURS}h"
	elif [ "$kept" -lt "$KEEP_NEWEST" ]; then
		action="keep"
		reason="kept slot $((kept + 1))/$KEEP_NEWEST"
		kept=$((kept + 1))
	else
		action="kill"
		reason="beyond keep=$KEEP_NEWEST"
	fi

	if [ "$action" = "keep" ]; then
		echo "  [keep] pid=$pid age=${etime} ($reason)"
		continue
	fi

	if term_pid "$pid" "age=${etime} python.app ($reason)"; then
		killed=$((killed + 1))
	fi
	if [ "$ppid" != "1" ] && [ -n "$ppid" ]; then
		parent_cmd="$(cmd_of "$ppid")"
		if is_browser_use_uv "$parent_cmd"; then
			term_pid "$ppid" "age=${etime} uv parent of $pid" || true
		fi
	fi
done

echo "=== TOTAL mode=$MODE: $killed stale, $skipped_young too-young, $kept kept, $considered matched ==="
