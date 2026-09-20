#!/usr/bin/env python3
"""PostToolUse Impeccable on UI file edits. Missing binary fail-open."""
import json
import os
import re
import subprocess
import sys

try:
    event = json.loads(sys.stdin.read() or "{}")
except Exception:
    sys.exit(0)

inp = event.get("toolInput") or {}
path = str(inp.get("target_file") or inp.get("file_path") or inp.get("path") or "")
if not path or not re.search(r"\.(svelte|css|scss|html|tsx|jsx|vue)$", path, re.I):
    sys.exit(0)

candidates = []
if os.environ.get("IMPECCABLE_BIN"):
    candidates.append(os.environ["IMPECCABLE_BIN"])
root = event.get("workspaceRoot") or event.get("cwd") or ""
if root:
    candidates.append(os.path.join(root, ".claude/skills/impeccable/scripts/impeccable"))
home = os.path.expanduser("~")
cache = os.path.join(home, ".claude/plugins/cache/impeccable")
if os.path.isdir(cache):
    for dirpath, _dirs, files in os.walk(cache):
        if "impeccable" in files and dirpath.endswith("scripts"):
            candidates.append(os.path.join(dirpath, "impeccable"))
            break

binpath = next((p for p in candidates if p and os.path.isfile(p) and os.access(p, os.X_OK)), None)
if not binpath:
    sys.exit(0)
try:
    subprocess.run([binpath, "hook"], timeout=5, check=False)
except Exception:
    pass
