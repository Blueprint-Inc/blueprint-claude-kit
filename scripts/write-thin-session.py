#!/usr/bin/env python3
"""Write a Grok home's hooks/thin-session.json.

Single source of truth for hook registration. Called by grok-thin.sh when the kit
is applied, and again by pickup-jev-key.sh once a Jev key lands -- because the Jev
PreToolUse entry is written only when the key already exists, and without that
second call a key installed after the last apply never takes effect.

Usage: write-thin-session.py <hooks/thin-session.json> <jev-key-path> [--quiet]
"""
import json
import os
import sys


def main(argv):
    if len(argv) < 3:
        print(__doc__.strip().splitlines()[-1], file=sys.stderr)
        return 2
    path, key = argv[1], argv[2]
    quiet = "--quiet" in argv[3:]

    doc = {
        "hooks": {
            "SessionStart": [
                {"hooks": [{"type": "command", "command": "./write-catalog.sh",
                            "timeout": 15}]}
            ],
            "PostToolUse": [
                {"matcher": "search_replace|write|Write|Edit|MultiEdit",
                 "hooks": [{"type": "command", "command": "./impeccable-ui-edit.sh",
                            "timeout": 6}]}
            ],
        }
    }

    has_key = os.path.isfile(key) and os.path.getsize(key) > 0
    if has_key:
        doc["hooks"]["PreToolUse"] = [{
            "matcher": ("run_terminal_command|search_replace|write|use_tool|"
                        "spawn_subagent|Bash|Write|Edit|MultiEdit"),
            "hooks": [{"type": "command", "command": "./jev-pretool.sh",
                       "timeout": 8}],
        }]

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as fh:
        json.dump(doc, fh, indent=2)
        fh.write("\n")

    if not quiet:
        if has_key:
            print("  grok-thin: Jev PreToolUse enabled")
        else:
            print("  grok-thin: Jev hook skipped (no key). "
                  "Run scripts/pickup-jev-key.sh")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
